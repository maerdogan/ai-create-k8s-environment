#!/usr/bin/env bash
# Step 07: install Prometheus and Grafana.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for ns in $(namespaces_like prometheus); do
  c=$(cluster_of "$ns")
  log "Prometheus $c/$ns -> $(ns_field "$ns" svc1_ip)"
  kc "$c" apply -f "$GEN/prometheus/$ns.yaml"
  kc "$c" -n "$ns" rollout status statefulset/prometheus --timeout=300s
done
for ns in tst-grafana live-grafana; do
  log "Grafana monitoring/$ns -> $(ns_field "$ns" svc1_ip)"
  ensure_secret monitoring "$ns" grafana-admin password
  kc monitoring apply -f "$GEN/grafana/$ns.yaml"
  kc monitoring -n "$ns" rollout status deploy/grafana --timeout=300s
done
log 'Step 07 is complete. Run verify.sh.'
