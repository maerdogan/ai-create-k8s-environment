#!/usr/bin/env bash
# Merge the kubeconfig of each cluster into one file. Keep the current context.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"

OUT=$RUNTIME/kubeconfig.yaml
current=$(kubectl --kubeconfig "$OUT" config current-context 2>/dev/null || true)
[[ -n $current ]] || current=$FIRST_CLUSTER
[[ -f $RUNTIME/kubeconfig/$current.yaml ]] || current=

sources=
for c in $(clusters); do
  [[ -f $RUNTIME/kubeconfig/$c.yaml ]] && sources+=$RUNTIME/kubeconfig/$c.yaml:
done
[[ -n $sources ]] || { rm -f "$OUT"; log 'No cluster exists.'; exit 0; }

umask 077
tmp=$(mktemp "$OUT.XXXXXX")
trap 'rm -f "$tmp"' EXIT
KUBECONFIG=${sources%:} kubectl config view --flatten \
  | sed -E 's/^([ -]*(name|cluster|user|current-context): )kind-/\1/' > "$tmp"
[[ -n $current ]] || current=$(kubectl --kubeconfig "$tmp" config get-contexts -o name | head -1)
kubectl --kubeconfig "$tmp" config use-context "$current" >/dev/null
mv "$tmp" "$OUT"
log "Merged $(kubectl --kubeconfig "$OUT" config get-clusters | tail -n +2 | wc -l) clusters into $OUT"
