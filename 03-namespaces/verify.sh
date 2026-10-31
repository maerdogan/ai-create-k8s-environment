#!/usr/bin/env bash
# Starts one test pod in each namespace. Checks the pod IP. Removes the pod.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for ns in $(namespaces); do
  c=$(cluster_of "$ns")
  kc "$c" -n "$ns" delete pod ip-check --now --ignore-not-found >/dev/null
  kc "$c" -n "$ns" run ip-check --image=registry.k8s.io/pause:3.10 --restart=Never >/dev/null
  kc "$c" -n "$ns" wait --for=condition=Ready pod/ip-check --timeout=120s >/dev/null
  ip=$(kc "$c" -n "$ns" get pod ip-check -o jsonpath='{.status.podIP}')
  kc "$c" -n "$ns" delete pod ip-check --now >/dev/null
  python3 - "$ip" "$(ns_field "$ns" pod_start)" "$(ns_field "$ns" pod_end)" <<'PY' \
    || die "$ns: pod IP $ip is outside the range."
import ipaddress as i, sys
ip, first, last = map(i.ip_address, sys.argv[1:])
sys.exit(0 if first <= ip <= last else 1)
PY
  log "$ns $ip OK"
done
log 'PASS'
