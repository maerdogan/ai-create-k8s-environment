#!/usr/bin/env bash
# Step 03: create pod IP pools and namespaces.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for c in $(clusters); do
  log "Cluster $c"
  kc "$c" apply -f "$GEN/calico-pools/$c.yaml" >/dev/null
  kc "$c" apply -f "$GEN/namespaces/$c.yaml"
done
log 'Step 03 is complete. Run verify.sh.'
