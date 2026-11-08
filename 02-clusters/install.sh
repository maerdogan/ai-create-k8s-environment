#!/usr/bin/env bash
# Step 02: create the clusters. Usage: install.sh [cluster...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
HERE=$INSTALL_DIR/02-clusters
need_plan_ready

BASE=$RUNTIME/manifests/calico-$CALICO_VERSION.yaml
[[ -f $BASE ]] || curl -fsSL --retry 3 -o "$BASE" \
  "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/calico.yaml"

add_registry() {
  local node=$1-control-plane dir=/etc/containerd/certs.d/$REGISTRY_IP:5000
  docker exec "$node" mkdir -p "$dir"
  printf '[host."http://%s:5000"]\n' "$REGISTRY_IP" \
    | docker exec -i "$node" cp /dev/stdin "$dir/hosts.toml"
}

create_cluster() {
  local c=$1 manifest
  if [[ $'\n'$(kind get clusters 2>/dev/null)$'\n' != *$'\n'"$c"$'\n'* ]]; then
    log "Create cluster $c"
    kind create cluster --name "$c" --image "$KIND_NODE_IMAGE" \
      --config "$GEN/kind/$c.yaml" --wait 0s \
      --kubeconfig "$RUNTIME/kubeconfig/$c.yaml"
  fi
  add_registry "$c"
  manifest=$RUNTIME/manifests/calico-$c.yaml
  bash "$HERE/patch-calico.sh" "$BASE" "$manifest" "$(cat "$GEN/calico-system-pool/$c.txt")"
  kc "$c" apply --server-side --force-conflicts -f "$manifest" >/dev/null
  kc "$c" wait --for=condition=Ready node --all --timeout=300s
  kc "$c" -n kube-system rollout status deploy/coredns --timeout=300s
}

targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(clusters)
for c in "${targets[@]}"; do mem_guard; create_cluster "$c"; done
bash "$HERE/node-routes.sh"
bash "$HERE/tune-memory.sh" "${targets[@]}"
bash "$HERE/merge-kubeconfig.sh"
log 'Step 02 is complete. Run verify.sh.'
log "For host access run in a normal terminal: sudo -v && $HERE/routes.sh"
