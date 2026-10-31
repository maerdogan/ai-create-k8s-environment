#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
kc central-operations get ns deployer >/dev/null
ip=$(ns_field deployer nginx_ip)
code=$(node_curl -s -o /dev/null -m 5 -w '%{http_code}' "http://$ip/" || true)
[[ $code == 404 ]] || die "deployer nginx returned '$code', expected 404."
log "deployer $ip OK"
log 'PASS'
