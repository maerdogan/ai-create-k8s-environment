#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
port_open() { node_port_open "$1" "$2" || die "$1:$2 is closed."; log "$1:$2 OK"; }
for ns in demo-database tst-database live-database; do
  port_open "$(ns_field "$ns" svc1_ip)" 5432
  port_open "$(ns_field "$ns" svc2_ip)" 27017
done
node_curl -fsS -m 5 "http://$(ns_field monitoring-database svc1_ip):8086/health" >/dev/null \
  || die 'InfluxDB does not answer.'
log 'PASS'
