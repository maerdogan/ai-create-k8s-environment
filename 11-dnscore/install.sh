#!/usr/bin/env bash
# Step 11: install dnscore. Connect all running clusters and this host to it.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
kc networking apply -f "$GEN/dnscore/dnscore.yaml"
kc networking -n dnscore rollout status deploy/dnscore --timeout=300s
bash "$INSTALL_DIR/11-dnscore/link.sh"
log "For host DNS run in a normal terminal: sudo -v && $INSTALL_DIR/02-clusters/routes.sh"
log 'Step 11 is complete. Run verify.sh.'
