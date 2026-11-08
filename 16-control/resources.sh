#!/usr/bin/env bash
# Memory, swap and CPU use. The menus format the output.
# Usage:
#   resources.sh host              KEY=VALUE lines, memory in MiB
#   resources.sh clusters          cluster, state, RAM MiB, swap MiB, CPU %, pods
#   resources.sh nodes             cluster, state, RAM MiB, swap MiB (fast, no CPU)
#   resources.sh pods [--system]   top 15 pods: cluster, ns, pod, app, RAM MiB, limit MiB, kind/name
#   resources.sh namespaces <c>    namespace, RAM MiB
#   resources.sh tune [cluster...] apply the memory settings of 02-clusters again
#   resources.sh drop-cache        needs sudo
#   resources.sh swap-check        used, free, need in MiB and ok=0|1
#   resources.sh swap-off          needs sudo; swapoff and swapon of the swap file
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
source "$INSTALL_DIR/16-control/lib-state.sh"
SWAPFILE=$RUNTIME/swapfile

# Prints the cgroup folder of a running node.
node_cgroup() {
  local id d
  id=$(docker inspect -f '{{.Id}}' "$1-control-plane" 2>/dev/null) || return 1
  for d in "/sys/fs/cgroup/system.slice/docker-$id.scope" "/sys/fs/cgroup/docker/$id"; do
    [[ -d $d ]] && { echo "$d"; return 0; }
  done
  return 1
}

# Prints "ram swap" of a node in MiB. RAM does not count file cache that can go.
node_mem() {
  local d ram inactive swap
  d=$(node_cgroup "$1") || { echo "0 0"; return; }
  ram=$(cat "$d/memory.current")
  inactive=$(awk '$1=="inactive_file" {print $2}' "$d/memory.stat")
  swap=$(cat "$d/memory.swap.current" 2>/dev/null || echo 0)
  echo "$(( (ram - inactive) / 1048576 )) $(( swap / 1048576 ))"
}

host() {
  local c ram swap k8s_ram=0 k8s_swap=0
  for c in $(running_clusters); do
    read -r ram swap < <(node_mem "$c")
    k8s_ram=$((k8s_ram + ram)) k8s_swap=$((k8s_swap + swap))
  done
  awk '{m[$1]=int($2/1024)} END {
    print "mem_total=" m["MemTotal:"]; print "mem_free=" m["MemAvailable:"]
    print "mem_used=" m["MemTotal:"]-m["MemAvailable:"]
    print "cache=" m["Cached:"]+m["Buffers:"]
    print "swap_total=" m["SwapTotal:"]; print "swap_used=" m["SwapTotal:"]-m["SwapFree:"]
  }' /proc/meminfo
  echo "k8s_ram=$k8s_ram"
  echo "k8s_swap=$k8s_swap"
  read -r l1 l5 l15 _ < /proc/loadavg
  echo "load=$l1 $l5 $l15"
  echo "cpus=$(nproc)"
  df -BM --output=used,size "$PLATFORM_ROOT" | awk 'NR==2 {gsub("M",""); print "disk_used=" $1; print "disk_total=" $2}'
  echo "clusters_running=$(running_clusters | wc -l)"
  echo "clusters_total=$(existing_clusters | wc -l)"
}

clusters_table() {
  local c ram swap cpu pods
  declare -A cpus
  while IFS=$'\t' read -r name pct; do cpus[${name%-control-plane}]=${pct%\%}; done < <(
    docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}' 2>/dev/null | grep -- '-control-plane' || true)
  for c in $(existing_clusters); do
    if [[ $(node_state "$c") == running ]]; then
      read -r ram swap < <(node_mem "$c")
      cpu=${cpus[$c]:-0}
      pods=$(wc -l < "$INV/$c.pods.tsv" 2>/dev/null || echo 0)
      printf '%s\trunning\t%s\t%s\t%s\t%s\n' "$c" "$ram" "$swap" "$cpu" "$pods"
    else
      printf '%s\tstopped\t0\t0\t0\t0\n' "$c"
    fi
  done | sort -t$'\t' -k3,3nr
}

case ${1:-} in
  host) host ;;
  nodes)
    for c in $(existing_clusters); do
      if [[ $(node_state "$c") == running ]]; then
        read -r ram swap < <(node_mem "$c")
        printf '%s\trunning\t%s\t%s\n' "$c" "$ram" "$swap"
      else
        printf '%s\tstopped\t0\t0\n' "$c"
      fi
    done ;;
  clusters) scan >/dev/null; clusters_table ;;
  pods)
    scan
    cat "$INV"/*.pods.tsv 2>/dev/null | awk -F'\t' -v s="${2:-}" 's=="--system" || $7==0' \
      | sort -t$'\t' -k5,5nr | head -15 | cut -f1-6,8 ;;
  namespaces)
    awk -F'\t' '{print $2 "\t" $5 "\t" $6}' "$INV/$2.ns.tsv" | sort -t$'\t' -k2,2nr ;;
  tune) shift; bash "$INSTALL_DIR/02-clusters/tune-memory.sh" "$@" ;;
  drop-cache) sync; echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null; log 'Page cache is free.' ;;
  swap-check)
    used=$(awk '/SwapTotal/ {t=$2} /SwapFree/ {f=$2} END {print int((t-f)/1024)}' /proc/meminfo)
    free=$(mem_free_mb)
    need=$((used + 1024))
    echo "used=$used free=$free need=$need ok=$(( free >= need ? 1 : 0 ))" ;;
  swap-off)
    swapon --show=NAME --noheadings | grep -qxF "$SWAPFILE" || die "$SWAPFILE is not active."
    start=$(awk '/SwapTotal/ {t=$2} /SwapFree/ {f=$2} END {print t-f}' /proc/meminfo)
    sudo -v
    sudo swapoff "$SWAPFILE" &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
      now=$(awk '/SwapTotal/ {t=$2} /SwapFree/ {f=$2} END {print t-f}' /proc/meminfo)
      echo "==> PROGRESS $(( start > 0 ? 100 - now * 100 / start : 100 ))"
      sleep 2
    done
    wait "$pid"
    sudo swapon "$SWAPFILE"
    echo "==> PROGRESS 100"
    log 'Swap is empty.' ;;
  *) sed -n '2,11p' "$0"; exit 2 ;;
esac
