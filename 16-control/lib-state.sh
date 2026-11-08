# shellcheck shell=bash
# Shared functions of 16-control. Source this file after 00-common/lib.sh.
# shellcheck disable=SC2034
CONTROL=$INSTALL_DIR/16-control
STATE=$RUNTIME/state
INV=$STATE/inventory
LOGS=$RUNTIME/logs
CATALOG=$GEN/components.tsv
# Annotation prefix for the saved state of stopped objects.
NOTE=$PLATFORM_NAME.local
mkdir -p "$INV" "$LOGS" "$TMPDIR"

# Prints running, stopped or missing.
node_state() {
  local s
  s=$(docker inspect -f '{{.State.Status}}' "$1-control-plane" 2>/dev/null || true)
  case $s in
    running) echo running ;;
    '') echo missing ;;
    *) echo stopped ;;
  esac
}

# Clusters that exist, also stopped ones.
existing_clusters() {
  local all c
  all=$(docker ps -a --format '{{.Names}}' 2>/dev/null || true)
  for c in $(clusters); do
    grep -qx "$c-control-plane" <<<"$all" && echo "$c"
  done
  return 0
}

# Reads the objects and memory use of one running cluster into $INV.
scan_cluster() {
  local c=$1 tmp
  tmp=$(mktemp -d "$TMPDIR/scan-$c.XXXXXX")
  if kc "$c" get ns,deploy,sts,ds,pods -A -o json > "$tmp/kube.json" 2>/dev/null; then
    docker exec "$c-control-plane" crictl stats -o json > "$tmp/stats.json" 2>/dev/null \
      || echo '{}' > "$tmp/stats.json"
    python3 "$CONTROL/inventory.py" "$c" "$NOTE" "$tmp/kube.json" "$tmp/stats.json" "$INV"
  fi
  rm -rf "$tmp"
}

# Usage: scan [cluster...]. Scans running clusters at the same time.
# Keeps the last inventory of a stopped cluster. Removes it for a deleted one.
scan() {
  local targets=("$@") c all
  [[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(running_clusters)
  for c in "${targets[@]}"; do
    [[ $(node_state "$c") == running ]] && scan_cluster "$c" &
  done
  wait
  all=$(existing_clusters)
  for c in $(clusters); do
    grep -qx "$c" <<<"$all" || rm -f "$INV/$c".*.tsv
  done
}

platform_ok() {
  docker info >/dev/null 2>&1 \
    && [[ $(docker inspect -f '{{.State.Running}}' "$REGISTRY_NAME" 2>/dev/null) == true ]]
}

images_ok() {
  local name
  platform_ok || return 1
  while IFS=$'\t' read -r name _; do
    curl -fsS -m 3 "http://$REGISTRY_IP:5000/v2/$PLATFORM_NAME/$name/tags/list" 2>/dev/null \
      | grep -q "\"$IMAGE_TAG\"" || return 1
  done < <(tail -n +2 "$INSTALL_DIR/09-images/images.tsv")
}

# Runs catalog.py with the current Docker state.
catalog() {
  local p=0 i=0
  docker ps -a --format '{{.Names}}\t{{.State}}' > "$STATE/docker.tsv" 2>/dev/null || true
  platform_ok && p=1
  [[ $p -eq 1 ]] && images_ok && i=1
  CATALOG=$CATALOG INV=$INV DOCKER_STATES=$STATE/docker.tsv PLATFORM_OK=$p IMAGES_OK=$i \
    python3 "$CONTROL/catalog.py" "$@"
}

# Usage: row <id>. Sets the catalog columns as variables with the prefix C_.
row() {
  local line
  line=$(awk -F'\t' -v i="$1" '$1==i' "$CATALOG")
  [[ -n $line ]] || die "Unknown component: $1"
  IFS=$'\t' read -r C_ID C_TYPE C_CLUSTER C_NS C_DEPS C_DEFAULT C_RAM C_WORKLOADS \
    C_MANIFESTS C_INSTALL C_VERIFY <<<"$line"
}

# Runs a step script with arguments from one string, for example "08-haproxy/install.sh nw-haproxy-1".
run_step() {
  local parts
  read -ra parts <<<"$1"
  bash "$INSTALL_DIR/${parts[0]}" "${parts[@]:1}"
}

# Free memory in MiB.
mem_free_mb() { awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo; }
