#!/usr/bin/env bash
# Adds a route in each node to the blocks of the other clusters. Needs no sudo.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
mapfile -t all < <(clusters)
for c in "${all[@]}"; do
  [[ -n $(node_ip "$c") ]] || continue
  for o in "${all[@]}"; do
    ip=$(node_ip "$o")
    [[ $o != "$c" && -n $ip ]] || continue
    docker exec "$c-control-plane" ip route replace "$(block_of "$o")" via "$ip"
  done
done
log 'Node routes are set.'
