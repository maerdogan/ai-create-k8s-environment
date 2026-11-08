#!/usr/bin/env bash
# Usage: verify.sh [cluster...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(clusters)
for c in "${targets[@]}"; do
  kc "$c" -n metallb-system rollout status deploy/metallb-controller --timeout=60s >/dev/null \
    || die "$c: MetalLB controller is not ready."
  have_ns=$(kc "$c" get ns -o name)
  want=0
  for ns in $(namespaces "$c"); do
    grep -qx "namespace/$ns" <<<"$have_ns" && want=$((want + 1))
  done
  have=$(kc "$c" -n metallb-system get ipaddresspool --no-headers | wc -l)
  [[ $want -eq $have ]] || die "$c: $have pools, expected $want."
  log "$c $have pools OK"
done
log 'PASS'
