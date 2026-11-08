#!/usr/bin/env bash
# Usage: verify.sh [namespace...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(namespaces_like haproxy)
for ns in "${targets[@]}"; do
  ip=$(ns_field "$ns" svc1_ip)
  code=$(node_curl -s -o /dev/null -m 5 -w '%{http_code}' -H 'Host: none.invalid' "http://$ip/" || true)
  [[ $code == 503 ]] || die "$ns: http://$ip returned '$code', expected 503."
  log "$ns $ip OK"
done
log 'PASS'
