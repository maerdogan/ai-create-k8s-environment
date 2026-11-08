#!/usr/bin/env bash
# Stop, start, restart and delete clusters, namespaces and apps.
# Usage:
#   control.sh stop|start|restart|delete cluster <cluster>...
#   control.sh stop|start|restart|delete ns <cluster>/<namespace>...
#   control.sh stop|start|restart|delete app <cluster>/<namespace>/<kind>/<name>...
#   control.sh stop|start all
#   delete app takes --purge first to remove the PVCs too.
# Stop keeps the old values in annotations. Start puts them back.
# A stopped cluster uses no memory. A stopped namespace or app runs no pods.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
source "$INSTALL_DIR/16-control/lib-state.sh"

stop_workload() {
  local c=$1 ns=$2 w=$3 r
  case ${w%%/*} in
    deploy|deployment.apps|sts|statefulset.apps)
      r=$(kc "$c" -n "$ns" get "$w" -o jsonpath='{.spec.replicas}')
      if [[ ${r:-0} -gt 0 ]]; then
        kc "$c" -n "$ns" annotate "$w" "$NOTE/replicas=$r" --overwrite >/dev/null
        kc "$c" -n "$ns" scale "$w" --replicas=0 >/dev/null
      fi ;;
    ds|daemonset.apps)
      # A DaemonSet has no replicas. A node label that no node has stops it.
      kc "$c" -n "$ns" patch "$w" --type=merge \
        -p "{\"spec\":{\"template\":{\"spec\":{\"nodeSelector\":{\"$NOTE/stopped\":\"true\"}}}}}" >/dev/null ;;
    cronjob|cronjob.batch)
      r=$(kc "$c" -n "$ns" get "$w" -o jsonpath='{.spec.suspend}')
      kc "$c" -n "$ns" annotate "$w" "$NOTE/suspend=${r:-false}" --overwrite >/dev/null
      kc "$c" -n "$ns" patch "$w" --type=merge -p '{"spec":{"suspend":true}}' >/dev/null ;;
  esac
  log "stopped $c/$ns/$w"
}

start_workload() {
  local c=$1 ns=$2 w=$3 r
  case ${w%%/*} in
    deploy|deployment.apps|sts|statefulset.apps)
      r=$(kc "$c" -n "$ns" get "$w" -o jsonpath="{.metadata.annotations.${NOTE//./\\.}/replicas}")
      [[ -n $r ]] || return 0
      kc "$c" -n "$ns" scale "$w" --replicas="$r" >/dev/null
      kc "$c" -n "$ns" annotate "$w" "$NOTE/replicas-" >/dev/null ;;
    ds|daemonset.apps)
      kc "$c" -n "$ns" patch "$w" --type=merge \
        -p "{\"spec\":{\"template\":{\"spec\":{\"nodeSelector\":{\"$NOTE/stopped\":null}}}}}" >/dev/null ;;
    cronjob|cronjob.batch)
      r=$(kc "$c" -n "$ns" get "$w" -o jsonpath="{.metadata.annotations.${NOTE//./\\.}/suspend}")
      [[ -n $r ]] || return 0
      kc "$c" -n "$ns" patch "$w" --type=merge -p "{\"spec\":{\"suspend\":$r}}" >/dev/null
      kc "$c" -n "$ns" annotate "$w" "$NOTE/suspend-" >/dev/null ;;
  esac
  log "started $c/$ns/$w"
}

workloads() { kc "$1" -n "$2" get deploy,sts,ds,cronjob -o name; }

ns_action() {
  local action=$1 c=${2%%/*} ns=${2#*/} w
  [[ $(node_state "$c") == running ]] || die "Cluster $c does not run."
  case $action in
    stop)
      for w in $(workloads "$c" "$ns"); do stop_workload "$c" "$ns" "$w"; done
      kc "$c" annotate ns "$ns" "$NOTE/stopped=true" --overwrite >/dev/null ;;
    start)
      for w in $(workloads "$c" "$ns"); do start_workload "$c" "$ns" "$w"; done
      kc "$c" annotate ns "$ns" "$NOTE/stopped-" >/dev/null 2>&1 || true ;;
    restart)
      for w in $(kc "$c" -n "$ns" get deploy,sts,ds -o name); do
        kc "$c" -n "$ns" rollout restart "$w" >/dev/null
      done ;;
    delete)
      if grep -qx "ns:$ns" < <(cut -f1 "$CATALOG"); then
        bash "$CONTROL/component.sh" remove "ns:$ns"
      else
        kc "$c" delete ns "$ns" --timeout=300s
      fi ;;
  esac
  log "$action $c/$ns done"
}

# Prints the catalog id of an app, or nothing.
catalog_app() {
  awk -F'\t' -v c="$1" -v n="$2" -v w="$3" \
    '$2=="app" && $3==c && $4==n && (","$8",") ~ ","w"," {print $1}' "$CATALOG"
}

app_action() {
  local action=$1 rest=$2 c ns w id tmp objs release
  c=${rest%%/*}; rest=${rest#*/}; ns=${rest%%/*}; w=${rest#*/}
  [[ $(node_state "$c") == running ]] || die "Cluster $c does not run."
  case $action in
    stop) stop_workload "$c" "$ns" "$w" ;;
    start) start_workload "$c" "$ns" "$w" ;;
    restart) kc "$c" -n "$ns" rollout restart "$w" ;;
    delete)
      id=$(catalog_app "$c" "$ns" "$w")
      if [[ -n $id ]]; then
        bash "$CONTROL/component.sh" remove "${PURGE_ARG[@]}" "$id"
        return
      fi
      release=$(kc "$c" -n "$ns" get "$w" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}')
      if [[ -n $release ]]; then
        hc "$c" uninstall "$release" -n "$ns" --wait
        return
      fi
      tmp=$(mktemp "$TMPDIR/objects.XXXXXX")
      kc "$c" -n "$ns" get deploy,sts,ds,svc,ingress,pvc -o json > "$tmp"
      kc "$c" -n "$ns" get httproute -o json 2>/dev/null | python3 -c '
import json, sys
a = json.load(open(sys.argv[1])); a["items"] += json.load(sys.stdin)["items"]
json.dump(a, open(sys.argv[1], "w"))' "$tmp" || true
      mapfile -t objs < <(python3 "$CONTROL/related.py" "$w" "$tmp")
      [[ ${#PURGE_ARG[@]} -eq 0 ]] || mapfile -t -O "${#objs[@]}" objs < <(python3 "$CONTROL/related.py" "$w" "$tmp" --pvc)
      rm -f "$tmp"
      kc "$c" -n "$ns" delete "$w" "${objs[@]}" ;;
  esac
  log "$action $c/$ns/$w done"
}

wait_api() {
  local c=$1
  for _ in {1..60}; do
    kc "$c" get --raw=/readyz >/dev/null 2>&1 && return 0
    sleep 3
  done
  die "$c API is not ready."
}

cluster_action() {
  local action=$1 c=$2 old ns
  case $action in
    stop)
      [[ $(node_state "$c") == running ]] || { log "$c does not run."; return 0; }
      # The inventory of a stopped cluster shows its last state.
      scan "$c"
      node_ip "$c" > "$STATE/$c.ip"
      docker stop "$c-control-plane" >/dev/null ;;
    start|restart)
      [[ $(node_state "$c") != missing ]] || die "Cluster $c does not exist."
      old=$(cat "$STATE/$c.ip" 2>/dev/null || node_ip "$c")
      if [[ $action == start ]]; then
        docker start "$c-control-plane" >/dev/null
      else
        docker restart "$c-control-plane" >/dev/null
      fi
      wait_api "$c"
      bash "$INSTALL_DIR/02-clusters/node-routes.sh" >/dev/null
      # Start everything below the cluster, also namespaces stopped one by one.
      for ns in $(kc "$c" get ns -o jsonpath='{.items[*].metadata.name}'); do
        case $ns in kube-*|default|local-path-storage|metallb-system) continue ;; esac
        ns_action start "$c/$ns" >/dev/null
      done
      if [[ -n $old && $(node_ip "$c") != "$old" ]]; then
        log "WARNING: $c has a new node IP. In a normal terminal run: sudo -v && $INSTALL_DIR/02-clusters/routes.sh"
      fi ;;
    delete) bash "$CONTROL/component.sh" remove "cluster:$c" ;;
  esac
  scan "$c"
  log "$action $c done"
}

action=${1:-}; level=${2:-}; shift 2 || true
PURGE_ARG=()
[[ ${1:-} != --purge ]] || { PURGE_ARG=(--purge); shift; }
case $action/$level in
  stop/all)
    mapfile -t targets < <(running_clusters)
    for c in "${targets[@]}"; do cluster_action stop "$c"; done ;;
  start/all)
    # networking first: it has the DNS server.
    mapfile -t targets < <(existing_clusters | awk '$1=="networking" {print; next} {a[++n]=$1} END {for (i=1;i<=n;i++) print a[i]}')
    for c in "${targets[@]}"; do
      [[ $(node_state "$c") == running ]] || { mem_guard; cluster_action start "$c"; }
    done ;;
  stop/cluster|start/cluster|restart/cluster|delete/cluster)
    for c in "$@"; do
      [[ $action != start ]] || mem_guard
      cluster_action "$action" "$c"
    done ;;
  stop/ns|start/ns|restart/ns|delete/ns)
    for t in "$@"; do ns_action "$action" "$t"; scan "${t%%/*}"; done ;;
  stop/app|start/app|restart/app|delete/app)
    for t in "$@"; do app_action "$action" "$t"; scan "${t%%/*}"; done ;;
  *) sed -n '2,10p' "$0"; exit 2 ;;
esac
