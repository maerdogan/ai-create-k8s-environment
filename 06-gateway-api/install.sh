#!/usr/bin/env bash
# Step 06: install the standard Gateway API CRDs in each cluster.
# Usage: install.sh [cluster...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
CRDS=$RUNTIME/manifests/gateway-api-$GATEWAY_API_VERSION.yaml
[[ -f $CRDS ]] || curl -fsSL --retry 3 -o "$CRDS" \
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/$GATEWAY_API_VERSION/standard-install.yaml"
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(clusters)
for c in "${targets[@]}"; do
  log "Cluster $c"
  kc "$c" apply --server-side --force-conflicts -f "$CRDS" >/dev/null
done
log 'Step 06 is complete. Run verify.sh.'
