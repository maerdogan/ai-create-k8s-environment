#!/usr/bin/env bash
# Common functions. Every step script sources this file.
# shellcheck disable=SC2034
set -euo pipefail

COMMON=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
INSTALL_DIR=$(dirname "$COMMON")
GEN=$COMMON/generated
PLAN_TSV=$GEN/ip-plan.tsv

# shellcheck source=/dev/null
source "$INSTALL_DIR/settings.env"
# shellcheck source=/dev/null
source "$COMMON/versions.env"

RUNTIME=$PLATFORM_ROOT/runtime
CHARTS=$RUNTIME/charts
SECRETS=$RUNTIME/secrets
BRIDGE=$PLATFORM_NAME-br0
DOCKER_NETWORK=$PLATFORM_NAME-net
DOCKER_SERVICE=$PLATFORM_NAME-docker.service
REGISTRY_NAME=$PLATFORM_NAME-registry

export PATH=$RUNTIME/bin:$RUNTIME/docker-bin:$PATH
export DOCKER_HOST=unix://$RUNTIME/run/docker.sock
export KIND_EXPERIMENTAL_DOCKER_NETWORK=$DOCKER_NETWORK
export TMPDIR=$RUNTIME/tmp
export KUBECACHEDIR=$RUNTIME/kube-cache
export HELM_CACHE_HOME=$RUNTIME/helm/cache
export HELM_CONFIG_HOME=$RUNTIME/helm/config
export HELM_DATA_HOME=$RUNTIME/helm/data

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Stop if the plan output does not exist.
[[ -f $PLAN_TSV ]] || die "Run: python3 $COMMON/plan.py"
# shellcheck source=/dev/null
source "$GEN/network.env"

clusters() { awk -F'\t' 'NR>1 && !s[$1]++ {print $1}' "$PLAN_TSV"; }
namespaces() { awk -F'\t' -v c="${1:-}" 'NR>1 && (c=="" || $1==c) {print $2}' "$PLAN_TSV"; }
cluster_of() { awk -F'\t' -v n="$1" '$2==n {print $1}' "$PLAN_TSV"; }
block_of() { awk -F'\t' -v c="$1" '$1==c {print $12; exit}' "$PLAN_TSV"; }
image_ref() { printf '%s:5000/%s/%s:%s' "$REGISTRY_IP" "$PLATFORM_NAME" "$1" "$IMAGE_TAG"; }
# Prints nothing if the node does not exist.
node_ip() {
  docker inspect -f "{{(index .NetworkSettings.Networks \"$DOCKER_NETWORK\").IPAddress}}" \
    "$1-control-plane" 2>/dev/null || true
}

# Usage: ns_field <namespace> <column-name>
ns_field() {
  awk -F'\t' -v n="$1" -v f="$2" '
    NR==1 {for (i=1;i<=NF;i++) if ($i==f) c=i; next}
    $2==n {print $c}' "$PLAN_TSV"
}

kc() { local c=$1; shift; kubectl --kubeconfig "$RUNTIME/kubeconfig/$c.yaml" "$@"; }
hc() { local c=$1; shift; helm --kubeconfig "$RUNTIME/kubeconfig/$c.yaml" "$@"; }

# Print namespaces whose name matches a regular expression.
namespaces_like() { namespaces | grep -E "$1"; }

# Usage: ensure_secret <cluster> <namespace> <secret> key [key...]
# Makes one random value for each key. Keeps the values in $SECRETS.
ensure_secret() {
  local c=$1 ns=$2 name=$3; shift 3
  local file=$SECRETS/$ns-$name.env args=() key
  install -d -m 700 "$SECRETS"
  if [[ ! -f $file ]]; then
    ( umask 077; for key in "$@"; do
        printf '%s=%s\n' "$key" "$(openssl rand -hex 16)"
      done > "$file" )
  fi
  args=(--from-env-file="$file")
  kc "$c" -n "$ns" create secret generic "$name" "${args[@]}" \
    --dry-run=client -o yaml | kc "$c" apply -f -
}

need_plan_ready() { [[ -x $RUNTIME/bin/kubectl ]] || die "Do step 01 first."; }

# Stop before the host runs out of memory.
mem_guard() {
  local mb
  mb=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  (( mb >= ${MIN_MEM_MB:-1500} )) || die "Only ${mb} MiB memory is free. Stop."
}

# Tests run in one node, so they do not need host routes.
FIRST_CLUSTER=$(awk -F'\t' 'NR==2 {print $1; exit}' "$PLAN_TSV")
PROBE_NODE=$FIRST_CLUSTER-control-plane
node_curl() { docker exec "$PROBE_NODE" curl "$@"; }
node_port_open() { docker exec "$PROBE_NODE" timeout 5 bash -c "exec 3<>/dev/tcp/$1/$2"; }
