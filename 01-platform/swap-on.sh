#!/usr/bin/env bash
# Optional. Adds swap from a file on the /data disk. Not persistent.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
SIZE_GB=${1:-16}
FILE=$RUNTIME/swapfile
if [[ ! -f $FILE ]]; then
  sudo dd if=/dev/zero of="$FILE" bs=1M count=$((SIZE_GB * 1024)) status=progress
  sudo chmod 600 "$FILE"
  sudo mkswap "$FILE"
fi
swapon --show=NAME --noheadings | grep -qxF "$FILE" || sudo swapon "$FILE"
swapon --show
