#!/usr/bin/env bash
# Usage: patch-calico.sh <input> <output> <system-pool-cidr>
# Turns off tunnels. Sets the default pool for system pods.
set -euo pipefail
sed -e '/name: CALICO_IPV4POOL_IPIP/{n;s/"Always"/"Never"/}' \
    -e 's|# - name: CALICO_IPV4POOL_CIDR|- name: CALICO_IPV4POOL_CIDR|' \
    -e "s|#   value: \"192.168.0.0/16\"|  value: \"$3\"\n            - name: IP_AUTODETECTION_METHOD\n              value: \"interface=eth0\"\n            - name: FELIX_IGNORELOOSERPF\n              value: \"true\"|" \
    "$1" > "$2"
grep -q "value: \"$3\"" "$2"
