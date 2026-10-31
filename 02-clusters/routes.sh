#!/usr/bin/env bash
# Adds host routes and the host DNS link. Run again after a reboot.
# Needs sudo, so use a normal terminal.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
bash "$INSTALL_DIR/02-clusters/node-routes.sh"
for c in $(clusters); do
  ip=$(node_ip "$c")
  [[ -n $ip ]] || die "No node IP for $c."
  sudo ip route replace "$(block_of "$c")" via "$ip" dev "$BRIDGE"
  log "$(block_of "$c") via $ip ($c)"
done
# The host sends zone names to dnscore.
sudo resolvectl dns "$BRIDGE" "$(cat "$GEN/dnscore/server-ip.txt")"
sudo resolvectl domain "$BRIDGE" "~$DOMAIN"
