#!/usr/bin/env bash
# Step 06: install the standard Gateway API CRDs in each cluster.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
CRDS=$RUNTIME/manifests/gateway-api-$GATEWAY_API_VERSION.yaml
[[ -f $CRDS ]] || curl -fsSL --retry 3 -o "$CRDS" \
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/$GATEWAY_API_VERSION/standard-install.yaml"
for c in $(clusters); do
  log "Cluster $c"
  kc "$c" apply --server-side --force-conflicts -f "$CRDS" >/dev/null
done
log 'Step 06 is complete. Run verify.sh.'
