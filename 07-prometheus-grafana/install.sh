#!/usr/bin/env bash
# Step 07: install Prometheus and Grafana.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
for ns in $(namespaces_like prometheus); do
  c=$(cluster_of "$ns")
  log "Prometheus $c/$ns -> $(ns_field "$ns" svc1_ip)"
  api=
  if [[ -f $GEN/prometheus/$ns-target.txt ]]; then
    # Give Prometheus a read-only token of the watched cluster.
    t=$(cat "$GEN/prometheus/$ns-target.txt")
    api=$(node_ip "$t")
    [[ -n $api ]] || die "Cluster $t has no node IP."
    kc "$t" apply -f "$GEN/prometheus/$ns-reader.yaml"
    for _ in {1..30}; do
      token=$(kc "$t" -n kube-system get secret "prometheus-$ns-reader" -o jsonpath='{.data.token}')
      [[ -n $token ]] && break
      sleep 1
    done
    [[ -n $token ]] || die "No token for prometheus-$ns-reader in $t."
    kc "$t" -n kube-system get secret "prometheus-$ns-reader" -o json | python3 -c '
import base64, json, sys
d = json.load(sys.stdin)["data"]
print(json.dumps({"apiVersion": "v1", "kind": "Secret", "type": "Opaque",
  "metadata": {"name": "prometheus-remote", "namespace": sys.argv[1]},
  "data": {"token": d["token"], "ca.crt": d["ca.crt"]}}))' "$ns" | kc "$c" apply -f -
  fi
  sed "s|@API_IP@|$api|" "$GEN/prometheus/$ns.yaml" | kc "$c" apply -f -
  kc "$c" -n "$ns" rollout status statefulset/prometheus --timeout=300s
done
for ns in tst-grafana live-grafana; do
  log "Grafana monitoring/$ns -> $(ns_field "$ns" svc1_ip)"
  ensure_secret monitoring "$ns" grafana-admin password
  kc monitoring -n "$ns" create configmap grafana-dashboards \
    --from-file="$INSTALL_DIR/07-prometheus-grafana/dashboard-overview.json" \
    --dry-run=client -o yaml | kc monitoring apply -f -
  kc monitoring apply -f "$GEN/grafana/$ns.yaml"
  # Grafana reads the data source and dashboards only at start.
  kc monitoring -n "$ns" rollout restart deploy/grafana
  kc monitoring -n "$ns" rollout status deploy/grafana --timeout=300s
done
log 'Step 07 is complete. Run verify.sh.'
