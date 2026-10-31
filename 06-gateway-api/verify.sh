#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for c in $(clusters); do
  for crd in gatewayclasses gateways httproutes; do
    kc "$c" get crd "$crd.gateway.networking.k8s.io" >/dev/null || die "$c: $crd is missing."
  done
  log "$c OK"
done
log 'PASS'
