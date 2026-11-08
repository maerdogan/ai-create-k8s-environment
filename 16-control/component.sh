#!/usr/bin/env bash
# Install, remove, check and verify the components of 00-common/generated/components.tsv.
# Usage:
#   component.sh status                  all components with their state
#   component.sh closure <id>...         ids to install, with missing dependencies
#   component.sh dependents <id>...      installed ids that need one of the ids
#   component.sh install <id>...
#   component.sh remove [--purge] <id>...  --purge also removes the PVCs of apps
#   component.sh verify <id>...
# Lines that start with "==>" show the progress. The menus read them.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
source "$INSTALL_DIR/16-control/lib-state.sh"

need_running() {
  [[ $(node_state "$1") == running ]] || die "Cluster $1 does not run. Start it first."
}

dnscore_runs() {
  [[ $(node_state networking) == running ]] \
    && kc networking -n dnscore get deploy dnscore >/dev/null 2>&1
}

install_one() {
  row "$1"
  case $C_TYPE in
    platform) bash "$INSTALL_DIR/01-platform/install.sh" ;;
    images) bash "$INSTALL_DIR/09-images/install.sh" --build-only ;;
    cluster)
      bash "$INSTALL_DIR/02-clusters/install.sh" "$C_CLUSTER"
      bash "$INSTALL_DIR/04-ako-loadbalancer/install.sh" "$C_CLUSTER"
      bash "$INSTALL_DIR/06-gateway-api/install.sh" "$C_CLUSTER"
      if dnscore_runs; then bash "$INSTALL_DIR/11-dnscore/link.sh" "$C_CLUSTER"; fi
      log "For host access run in a normal terminal: sudo -v && $INSTALL_DIR/02-clusters/routes.sh" ;;
    namespace)
      need_running "$C_CLUSTER"
      mem_guard
      local d=$GEN/ns/$C_NS
      kc "$C_CLUSTER" apply -f "$d/calico.yaml" -f "$d/namespace.yaml" -f "$d/metallb.yaml"
      [[ ! -f $GEN/limits/$C_NS.yaml ]] || kc "$C_CLUSTER" apply -f "$GEN/limits/$C_NS.yaml"
      bash "$INSTALL_DIR/05-nginx-ingress/install.sh" "$C_NS" ;;
    app)
      need_running "$C_CLUSTER"
      run_step "$C_INSTALL" ;;
  esac
  [[ $C_CLUSTER == - ]] || scan "$C_CLUSTER"
}

# Prints the manifest without PersistentVolumeClaims, so data stays.
without_pvc() {
  python3 -c '
import re, sys
docs = re.split(r"^---\s*$", open(sys.argv[1]).read(), flags=re.M)
print("\n---\n".join(d for d in docs if d.strip() and not re.search(r"^kind: PersistentVolumeClaim", d, re.M)))
' "$1"
}

remove_app() {
  local purge=$1 w m pvcs=() tmp
  if [[ $purge == 1 ]]; then
    tmp=$(mktemp "$TMPDIR/objects.XXXXXX")
    kc "$C_CLUSTER" -n "$C_NS" get deploy,sts,ds,pvc -o json > "$tmp"
    for w in ${C_WORKLOADS//,/ }; do
      mapfile -t -O "${#pvcs[@]}" pvcs < <(python3 "$CONTROL/related.py" "$w" "$tmp" --pvc)
    done
    rm -f "$tmp"
  fi
  for m in ${C_MANIFESTS//,/ }; do
    without_pvc "$GEN/$m" | kc "$C_CLUSTER" delete --ignore-not-found -f -
  done
  if [[ ${#pvcs[@]} -gt 0 ]]; then kc "$C_CLUSTER" -n "$C_NS" delete "${pvcs[@]}"; fi
}

remove_one() {
  row "$1"
  case $C_TYPE in
    platform|images) die "The menu does not remove $C_ID. See 01-platform/README.txt." ;;
    cluster)
      kind delete cluster --name "$C_CLUSTER" --kubeconfig "$RUNTIME/kubeconfig/$C_CLUSTER.yaml"
      rm -f "$RUNTIME/kubeconfig/$C_CLUSTER.yaml" "$INV/$C_CLUSTER".*.tsv
      bash "$INSTALL_DIR/02-clusters/merge-kubeconfig.sh" ;;
    namespace)
      need_running "$C_CLUSTER"
      hc "$C_CLUSTER" uninstall "nginx-$C_NS" -n "$C_NS" --wait 2>/dev/null || true
      kc "$C_CLUSTER" delete ns "$C_NS" --ignore-not-found --timeout=300s
      kc "$C_CLUSTER" delete --ignore-not-found \
        -f "$GEN/ns/$C_NS/metallb.yaml" -f "$GEN/ns/$C_NS/calico.yaml" ;;
    app)
      need_running "$C_CLUSTER"
      remove_app "$PURGE" ;;
  esac
  [[ $C_CLUSTER == - || $C_TYPE == cluster ]] || scan "$C_CLUSTER"
}

verify_one() {
  row "$1"
  case $C_TYPE in
    platform) bash "$INSTALL_DIR/01-platform/verify.sh" ;;
    images) bash "$INSTALL_DIR/09-images/verify.sh" --images-only ;;
    cluster)
      bash "$INSTALL_DIR/02-clusters/verify.sh" "$C_CLUSTER"
      bash "$INSTALL_DIR/04-ako-loadbalancer/verify.sh" "$C_CLUSTER"
      bash "$INSTALL_DIR/06-gateway-api/verify.sh" "$C_CLUSTER" ;;
    namespace)
      bash "$INSTALL_DIR/03-namespaces/verify.sh" "$C_NS"
      bash "$INSTALL_DIR/05-nginx-ingress/verify.sh" "$C_NS" ;;
    app) run_step "$C_VERIFY" ;;
  esac
}

# Usage: each <install|remove> <id>... Stops at the first error.
each() {
  local action=$1 ids n i=0 id; shift
  mapfile -t ids < <(catalog order "$action" "$@")
  n=${#ids[@]}
  for id in "${ids[@]}"; do
    i=$((i + 1))
    echo "==> START $i $n $action $id"
    # A new process, so set -e works in it.
    if bash "$0" _one "$action" "$id"; then
      echo "==> OK $id"
    else
      echo "==> FAIL $id"
      return 1
    fi
  done
}

cmd=${1:-}; shift || true
export PURGE=${PURGE:-0}
case $cmd in
  _one) "${1}_one" "$2" ;;
  status) scan; catalog status ;;
  closure|dependents) scan; catalog "$cmd" "$@" ;;
  install) each install "$@" ;;
  remove)
    [[ ${1:-} != --purge ]] || { PURGE=1; shift; }
    each remove "$@" ;;
  verify)
    scan
    declare -A state
    while IFS=$'\t' read -r id _ _ _ _ _ s _; do state[$id]=$s; done < <(catalog status)
    bad=0
    for id in "$@"; do
      [[ -n ${state[$id]:-} ]] || die "Unknown component: $id"
      if [[ ${state[$id]} != running ]]; then echo "==> SKIP $id ${state[$id]}"; continue; fi
      if out=$(bash "$0" _one verify "$id" 2>&1); then
        echo "==> PASS $id"
      else
        bad=1
        printf '%s\n' "$out"
        echo "==> FAIL $id $(grep -m1 '^ERROR' <<<"$out" || tail -1 <<<"$out")"
      fi
    done
    exit "$bad" ;;
  *) sed -n '2,9p' "$0"; exit 2 ;;
esac
