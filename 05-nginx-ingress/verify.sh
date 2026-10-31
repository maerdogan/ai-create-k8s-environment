#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for ns in $(namespaces); do
  ip=$(ns_field "$ns" nginx_ip)
  code=$(node_curl -s -o /dev/null -m 5 -w '%{http_code}' "http://$ip/" || true)
  [[ $code == 404 ]] || die "$ns: http://$ip returned '$code', expected 404."
  log "$ns $ip OK"
done
log 'PASS'
