#!/usr/bin/env bash
# Step 15: build pcap-analyzer from GitHub and deploy it.
# Usage: install.sh [--build-only]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
NS=pcap-analyzer
SRC=$RUNTIME/apps/pcap-analyzer
HOST=pcap-analyzer.$DOMAIN
CERT=$SECRETS/pcap-analyzer-tls.crt
KEY=$SECRETS/pcap-analyzer-tls.key
PASSFILE=$SECRETS/pcap-analyzer-admin.env
# The static Docker package has no buildx plugin.
export DOCKER_BUILDKIT=0

mem_guard
[[ -d $SRC/.git ]] || git clone -q "$PCAP_ANALYZER_REPO" "$SRC"
git -C "$SRC" fetch -q origin main
git -C "$SRC" checkout -q --detach origin/main
sha=$(git -C "$SRC" rev-parse --short=12 HEAD)
image=$REGISTRY_IP:5000/$PLATFORM_NAME/pcap-analyzer:$sha

log "Build $image"
docker build -q -t "$image" -f "$SRC/Containerfile" "$SRC"
docker push -q "$image"
[[ ${1:-} != --build-only ]] || { log "Image $image is ready."; exit 0; }

install -d -m 700 "$SECRETS"
# Keep the password of a running application.
if ! kc analyzer -n "$NS" get secret pcap-analyzer-admin >/dev/null 2>&1; then
  ( umask 077; printf 'PCAP_ANALYZER_ADMIN_PASSWORD=%s\n' "$(openssl rand -hex 16)" > "$PASSFILE" )
  pass=$(sed -n 's/^PCAP_ANALYZER_ADMIN_PASSWORD=//p' "$PASSFILE")
  hash=$(docker run --rm -e "PASS=$pass" --entrypoint python "$image" -c \
    'import os; from pcap_analyzer.web.auth import hash_password as h; print(h(os.environ["PASS"]))')
  kc analyzer -n "$NS" create secret generic pcap-analyzer-admin \
    --from-literal=password-hash="$hash"
fi
[[ -f $CERT ]] || ( umask 077
  openssl req -x509 -newkey rsa:2048 -nodes -days 825 -keyout "$KEY" -out "$CERT" \
    -subj "/CN=$HOST" -addext "subjectAltName=DNS:$HOST" 2>/dev/null )
kc analyzer -n "$NS" create secret tls pcap-analyzer-tls --cert="$CERT" --key="$KEY" \
  --dry-run=client -o yaml | kc analyzer apply -f -

sed "s|@IMAGE@|$image|" "$GEN/pcap-analyzer/app.yaml" | kc analyzer apply -f -
kc analyzer -n "$NS" rollout status deploy/pcap-analyzer --timeout=300s
log "Step 15 is complete: $sha. Run 11-dnscore/install.sh for the name. Run verify.sh."
