#!/usr/bin/env bash
# Offline check. It does not touch Docker or a cluster.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$HERE")
source "$ROOT/settings.env"
source "$HERE/versions.env"
RT=$PLATFORM_ROOT/runtime
KUBE=${K8S_VERSION#v}
T=$RT/tools
export TMPDIR=$RT/tmp PYTHONPATH=$T/py
export HELM_CACHE_HOME=$T/h HELM_CONFIG_HOME=$T/h HELM_DATA_HOME=$T/h
mkdir -p "$T/kubeconform-cache" "$TMPDIR"
fail=0
step() { printf '== %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

step 'plan.py'
python3 "$HERE/plan.py" || bad plan.py

step 'bash -n'
while IFS= read -r f; do bash -n "$f" || bad "$f"; done \
  < <(find "$ROOT" -name '*.sh' -not -path '*/generated/*')

have() {
  [[ -x $T/bin/$1 ]] && return 0
  printf 'SKIP: %s is not in %s/bin\n' "$1" "$T"
  return 1
}

step 'shellcheck'
have shellcheck && { find "$ROOT" -name '*.sh' -not -path '*/generated/*' -print0 \
  | xargs -0 "$T/bin/shellcheck" -x -S warning -e SC1091 -e SC2329 || bad shellcheck; }

step 'yamllint'
if python3 -m yamllint --version >/dev/null 2>&1; then
  python3 -m yamllint -d '{extends: relaxed, rules: {line-length: disable}}' \
    "$HERE/generated" || bad yamllint
else
  echo 'SKIP: yamllint is not installed'
fi

if ! have kubeconform || ! have helm; then
  [[ $fail -eq 0 ]] && echo 'RESULT: PASS' || echo 'RESULT: FAIL'
  exit $fail
fi

step 'kubeconform'
find "$HERE/generated" -name '*.yaml' -not -path '*/kind/*' \
  -not -path '*/nginx/*' -print0 \
  | xargs -0 "$T/bin/kubeconform" -summary -strict \
      -kubernetes-version "$KUBE" -ignore-missing-schemas \
      -cache "$T/kubeconform-cache" || bad kubeconform

step 'helm template'
for f in "$HERE"/generated/nginx/*.yaml; do
  ns=$(basename "$f" .yaml)
  "$T/bin/helm" template "nginx-$ns" "$RT/charts/nginx-ingress-$NIC_CHART.tgz" \
    -n "$ns" -f "$f" --skip-crds 2>&1 \
    | "$T/bin/kubeconform" -strict -kubernetes-version "$KUBE" \
        -ignore-missing-schemas -cache "$T/kubeconform-cache" -summary \
        > "$TMPDIR/nginx.out" || { cat "$TMPDIR/nginx.out"; bad "nginx $ns"; }
done
tail -1 "$TMPDIR/nginx.out"
"$T/bin/helm" template metallb "$RT/charts/metallb-$METALLB_CHART.tgz" \
  -n metallb-system -f "$ROOT/04-ako-loadbalancer/values.yaml" >"$TMPDIR/mlb.yaml" \
  && "$T/bin/kubeconform" -strict -kubernetes-version "$KUBE" \
       -ignore-missing-schemas -cache "$T/kubeconform-cache" -summary "$TMPDIR/mlb.yaml" \
  || bad metallb

[[ $fail -eq 0 ]] && echo 'RESULT: PASS' || echo 'RESULT: FAIL'
exit $fail
