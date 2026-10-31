#!/usr/bin/env bash
# Merge the kubeconfig of each cluster into one file. Keep the current context.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"

OUT=$RUNTIME/kubeconfig.yaml
current=$(kubectl --kubeconfig "$OUT" config current-context 2>/dev/null || true)
[[ -n $current ]] || current=$FIRST_CLUSTER

sources=
for c in $(clusters); do sources+=$RUNTIME/kubeconfig/$c.yaml:; done

umask 077
tmp=$(mktemp "$OUT.XXXXXX")
trap 'rm -f "$tmp"' EXIT
KUBECONFIG=${sources%:} kubectl config view --flatten \
  | sed -E 's/^([ -]*(name|cluster|user|current-context): )kind-/\1/' > "$tmp"
kubectl --kubeconfig "$tmp" config use-context "$current" >/dev/null
mv "$tmp" "$OUT"
log "Merged $(kubectl --kubeconfig "$OUT" config get-clusters | tail -n +2 | wc -l) clusters into $OUT"
