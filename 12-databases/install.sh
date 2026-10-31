#!/usr/bin/env bash
# Step 12: install database servers. Application databases come later.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for ns in demo-database tst-database live-database; do
  mem_guard
  c=$(cluster_of "$ns")
  ensure_secret "$c" "$ns" postgres-admin password
  ensure_secret "$c" "$ns" mongodb-admin password
  kc "$c" apply -f "$GEN/databases/$ns-postgres.yaml"
  kc "$c" apply -f "$GEN/databases/$ns-mongodb.yaml"
  kc "$c" -n "$ns" rollout status statefulset/postgres --timeout=300s
  kc "$c" -n "$ns" rollout status statefulset/mongodb --timeout=300s
done
ns=monitoring-database
ensure_secret monitoring "$ns" influxdb-admin password token
kc monitoring apply -f "$GEN/databases/$ns-influxdb.yaml"
kc monitoring -n "$ns" rollout status statefulset/influxdb --timeout=300s
log 'Step 12 is complete. Run verify.sh.'
