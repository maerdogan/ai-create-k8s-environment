#!/usr/bin/env python3
"""Find the objects of one app in a namespace.

Usage: related.py <kind/name> <objects.json> [--pvc]
objects.json is "kubectl get deploy,sts,ds,svc,ingress,httproute,pvc -o json".
Prints the Services, Ingresses and HTTPRoutes of the workload.
With --pvc it prints only the PersistentVolumeClaims of the workload.
"""
import json
import re
import sys

KINDS = {"deploy": "Deployment", "sts": "StatefulSet", "ds": "DaemonSet"}


def main():
    target, path = sys.argv[1], sys.argv[2]
    short, name = target.split("/", 1)
    items = json.load(open(path))["items"]
    work = next((i for i in items if i["kind"] == KINDS[short]
                 and i["metadata"]["name"] == name), None)
    if work is None:
        return
    spec = work["spec"]["template"]["spec"]
    if "--pvc" in sys.argv:
        claims = {v["persistentVolumeClaim"]["claimName"]
                  for v in spec.get("volumes", []) if "persistentVolumeClaim" in v}
        templates = [t["metadata"]["name"] for t in work["spec"].get("volumeClaimTemplates", [])]
        for i in items:
            n = i["metadata"]["name"]
            if i["kind"] == "PersistentVolumeClaim" and (
                    n in claims or any(re.fullmatch(f"{t}-{name}-[0-9]+", n) for t in templates)):
                print(f"pvc/{n}")
        return
    labels = work["spec"]["template"]["metadata"].get("labels", {})
    services = set()
    for i in items:
        sel = i.get("spec", {}).get("selector") if i["kind"] == "Service" else None
        if sel and all(labels.get(k) == v for k, v in sel.items()):
            services.add(i["metadata"]["name"])
            print(f"service/{i['metadata']['name']}")
    for i in items:
        text = json.dumps(i.get("spec", {}))
        if i["kind"] == "Ingress" and any(
                f'"name": "{s}"' in text for s in services):
            print(f"ingress/{i['metadata']['name']}")
        if i["kind"] == "HTTPRoute" and any(
                f'"name": "{s}"' in text for s in services):
            print(f"httproute.gateway.networking.k8s.io/{i['metadata']['name']}")


if __name__ == "__main__":
    main()
