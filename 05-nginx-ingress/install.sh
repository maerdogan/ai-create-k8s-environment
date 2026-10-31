#!/usr/bin/env bash
# Step 05: install one NGINX controller in each namespace.
# Usage: install.sh [namespace...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(namespaces)
for ns in "${targets[@]}"; do
  mem_guard
  c=$(cluster_of "$ns")
  log "$c/$ns -> $(ns_field "$ns" nginx_ip)"
  hc "$c" upgrade --install "nginx-$ns" "$CHARTS/nginx-ingress-$NIC_CHART.tgz" \
    -n "$ns" --skip-crds -f "$GEN/nginx/$ns.yaml" --wait --timeout 5m
done
log 'Step 05 is complete. Run verify.sh.'
