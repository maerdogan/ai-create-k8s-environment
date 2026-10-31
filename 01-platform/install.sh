#!/usr/bin/env bash
# Step 01: install the local platform. Run root-setup.sh when this script asks.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"

fetch() { [[ -f $2 ]] || curl -fsSL --retry 3 -o "$2" "$1"; }

check_host() {
  local avail
  avail=$(awk '/MemAvailable/ {print int($2/1024/1024)}' /proc/meminfo)
  log "Available memory: ${avail} GiB. The full stack needs about 12 GiB."
  (( avail >= 12 )) || log 'WARNING: Close other programs or run swap-on.sh.'
  grep -q cgroup2 /proc/mounts || die 'cgroup v2 is necessary.'
  local tool
  export PATH=$PATH:/usr/sbin:/sbin
  for tool in curl sudo openssl python3 resolvectl iptables; do
    command -v "$tool" >/dev/null || die "$tool is missing."
  done
}

install_binaries() {
  mkdir -p "$RUNTIME"/{bin,docker-bin,run,tmp,kubeconfig,registry,manifests,helm} "$CHARTS"
  local dl=$RUNTIME/tmp/download
  mkdir -p "$dl"

  fetch "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-amd64" "$dl/kind"
  fetch "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-amd64.sha256sum" "$dl/kind.sha"
  (cd "$dl" && echo "$(cut -d' ' -f1 kind.sha)  kind" | sha256sum -c -)
  install -m 755 "$dl/kind" "$RUNTIME/bin/kind"

  fetch "https://dl.k8s.io/release/$K8S_VERSION/bin/linux/amd64/kubectl" "$dl/kubectl"
  fetch "https://dl.k8s.io/release/$K8S_VERSION/bin/linux/amd64/kubectl.sha256" "$dl/kubectl.sha"
  (cd "$dl" && echo "$(cat kubectl.sha)  kubectl" | sha256sum -c -)
  install -m 755 "$dl/kubectl" "$RUNTIME/bin/kubectl"

  fetch "https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz" "$dl/helm.tgz"
  fetch "https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz.sha256sum" "$dl/helm.sha"
  (cd "$dl" && echo "$(cut -d' ' -f1 helm.sha)  helm.tgz" | sha256sum -c -)
  tar -xzf "$dl/helm.tgz" -C "$dl" linux-amd64/helm
  install -m 755 "$dl/linux-amd64/helm" "$RUNTIME/bin/helm"

  fetch "https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_VERSION.tgz" "$dl/docker.tgz"
  tar -xzf "$dl/docker.tgz" -C "$RUNTIME/docker-bin" --strip-components=1
}

pull_charts() {
  [[ -f $CHARTS/metallb-$METALLB_CHART.tgz ]] || {
    helm repo add metallb https://metallb.github.io/metallb
    helm repo update
    helm pull metallb/metallb --version "$METALLB_CHART" -d "$CHARTS"
  }
  [[ -f $CHARTS/nginx-ingress-$NIC_CHART.tgz ]] ||
    helm pull oci://ghcr.io/nginx/charts/nginx-ingress --version "$NIC_CHART" -d "$CHARTS"
}

wait_daemon() {
  systemctl is-active --quiet "$DOCKER_SERVICE" \
    || die "Docker is not active. In a normal terminal run: sudo $INSTALL_DIR/01-platform/root-setup.sh"
  for _ in {1..30}; do
    docker info >/dev/null 2>&1 && return 0
    sleep 2
  done
  die "Docker does not answer. Run: journalctl -u $DOCKER_SERVICE"
}

create_network() {
  docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1 && return 0
  docker network create "$DOCKER_NETWORK" --driver bridge \
    --subnet "$NODE_SUBNET" --gateway "$NODE_GATEWAY" \
    --ip-range "$NODE_RANGE" \
    --opt com.docker.network.bridge.name="$BRIDGE"
}

start_registry() {
  docker inspect "$REGISTRY_NAME" >/dev/null 2>&1 && return 0
  docker run -d --restart=always --name "$REGISTRY_NAME" \
    --network "$DOCKER_NETWORK" --ip "$REGISTRY_IP" \
    -v "$RUNTIME/registry:/var/lib/registry" "$REGISTRY_IMAGE"
}

check_host
install_binaries
pull_charts
wait_daemon
create_network
start_registry
log 'Step 01 is complete. Run verify.sh.'
