#!/usr/bin/env bash
# Step 08: install HAProxy in each haproxy namespace.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for ns in $(namespaces_like haproxy); do
  c=$(cluster_of "$ns")
  log "$c/$ns -> $(ns_field "$ns" svc1_ip)"
  kc "$c" apply -f "$GEN/haproxy/$ns.yaml"
  kc "$c" -n "$ns" rollout restart deploy/haproxy
  kc "$c" -n "$ns" rollout status deploy/haproxy --timeout=300s
done
log 'Step 08 is complete. Run verify.sh.'
