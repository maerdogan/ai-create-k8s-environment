#!/usr/bin/env python3
"""Read the component catalog and the inventory. Used by component.sh.

Usage:
  catalog.py status                 id, type, cluster, ns, default, ram_mb, state, label
  catalog.py closure <id>...        missing ids and missing dependencies, install order
  catalog.py dependents <id>...     installed ids that need one of the ids
  catalog.py order install|remove <id>...
  catalog.py get <id> <column>
Environment: CATALOG, INV, DOCKER_STATES, PLATFORM_OK, IMAGES_OK.
"""
import csv
import os
import pathlib
import sys

RANK = {"platform": 0, "images": 1, "cluster": 2, "namespace": 3, "app": 4}


def load():
    with open(os.environ["CATALOG"], newline="") as f:
        rows = list(csv.DictReader(f, delimiter="\t"))
    for r in rows:
        r["deps"] = [] if r["deps"] == "-" else r["deps"].split(",")
    return {r["id"]: r for r in rows}


def docker_states():
    states = {}
    path = os.environ.get("DOCKER_STATES", "")
    if path and pathlib.Path(path).exists():
        for line in pathlib.Path(path).read_text().splitlines():
            name, state = line.split("\t")
            if name.endswith("-control-plane"):
                states[name[: -len("-control-plane")]] = (
                    "running" if state == "running" else "stopped")
    return states


def inventory(cluster, suffix):
    path = pathlib.Path(os.environ["INV"]) / f"{cluster}.{suffix}.tsv"
    if not path.exists():
        return None
    return [line.split("\t") for line in path.read_text().splitlines() if line]


def states(cat):
    nodes = docker_states()
    out = {}
    for cid, r in cat.items():
        kind, cluster = r["type"], r["cluster"]
        if kind == "platform":
            out[cid] = "running" if os.environ.get("PLATFORM_OK") == "1" else "missing"
            continue
        if kind == "images":
            out[cid] = "running" if os.environ.get("IMAGES_OK") == "1" else "missing"
            continue
        node = nodes.get(cluster, "missing")
        if kind == "cluster" or node == "missing":
            out[cid] = node
            continue
        nss = inventory(cluster, "ns")
        if nss is None:
            out[cid] = "unknown"
            continue
        ns_state = {row[1]: row[2] for row in nss}
        if r["ns"] not in ns_state:
            out[cid] = "missing"
            continue
        if kind == "namespace":
            out[cid] = "stopped" if node == "stopped" else ns_state[r["ns"]]
            continue
        apps = {(a[1], f"{a[3]}/{a[4]}"): a[7] for a in inventory(cluster, "apps") or []}
        found = [apps.get((r["ns"], w)) for w in r["workloads"].split(",")]
        if None in found:
            out[cid] = "missing"
        elif node == "stopped" or ns_state[r["ns"]] == "stopped" or "stopped" in found:
            out[cid] = "stopped"
        elif "starting" in found:
            out[cid] = "starting"
        else:
            out[cid] = "running"
    return out


def label(r):
    if r["type"] == "app":
        return f"{r['id'][4:].split('@')[0]} ({r['ns']})"
    if r["type"] in ("cluster", "namespace"):
        return r["cluster"] if r["type"] == "cluster" else r["ns"]
    return r["id"]


def topo(cat, ids):
    seen, out = set(), []

    def visit(cid):
        if cid in seen:
            return
        seen.add(cid)
        for dep in cat[cid]["deps"]:
            visit(dep)
        out.append(cid)
    for cid in sorted(ids, key=lambda c: (RANK[cat[c]["type"]], list(cat).index(c))):
        visit(cid)
    return [c for c in out if c in ids]


def needs(cat, cid, target, memo=None):
    memo = {} if memo is None else memo
    if cid not in memo:
        memo[cid] = False
        memo[cid] = any(d == target or needs(cat, d, target, memo) for d in cat[cid]["deps"])
    return memo[cid]


def main():
    cat = load()
    cmd, args = sys.argv[1], sys.argv[2:]
    for cid in args[1:] if cmd in ("order", "get") else args:
        if cmd == "get":
            break
        if cid not in cat:
            sys.exit(f"Unknown component: {cid}")
    if cmd == "status":
        st = states(cat)
        for cid, r in cat.items():
            print("\t".join([cid, r["type"], r["cluster"], r["ns"], r["default"],
                             r["ram_mb"], st[cid], label(r)]))
    elif cmd == "closure":
        st = states(cat)
        want = set()

        def add(cid):
            if st[cid] == "missing" and cid not in want:
                want.add(cid)
                for dep in cat[cid]["deps"]:
                    add(dep)
        for cid in args:
            add(cid)
        print("\n".join(topo(cat, want)))
    elif cmd == "dependents":
        st = states(cat)
        given = set(args)
        found = {c for c in cat if c not in given and st[c] != "missing"
                 and any(needs(cat, c, g) for g in given)}
        print("\n".join(reversed(topo(cat, found))))
    elif cmd == "order":
        ids = topo(cat, set(args[1:]))
        print("\n".join(ids if args[0] == "install" else reversed(ids)))
    elif cmd == "get":
        print(cat[args[0]][args[1]] if args[0] in cat else "")


if __name__ == "__main__":
    main()
