#!/usr/bin/env bash
# Usage: verify.sh [cluster...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(clusters)
for c in "${targets[@]}"; do
  [[ $(kc "$c" get nodes --no-headers) == *' Ready '* ]] || die "$c node is not Ready."
  [[ $(kc "$c" get ippool default-ipv4-ippool -o jsonpath='{.spec.ipipMode}') == Never ]] \
    || die "$c: default pool has a tunnel."
  [[ $(ip route show "$(block_of "$c")") == *"dev $BRIDGE"* ]] || log "INFO: $c has no host route. Run routes.sh."
  log "$c OK"
done
log 'PASS'
