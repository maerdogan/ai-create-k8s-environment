# shellcheck shell=bash
# Shell settings for manual use. Usage: source this file. Do not run it.
_env_root=$(. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../settings.env"; echo "$PLATFORM_ROOT")
export PATH=$_env_root/runtime/bin:$_env_root/runtime/docker-bin:$PATH
export DOCKER_HOST=unix://$_env_root/runtime/run/docker.sock
export KUBECONFIG=$_env_root/runtime/kubeconfig.yaml
export KUBECACHEDIR=$_env_root/runtime/kube-cache
unset _env_root
