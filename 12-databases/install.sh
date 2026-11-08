#!/usr/bin/env bash
# Step 12: install database servers. Application databases come later.
# Usage: install.sh [server@namespace...], for example postgres@tst-database-1
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
targets=("$@")
if [[ ${#targets[@]} -eq 0 ]]; then
  for f in "$GEN"/databases/*.yaml; do
    b=$(basename "$f" .yaml)
    targets+=("${b##*-}@${b%-*}")
  done
fi
for t in "${targets[@]}"; do
  mem_guard
  db=${t%@*} ns=${t#*@}
  c=$(cluster_of "$ns")
  [[ -f $GEN/databases/$ns-$db.yaml ]] || die "No $db plan for $ns."
  keys=(password)
  [[ $db != influxdb ]] || keys=(password token)
  ensure_secret "$c" "$ns" "$db-admin" "${keys[@]}"
  kc "$c" apply -f "$GEN/databases/$ns-$db.yaml"
  kc "$c" -n "$ns" rollout status "statefulset/$db" --timeout=300s
done
log 'Step 12 is complete. Run verify.sh.'
