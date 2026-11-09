#!/usr/bin/env python3
"""Make the IP plan and all manifests from plan.json. Writes only generated/."""
import ipaddress as ipa
import json
import pathlib
import re
import shutil
import string
import time

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
GEN = HERE / "generated"


def read_env(path):
    return dict(
        line.split("=", 1)
        for line in path.read_text().splitlines()
        if line and not line.startswith("#")
    )


SETTINGS = read_env(ROOT / "settings.env") | read_env(HERE / "versions.env")
NAME = SETTINGS["PLATFORM_NAME"]
PLAN = json.loads((HERE / "plan.json").read_text().replace("@NAME@", NAME))
SIZE, VIPS = PLAN["namespace_size"], PLAN["vip_count"]


def fill(template, **values):
    text = (ROOT / template).read_text()
    return string.Template(text).substitute(SETTINGS, **values)


def write(path, text):
    target = GEN / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text.rstrip() + "\n")


def cover(first, last):
    return [str(n) for n in ipa.summarize_address_range(first, last)]


def records():
    out = []
    for cluster in PLAN["clusters"]:
        net = ipa.ip_network(cluster["block"])
        for index, ns in enumerate(cluster["namespaces"]):
            # null keeps a free slot, so the next namespaces keep their IPs.
            if ns is None:
                continue
            base = net.network_address + SIZE * index
            start, end = base + 1, base + SIZE
            out.append({
                "cluster": cluster["name"], "ns": ns,
                "start": start, "end": end,
                "vip_start": start, "vip_end": base + VIPS,
                "pod_start": base + VIPS + 1, "pod_end": end,
                "nginx": base + 10, "svc1": base + 11, "svc2": base + 12,
                "block": cluster["block"], "image": cluster["image"],
            })
    return out


RECORDS = records()
BY_NS = {r["ns"]: r for r in RECORDS}
DB_NS = ("demo-database-1", "tst-database-1", "live-database-1")
COLUMNS = ["cluster", "namespace", "start", "end", "vip_start", "vip_end",
           "pod_start", "pod_end", "nginx_ip", "svc1_ip", "svc2_ip", "block"]


def indent(lines, spaces):
    return ("\n" + " " * spaces).join(lines)


def check_plan():
    assert re.fullmatch("[a-z][a-z0-9-]*", NAME), NAME
    # A Linux interface name has a maximum of 15 characters.
    assert len(f"{NAME}-br0") <= 15, NAME
    vlan = ipa.ip_network(PLAN["network"]["vlan"])
    seen = []
    for cluster in PLAN["clusters"]:
        net = ipa.ip_network(cluster["block"])
        assert net.subnet_of(vlan), net
        assert not any(net.overlaps(o) for o in seen), net
        seen.append(net)
        assert len(cluster["namespaces"]) * SIZE < 768, cluster["name"]
    for r in RECORDS:
        assert int(r["end"]) - int(r["start"]) + 1 == SIZE
        assert ipa.ip_address(r["end"]) in ipa.ip_network(r["block"])


def gen_core():
    rows = ["\t".join(COLUMNS)]
    for r in RECORDS:
        rows.append("\t".join(str(r[k]) for k in (
            "cluster", "ns", "start", "end", "vip_start", "vip_end",
            "pod_start", "pod_end", "nginx", "svc1", "svc2", "block")))
    write("ip-plan.tsv", "\n".join(rows))
    net = PLAN["network"]
    write("network.env", "\n".join((
        f"REGISTRY_IP={net['registry']}", f"NODE_SUBNET={net['infra']}",
        f"NODE_GATEWAY={net['gateway']}", f"NODE_RANGE={net['node_range']}")))

    for cluster in PLAN["clusters"]:
        name, block = cluster["name"], cluster["block"]
        system_pool = ipa.ip_network(block).network_address + 768
        write(f"kind/{name}.yaml", fill(
            "02-clusters/kind.tmpl.yaml", NAME=name, BLOCK=block))
        write(f"calico-system-pool/{name}.txt", f"{system_pool}/24")
        ns_docs, pool_docs, lb_docs = [], [], []
        for r in (x for x in RECORDS if x["cluster"] == name):
            cidrs = cover(r["pod_start"], r["pod_end"])
            names = [f"{r['ns']}-{i}" for i in range(len(cidrs))]
            ns_doc = fill(
                "03-namespaces/namespace.tmpl.yaml", NS=r["ns"], CLUSTER=name,
                POOLS=json.dumps(names), RANGE=f"{r['start']}-{r['end']}")
            pools = [fill("03-namespaces/ippool.tmpl.yaml", POOL=pool, CIDR=cidr,
                          BLOCK_SIZE=cidr.split("/")[1])
                     for pool, cidr in zip(names, cidrs)]
            lb_doc = fill(
                "04-ako-loadbalancer/ipaddresspool.tmpl.yaml", NS=r["ns"],
                FIRST=r["vip_start"], LAST=r["vip_end"])
            # One namespace alone, for 16-control.
            write(f"ns/{r['ns']}/namespace.yaml", ns_doc)
            write(f"ns/{r['ns']}/calico.yaml", "---\n".join(pools))
            write(f"ns/{r['ns']}/metallb.yaml", lb_doc)
            ns_docs.append(ns_doc)
            pool_docs += pools
            lb_docs.append(lb_doc)
        write(f"namespaces/{name}.yaml", "---\n".join(ns_docs))
        write(f"calico-pools/{name}.yaml", "---\n".join(pool_docs))
        write(f"metallb/{name}.yaml", "---\n".join(lb_docs))


def gen_nginx():
    for r in RECORDS:
        write(f"nginx/{r['ns']}.yaml", fill(
            "05-nginx-ingress/values.tmpl.yaml", NS=r["ns"], IP=r["nginx"]))


def gen_prometheus():
    remote = PLAN.get("remote_prometheus", {})
    for r in (x for x in RECORDS if "prometheus" in x["ns"]):
        # A remote Prometheus watches another cluster through its API server.
        target = remote.get(r["ns"], r["cluster"])
        others = [x["ns"] for x in RECORDS
                  if x["cluster"] == target and x["ns"] != r["ns"]]
        sd = ["# Uses the API server of this cluster."]
        if r["ns"] in remote:
            sd = ["api_server: https://@API_IP@:6443", "tls_config:",
                  "  ca_file: /etc/prometheus-remote/ca.crt", "authorization:",
                  "  credentials_file: /etc/prometheus-remote/token"]
            write(f"prometheus/{r['ns']}-reader.yaml", fill(
                "07-prometheus-grafana/remote-reader.tmpl.yaml", NS=r["ns"]))
            write(f"prometheus/{r['ns']}-target.txt", target)
        write(f"prometheus/{r['ns']}.yaml", fill(
            "07-prometheus-grafana/prometheus.tmpl.yaml", NS=r["ns"],
            IP=r["svc1"], TARGETS=indent([f"- {o}" for o in others], 14),
            REMOTE_SD=indent(sd, 12)))
    for grafana, source in (("tst-grafana", "tst-prometheus"),
                            ("live-grafana", "live-prometheus")):
        write(f"grafana/{grafana}.yaml", fill(
            "07-prometheus-grafana/grafana.tmpl.yaml", NS=grafana,
            IP=BY_NS[grafana]["svc1"], PROM_NS=source,
            PROM_IP=BY_NS[source]["svc1"]))


def load_routes():
    routes = []
    path = ROOT / "08-haproxy/routes.tsv"
    for line in path.read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            host, ns = line.split()
            assert ns in BY_NS, ns
            routes.append((host, ns))
    return routes


def gen_haproxy():
    routes = load_routes()
    for ns, scope in (("live-haproxy-1", "live"), ("nw-haproxy-1", None),
                      ("nw-haproxy-2", None)):
        targets = [x for x in RECORDS if scope in (None, x["cluster"])]
        names = {x["ns"] for x in targets}
        backends = "\n".join(
            f"backend be_{x['ns']}\n    server nginx {x['nginx']}:80 check"
            for x in targets)
        route_map = [f"{h} be_{n}" for h, n in routes if n in names]
        write(f"haproxy/{ns}.yaml", fill(
            "08-haproxy/haproxy.tmpl.yaml", NS=ns, IP=BY_NS[ns]["svc1"],
            BACKENDS=indent(backends.splitlines(), 4),
            ROUTES=indent(route_map or ["# no routes"], 4)))


def gen_limits():
    limits = {}
    for line in (ROOT / "09-images/images.tsv").read_text().splitlines()[1:]:
        name, cpu_req, cpu_lim, mem_req, mem_lim, _ = line.split("\t")
        limits[name] = dict(CPU_REQ=cpu_req, CPU_LIM=cpu_lim,
                            MEM_REQ=mem_req, MEM_LIM=mem_lim)
    for r in RECORDS:
        image = "database" if re.search(r"-database(-\d+)?$", r["ns"]) else r["image"]
        if image:
            write(f"limits/{r['ns']}.yaml", fill(
                "09-images/limitrange.tmpl.yaml", NS=r["ns"], IMAGE=image,
                **limits[image]))


def gen_dns():
    a = [("dns", BY_NS["dnscore"]["svc1"]),
         ("registry", PLAN["network"]["registry"])]
    for r in RECORDS:
        a.append((f"nginx-{r['ns']}", r["nginx"]))
    for ns in ("demo-prometheus", "tst-prometheus", "live-prometheus",
               "tst-grafana", "live-grafana", "nw-haproxy-1", "nw-haproxy-2",
               "live-haproxy-1"):
        a.append((ns, BY_NS[ns]["svc1"]))
    for ns in DB_NS:
        a.append((f"postgres-{ns}", BY_NS[ns]["svc1"]))
        a.append((f"mongodb-{ns}", BY_NS[ns]["svc2"]))
    a.append(("influxdb-monitoring-database-1",
              BY_NS["monitoring-database-1"]["svc1"]))
    path = ROOT / "11-dnscore/records.tsv"
    for line in path.read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            name, ip = line.split()
            ipa.ip_address(ip)
            a.append((name, ip))
    lines = [f"{n:<40} IN A {ip}" for n, ip in a]
    write("dnscore/dnscore.yaml", fill(
        "11-dnscore/dnscore.tmpl.yaml", NS="dnscore",
        IP=BY_NS["dnscore"]["svc1"], SERIAL=int(time.time()),
        RECORDS=indent(lines, 4)))
    write("dnscore/server-ip.txt", str(BY_NS["dnscore"]["svc1"]))


def gen_databases():
    for ns in DB_NS:
        write(f"databases/{ns}-postgres.yaml", fill(
            "12-databases/postgres.tmpl.yaml", NS=ns, IP=BY_NS[ns]["svc1"]))
        write(f"databases/{ns}-mongodb.yaml", fill(
            "12-databases/mongodb.tmpl.yaml", NS=ns, IP=BY_NS[ns]["svc2"]))
    ns = "monitoring-database-1"
    write(f"databases/{ns}-influxdb.yaml", fill(
        "12-databases/influxdb.tmpl.yaml", NS=ns, IP=BY_NS[ns]["svc1"]))


def gen_demo_app():
    write("demo-app/Dockerfile", fill(
        "10-demo-app/Dockerfile.tmpl", REGISTRY_IP=PLAN["network"]["registry"]))


def gen_components():
    """The catalog of 16-control: platform, clusters, namespaces and apps."""
    cols = ["id", "type", "cluster", "ns", "deps", "default", "ram_mb",
            "workloads", "manifests", "install", "verify"]
    rows = [["platform", "platform", "-", "-", "-", 50],
            ["images", "images", "-", "-", "platform", 0]]
    for cluster in PLAN["clusters"]:
        rows.append([f"cluster:{cluster['name']}", "cluster", cluster["name"],
                     "-", "platform", 1000])
    for r in RECORDS:
        rows.append([f"ns:{r['ns']}", "namespace", r["cluster"], r["ns"],
                     f"cluster:{r['cluster']}", 60])
    for line in (ROOT / "16-control/apps.tsv").read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        app, ns, deps, ram, *rest = line.split("\t")
        assert ns in BY_NS, f"apps.tsv: {ns} is not in plan.json"
        need = [f"ns:{ns}"] + [d for d in deps.split(",") if d != "-"]
        rows.append([f"app:{app}", "app", BY_NS[ns]["cluster"], ns,
                     ",".join(need), int(ram), *rest])
    ids = {row[0] for row in rows}
    defaults = set(PLAN.get("defaults", []))
    assert defaults <= ids, defaults - ids
    out = ["\t".join(cols)]
    for row in rows:
        assert all(d in ids for d in row[4].split(",") if d != "-"), row
        row = row[:5] + ["1" if row[0] in defaults else "0"] + row[5:]
        row += ["-"] * (len(cols) - len(row))
        out.append("\t".join(str(v) for v in row))
    write("components.tsv", "\n".join(out))


def main():
    check_plan()
    if GEN.exists():
        shutil.rmtree(GEN)
    gen_core()
    gen_nginx()
    gen_prometheus()
    gen_haproxy()
    gen_limits()
    gen_dns()
    gen_databases()
    gen_demo_app()
    gen_components()
    print(f"OK: {len(PLAN['clusters'])} clusters, {len(RECORDS)} namespaces")


if __name__ == "__main__":
    main()
