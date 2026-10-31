#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for ns in $(namespaces_like haproxy); do
  ip=$(ns_field "$ns" svc1_ip)
  code=$(node_curl -s -o /dev/null -m 5 -w '%{http_code}' -H 'Host: none.invalid' "http://$ip/" || true)
  [[ $code == 503 ]] || die "$ns: http://$ip returned '$code', expected 503."
  log "$ns $ip OK"
done
log 'PASS'
