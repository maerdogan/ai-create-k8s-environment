#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for c in $(clusters); do
  want=$(namespaces "$c" | wc -l)
  have=$(kc "$c" -n metallb-system get ipaddresspool --no-headers | wc -l)
  [[ $want -eq $have ]] || die "$c: $have pools, expected $want."
  log "$c $have pools OK"
done
log 'PASS'
