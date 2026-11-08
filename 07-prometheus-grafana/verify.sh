#!/usr/bin/env bash
# Usage: verify.sh [namespace...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(namespaces_like 'prometheus|grafana')
for ns in "${targets[@]}"; do
  [[ $ns == *prometheus* ]] || continue
  ip=$(ns_field "$ns" svc1_ip)
  n=$(node_curl -fsS -m 5 "http://$ip:9090/api/v1/targets" \
    | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["data"]["activeTargets"]))')
  (( n > 0 )) || die "$ns: no active targets."
  log "$ns $ip targets=$n OK"
done
for ns in "${targets[@]}"; do
  [[ $ns == *grafana* ]] || continue
  ip=$(ns_field "$ns" svc1_ip)
  node_curl -fsS -m 5 "http://$ip/api/health" >/dev/null || die "$ns does not answer."
  pass=$(sed -n 's/^password=//p' "$SECRETS/$ns-grafana-admin.env")
  node_curl -fsS -m 5 -u "admin:$pass" "http://$ip/api/dashboards/uid/vks-overview" >/dev/null \
    || die "$ns has no VKS overview dashboard."
  log "$ns $ip dashboard OK"
done
log 'PASS'
