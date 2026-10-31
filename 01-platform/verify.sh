#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
kind version
kubectl version --client
helm version --short
docker info --format 'Docker {{.ServerVersion}} root={{.DockerRootDir}}'
[[ $(docker info --format '{{.DockerRootDir}}') == "$RUNTIME/docker-data" ]] || die 'Docker data is not in runtime.'
ip -br addr show "$BRIDGE"
curl -fsS "http://$REGISTRY_IP:5000/v2/" >/dev/null || die 'Registry does not answer.'
log 'PASS'
