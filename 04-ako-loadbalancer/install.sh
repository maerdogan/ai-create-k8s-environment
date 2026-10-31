#!/usr/bin/env bash
# Step 04: install MetalLB as the local replacement for AKO.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
HERE=$INSTALL_DIR/04-ako-loadbalancer
for c in $(clusters); do
  mem_guard
  log "Cluster $c"
  kc "$c" create namespace metallb-system --dry-run=client -o yaml | kc "$c" apply -f -
  kc "$c" apply -f "$HERE/controller-rbac.yaml"
  hc "$c" upgrade --install metallb "$CHARTS/metallb-$METALLB_CHART.tgz" \
    -n metallb-system --create-namespace -f "$HERE/values.yaml" \
    --wait --timeout 5m
  kc "$c" apply -f "$GEN/metallb/$c.yaml"
done
log 'Step 04 is complete. Run verify.sh.'
