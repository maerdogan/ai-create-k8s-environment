#!/usr/bin/env bash
# Usage: verify.sh [server@namespace...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
port_open() { node_port_open "$1" "$2" || die "$1:$2 is closed."; log "$1:$2 OK"; }
targets=("$@")
if [[ ${#targets[@]} -eq 0 ]]; then
  for f in "$GEN"/databases/*.yaml; do
    b=$(basename "$f" .yaml)
    targets+=("${b##*-}@${b%-*}")
  done
fi
for t in "${targets[@]}"; do
  db=${t%@*} ns=${t#*@}
  case $db in
    postgres) port_open "$(ns_field "$ns" svc1_ip)" 5432 ;;
    mongodb) port_open "$(ns_field "$ns" svc2_ip)" 27017 ;;
    influxdb)
      node_curl -fsS -m 5 "http://$(ns_field "$ns" svc1_ip):8086/health" >/dev/null \
        || die "InfluxDB in $ns does not answer."
      log "$ns influxdb OK" ;;
    *) die "Unknown server $db." ;;
  esac
done
log 'PASS'
