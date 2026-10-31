#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
DNS_IP=$(cat "$GEN/dnscore/server-ip.txt")
NAME=dns.$DOMAIN
for c in $(clusters); do
  ip=$(kc "$c" -n default run dns-check --rm -i --restart=Never -q \
    --image=busybox:1.37 -- nslookup "$NAME" 2>/dev/null \
    | awk '/^Address/ && !/:53/ {print $NF}' | tail -1 || true)
  [[ $ip == "$DNS_IP" ]] || die "$c: $NAME returned '$ip'."
  log "$c $NAME=$ip OK"
done
host_ip=$(resolvectl query --legend=no "$NAME" 2>/dev/null | awk 'NR==1 {print $2}' || true)
[[ $host_ip == "$DNS_IP" ]] || log "INFO: host DNS is not set. Run routes.sh."
log 'PASS'
