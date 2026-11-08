#!/usr/bin/env bash
# Lowers memory use. Run after clusters exist. Restarts control planes one by one.
# Usage: tune-memory.sh [cluster...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
M=/etc/kubernetes/manifests
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(running_clusters)
for c in "${targets[@]}"; do
  node=$c-control-plane
  for f in kube-apiserver kube-controller-manager; do
    docker exec "$node" sh -c "grep -q GOGC $M/$f.yaml || sed -i 's/^  - command:/  - env:\n    - name: GOGC\n      value: \"40\"\n    command:/' $M/$f.yaml"
  done
  sleep 20
  for _ in {1..60}; do
    kc "$c" get --raw=/readyz >/dev/null 2>&1 && break
    sleep 5
  done
  kc "$c" get --raw=/readyz >/dev/null || die "$c API is not ready."
  for _ in {1..12}; do
    kc "$c" -n kube-system scale deploy/coredns --replicas=1 && break
    sleep 5
  done
  log "$c tuned"
done
