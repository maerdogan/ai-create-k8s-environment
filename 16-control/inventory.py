#!/usr/bin/env python3
"""Make the inventory of one cluster from kubectl and crictl JSON.

Usage: inventory.py <cluster> <prefix> <kubectl.json> <crictl.json> <out-dir>
Writes <cluster>.ns.tsv, <cluster>.apps.tsv and <cluster>.pods.tsv:
  ns:   cluster, ns, state, apps, RAM MiB, system
  apps: cluster, ns, app, kind, name, ready, wanted, state, RAM MiB, system
  pods: cluster, ns, pod, app, RAM MiB, limit MiB, system, kind/name
"""
import json
import pathlib
import re
import sys

SYSTEM = {"default", "kube-system", "kube-public", "kube-node-lease",
          "local-path-storage", "metallb-system"}
KINDS = {"Deployment": "deploy", "StatefulSet": "sts", "DaemonSet": "ds"}
UNITS = {"Ki": 2**10, "Mi": 2**20, "Gi": 2**30, "K": 10**3, "M": 10**6, "G": 10**9}


def mib(text):
    m = re.fullmatch(r"([0-9.]+)([A-Za-z]*)", text or "")
    return int(float(m.group(1)) * UNITS.get(m.group(2), 1) / 2**20) if m else 0


def app_name(ns, name):
    # The NGINX release of a namespace is nginx-<ns>-nginx-ingress-controller.
    return "nginx" if name == f"nginx-{ns}-nginx-ingress-controller" else name


def owner_of(pod):
    """Returns (kind, name) of the workload of a pod."""
    for ref in pod["metadata"].get("ownerReferences", []):
        if ref["kind"] == "ReplicaSet":
            return "deploy", ref["name"].rsplit("-", 1)[0]
        if ref["kind"] in ("StatefulSet", "DaemonSet"):
            return KINDS[ref["kind"]], ref["name"]
    return "pod", pod["metadata"]["name"]


def main():
    cluster, prefix, kube, crictl, out = sys.argv[1:]
    items = json.loads(pathlib.Path(kube).read_text())["items"]
    ram = {}
    try:
        stats = json.loads(pathlib.Path(crictl).read_text()).get("stats", [])
    except (ValueError, OSError):
        stats = []
    for s in stats:
        labels = s["attributes"]["labels"]
        key = (labels.get("io.kubernetes.pod.namespace"), labels.get("io.kubernetes.pod.name"))
        value = s.get("memory", {}).get("workingSetBytes", {}).get("value", 0)
        ram[key] = ram.get(key, 0) + int(value) / 2**20

    stopped_key = f"{prefix}/stopped"
    replicas_key = f"{prefix}/replicas"
    namespaces, apps, pods = {}, [], []
    for it in items:
        if it["kind"] == "Namespace":
            name = it["metadata"]["name"]
            notes = it["metadata"].get("annotations", {})
            namespaces[name] = "stopped" if notes.get(stopped_key) == "true" else "running"
    pod_ram = {}
    for it in items:
        if it["kind"] != "Pod":
            continue
        ns, name = it["metadata"]["namespace"], it["metadata"]["name"]
        used = ram.get((ns, name), 0)
        kind, app = owner_of(it)
        pod_ram[(ns, app)] = pod_ram.get((ns, app), 0) + used
        limit = sum(mib(c.get("resources", {}).get("limits", {}).get("memory"))
                    for c in it["spec"]["containers"])
        pods.append([cluster, ns, name, app_name(ns, app), f"{used:.0f}", limit,
                     int(ns in SYSTEM), f"{kind}/{app}"])
    for it in items:
        kind = KINDS.get(it["kind"])
        if not kind:
            continue
        ns, name = it["metadata"]["namespace"], it["metadata"]["name"]
        notes = it["metadata"].get("annotations", {})
        st = it.get("status", {})
        if kind == "ds":
            want = st.get("desiredNumberScheduled", 0)
            ready = st.get("numberReady", 0)
            selector = it["spec"]["template"]["spec"].get("nodeSelector", {})
            stopped = selector.get(stopped_key) == "true"
        else:
            want = it["spec"].get("replicas", 1)
            ready = st.get("readyReplicas", 0)
            stopped = want == 0
        if stopped or replicas_key in notes:
            state = "stopped" if want == 0 or stopped else "starting"
        else:
            state = "running" if ready >= want else "starting"
        apps.append([cluster, ns, app_name(ns, name), kind, name, ready, want, state,
                     f"{pod_ram.get((ns, name), 0):.0f}", int(ns in SYSTEM)])
    ns_rows = []
    for ns, state in sorted(namespaces.items()):
        mine = [a for a in apps if a[1] == ns]
        used = sum(float(p[4]) for p in pods if p[1] == ns)
        ns_rows.append([cluster, ns, state, len(mine), f"{used:.0f}", int(ns in SYSTEM)])
    out = pathlib.Path(out)
    for suffix, rows in (("ns", ns_rows), ("apps", apps), ("pods", pods)):
        text = "".join("\t".join(map(str, r)) + "\n" for r in rows)
        (out / f"{cluster}.{suffix}.tsv").write_text(text)


if __name__ == "__main__":
    main()
