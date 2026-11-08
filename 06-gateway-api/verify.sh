#!/usr/bin/env bash
# Usage: verify.sh [cluster...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(clusters)
for c in "${targets[@]}"; do
  for crd in gatewayclasses gateways httproutes; do
    kc "$c" get crd "$crd.gateway.networking.k8s.io" >/dev/null || die "$c: $crd is missing."
  done
  log "$c OK"
done
log 'PASS'
