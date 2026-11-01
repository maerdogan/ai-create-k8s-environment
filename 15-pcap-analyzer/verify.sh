#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
HOST=pcap-analyzer.$DOMAIN
IP=$(ns_field pcap-analyzer nginx_ip)
url() { printf 'https://%s%s' "$HOST" "$1"; }
call() { node_curl -sk -m 10 --resolve "$HOST:443:$IP" -o /dev/null -w '%{http_code}' "$@" || true; }
password=$(sed -n 's/^PCAP_ANALYZER_ADMIN_PASSWORD=//p' "$SECRETS/pcap-analyzer-admin.env")

# NGINX needs some seconds to find a new pod.
for _ in {1..15}; do
  code=$(call "$(url /healthz)")
  [[ $code == 200 ]] && break
  sleep 2
done
[[ $code == 200 ]] || die "healthz returned '$code', expected 200."
code=$(call --data-urlencode username=admin --data-urlencode password=wrong "$(url /login)")
[[ $code != 303 ]] || die 'Login accepted a wrong password.'
code=$(call --data-urlencode username=admin --data-urlencode "password=$password" "$(url /login)")
[[ $code == 303 ]] || die "Login returned '$code', expected 303."
log "$HOST $IP OK"
log 'PASS'
