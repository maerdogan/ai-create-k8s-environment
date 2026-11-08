#!/usr/bin/env bash
# Step 04: install MetalLB as the local replacement for AKO.
# Usage: install.sh [cluster...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
HERE=$INSTALL_DIR/04-ako-loadbalancer
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(clusters)
for c in "${targets[@]}"; do
  mem_guard
  log "Cluster $c"
  kc "$c" create namespace metallb-system --dry-run=client -o yaml | kc "$c" apply -f -
  kc "$c" apply -f "$HERE/controller-rbac.yaml"
  hc "$c" upgrade --install metallb "$CHARTS/metallb-$METALLB_CHART.tgz" \
    -n metallb-system --create-namespace -f "$HERE/values.yaml" \
    --wait --timeout 5m
  # A pool only for the namespaces that exist.
  have=$(kc "$c" get ns -o name)
  for ns in $(namespaces "$c"); do
    grep -qx "namespace/$ns" <<<"$have" && kc "$c" apply -f "$GEN/ns/$ns/metallb.yaml"
  done
done
log 'Step 04 is complete. Run verify.sh.'
