#!/usr/bin/env bash
# Step 11: install dnscore. Connect all clusters and this host to it.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
DNS_IP=$(cat "$GEN/dnscore/server-ip.txt")

kc networking apply -f "$GEN/dnscore/dnscore.yaml"
kc networking -n dnscore rollout status deploy/dnscore --timeout=300s

for c in $(clusters); do
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

log "For host DNS run in a normal terminal: sudo -v && $INSTALL_DIR/02-clusters/routes.sh"
log 'Step 11 is complete. Run verify.sh.'
