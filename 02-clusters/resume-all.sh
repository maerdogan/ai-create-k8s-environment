#!/usr/bin/env bash
# Starts all stopped cluster nodes. Then run routes.sh in a normal terminal.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for c in $(clusters); do
  docker inspect "$c-control-plane" >/dev/null 2>&1 || continue
  docker start "$c-control-plane" >/dev/null
  log "$c started"
done
bash "$INSTALL_DIR/02-clusters/node-routes.sh"
