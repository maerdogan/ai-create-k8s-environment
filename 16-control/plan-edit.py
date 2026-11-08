#!/usr/bin/env python3
"""Add a namespace to a cluster in plan.json. Keeps the format of the file.

Usage: plan-edit.py add <cluster> <namespace>
A free (null) slot is used first, so the IPs of other namespaces do not change.
"""
import json
import pathlib
import re
import sys

PLAN = pathlib.Path(__file__).resolve().parent.parent / "00-common/plan.json"
MAX_SLOTS = 15  # 15 x 50 IPs fit below the system pool of a /22 block.


def main():
    if len(sys.argv) != 4 or sys.argv[1] != "add":
        sys.exit(__doc__)
    cluster, ns = sys.argv[2:]
    if not re.fullmatch(r"[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?", ns):
        sys.exit(f"Bad namespace name: {ns}")
    text = PLAN.read_text()
    plan = json.loads(text)
    names = [n for c in plan["clusters"] for n in c["namespaces"] if n]
    if ns in names:
        sys.exit(f"{ns} is already in the plan.")
    found = [c for c in plan["clusters"] if c["name"] == cluster]
    if not found:
        sys.exit(f"Unknown cluster: {cluster}")
    slots = found[0]["namespaces"]
    if None in slots:
        slots[slots.index(None)] = ns
    elif len(slots) < MAX_SLOTS:
        slots.append(ns)
    else:
        sys.exit(f"{cluster} has no free slot.")
    # Change only the namespaces line of this cluster.
    pattern = re.compile(r'(\{"name": "%s",.*?"namespaces": )\[[^\]]*\]' % re.escape(cluster), re.S)
    new, count = pattern.subn(lambda m: m.group(1) + json.dumps(slots), text, count=1)
    if count != 1:
        sys.exit("plan.json has an unknown format.")
    PLAN.write_text(new)
    print(f"{ns} added to {cluster}.")


if __name__ == "__main__":
    main()
