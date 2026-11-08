#!/usr/bin/env bash
# Sends the DNS zone of each cluster to dnscore. Usage: link.sh [cluster...]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
DNS_IP=$(cat "$GEN/dnscore/server-ip.txt")
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || mapfile -t targets < <(running_clusters)
for c in "${targets[@]}"; do
  corefile=$(kc "$c" -n kube-system get cm coredns -o jsonpath='{.data.Corefile}')
  if ! grep -q "^$DOMAIN:53" <<<"$corefile"; then
    file=$TMPDIR/Corefile-$c
    {
      printf '%s:53 {\n    errors\n    cache 30\n    forward . %s\n}\n' "$DOMAIN" "$DNS_IP"
      printf '%s\n' "$corefile"
    } > "$file"
    kc "$c" -n kube-system create cm coredns --from-file=Corefile="$file" \
      --dry-run=client -o yaml | kc "$c" apply -f -
    kc "$c" -n kube-system rollout restart deploy/coredns
    rm -f "$file"
  fi
  kc "$c" -n kube-system rollout status deploy/coredns --timeout=180s
done
