#!/usr/bin/env python3
"""Make README.txt and ROADMAP.md for each step. One template for all."""
import pathlib
import textwrap

ROOT = pathlib.Path(__file__).resolve().parent.parent
WIDTH = 78
FOOTER = "# vim: set ft=text tw=78 nowrap nospell:"
COMMON_RULES = [
    "Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.",
    "Do not use the latest tag. Change versions in 00-common/versions.env.",
    "Do not edit 00-common/generated. Edit plan.json or a template.",
    "After each change run 00-common/validate.sh.",
    "If a check fails, stop. Do not go to the next step.",
]

STEPS = {
    "01-platform": dict(
        title="LOCAL PLATFORM",
        summary=["Install Docker, kind, kubectl and helm in $PLATFORM_ROOT/runtime.",
                 "Create the Docker network and the local image registry.",
                 "This platform replaces VMware VKS on one host."],
        flow=["Check host", "Install binaries", "Start Docker", "Create network", "Start registry"],
        before=["The host has internet access.", "The user has sudo access."],
        run=["./install.sh", "In a normal terminal: sudo ./root-setup.sh", "./install.sh", "Optional, if memory is low: ./swap-on.sh 16"],
        files=["install.sh", "root-setup.sh", "verify.sh", "swap-on.sh", "daemon.tmpl.json",
               "docker.tmpl.service", "sysctl.conf"],
        goal="Make the container platform for all clusters.",
        done=["verify.sh shows PASS.", "Docker data is in $PLATFORM_ROOT/runtime/docker-data."],
        notes=["VMware VKS needs vCenter, ESXi and Supervisor. One host cannot run them.",
               "sudo writes two files: /etc/systemd/system/$PLATFORM_NAME-docker.service and /etc/sysctl.d/90-$PLATFORM_NAME.conf.",
               "This Docker service uses its own socket. Load it with lib.sh.",
               "sudo does not work in app terminals. Use a normal terminal.",
               "K8S_VERSION in versions.env sets the Kubernetes version."],
    ),
    "02-clusters": dict(
        title="CLUSTERS",
        summary=["Create 8 kind clusters with one node each.",
                 "Install Calico in each cluster.",
                 "Add one host route for each /22 block."],
        flow=["Create cluster", "Add registry link", "Install Calico", "Wait for node", "Add host routes"],
        before=["Step 01 is complete."],
        run=["./install.sh", "One cluster only: ./install.sh demo", "In a normal terminal: sudo -v && ./routes.sh", "After a reboot: run routes.sh again.", "For kubectl: source env.sh", "Change cluster: kubectl config use-context test"],
        files=["install.sh", "verify.sh", "routes.sh", "node-routes.sh", "tune-memory.sh", "resume-all.sh", "patch-calico.sh", "kind.tmpl.yaml", "merge-kubeconfig.sh", "env.sh"],
        goal="Create all clusters in plan.json.",
        done=["verify.sh shows PASS.", "All 8 nodes are Ready."],
        notes=["network.infra in plan.json is the node network. It is part of network.vlan.",
               "Host routes send each /22 block to its node.",
               "The last /24 of each block is for system pods.",
               "Do not change podSubnet after the cluster exists.",
               "tune-memory.sh sets GOGC=40 on control planes. Without it the host thrashes.",
               "Run routes.sh after all clusters exist."],
    ),
    "03-namespaces": dict(
        title="NAMESPACES AND IP RANGES",
        summary=["Create 30 namespaces.",
                 "Give each namespace 50 IPs: 20 for Services, 30 for pods.",
                 "Calico pools hold pods in the range of the namespace."],
        flow=["Read ip-plan.tsv", "Create Calico pools", "Create namespaces", "Test pod IP"],
        before=["Step 02 is complete."],
        run=["./install.sh"],
        files=["install.sh", "verify.sh", "namespace.tmpl.yaml", "ippool.tmpl.yaml",
               "../00-common/generated/ip-plan.tsv"],
        goal="Create namespaces and hold each one in its 50 IP range.",
        done=["verify.sh shows PASS. Each test pod has an IP in pod_start to pod_end."],
        notes=["Namespace number N uses block start + 50 x (N-1) + 1 to + 50.",
               "central-operations has only namespace deployer.",
               "A pod stays Pending if the 30 pod IPs are in use. This is correct."],
    ),
    "04-ako-loadbalancer": dict(
        title="LOAD BALANCER (AKO REPLACEMENT)",
        summary=["Install the MetalLB controller in each cluster.",
                 "Each namespace gets its own IP pool of 20 Service IPs.",
                 "AKO is not installed. AKO needs an Avi Controller."],
        flow=["Install MetalLB", "Apply namespace pools", "Check pool count"],
        before=["Step 03 is complete."],
        run=["./install.sh"],
        files=["install.sh", "verify.sh", "values.yaml", "controller-rbac.yaml", "ipaddresspool.tmpl.yaml"],
        goal="Give LoadBalancer Services a fixed IP from the namespace range.",
        done=["verify.sh shows PASS."],
        notes=["The MetalLB speaker is off. Host routes carry the traffic.",
               "Use annotation metallb.io/loadBalancerIPs to fix an IP."],
    ),
    "05-nginx-ingress": dict(
        title="NGINX CONTROLLERS",
        summary=["Install one NGINX controller in each of the 30 namespaces.",
                 "Each controller has the fixed IP nginx_ip in ip-plan.tsv.",
                 "Each controller watches only its own namespace."],
        flow=["Read namespace", "Helm install", "Fix IP", "Test HTTP 404"],
        before=["Step 04 is complete."],
        run=["./install.sh", "One namespace only: ./install.sh demo-first"],
        files=["install.sh", "verify.sh", "values.tmpl.yaml"],
        goal="Run one controller for each namespace with a fixed IP.",
        done=["verify.sh shows PASS. Each IP returns HTTP 404."],
        notes=["The product is F5 NGINX Ingress Controller.",
               "Community ingress-nginx is retired. Do not use it.",
               "Ingress objects use ingressClassName nginx-<namespace>."],
    ),
    "06-gateway-api": dict(
        title="GATEWAY API",
        summary=["Install the standard Gateway API CRDs in each cluster.",
                 "No Gateway controller is installed.",
                 "Gateway names come after the applications."],
        flow=["Get CRD file", "Apply CRDs", "Check CRDs"],
        before=["Step 02 is complete."],
        run=["./install.sh"],
        files=["install.sh", "verify.sh"],
        goal="Make the Gateway API resources ready in all clusters.",
        done=["verify.sh shows PASS."],
        notes=["This project does not use NGINX Gateway Fabric.",
               "A Gateway object has no effect until a controller exists."],
    ),
    "07-prometheus-grafana": dict(
        title="PROMETHEUS AND GRAFANA",
        summary=["Install Prometheus in the 3 prometheus namespaces.",
                 "demo and tst watch other namespaces in their cluster.",
                 "live-prometheus runs in monitoring and watches the live cluster.",
                 "Install Grafana in tst-grafana and live-grafana."],
        flow=["Install Prometheus", "Scrape pods", "Install Grafana", "Connect data source"],
        before=["Step 05 is complete."],
        run=["./install.sh"],
        files=["install.sh", "verify.sh", "prometheus.tmpl.yaml", "grafana.tmpl.yaml",
               "remote-reader.tmpl.yaml", "dashboard-overview.json"],
        goal="Collect metrics in each cluster. Show test and live in Grafana.",
        done=["verify.sh shows PASS. Each Prometheus has targets."],
        notes=["A pod needs annotations prometheus.io/scrape and prometheus.io/port.",
               "Grafana admin passwords are in $PLATFORM_ROOT/runtime/secrets.",
               "The fixed IP is svc1_ip in ip-plan.tsv.",
               "remote_prometheus in plan.json sets the watched cluster.",
               "A remote Prometheus reads pods with a token of that cluster.",
               "Each Grafana has the VKS overview dashboard in folder VKS."],
    ),
    "08-haproxy": dict(
        title="HAPROXY",
        summary=["Install HAProxy in 3 namespaces.",
                 "nw-haproxy-1 and nw-haproxy-2 reach nginx in all clusters.",
                 "live-haproxy-1 reaches nginx in the live cluster only."],
        flow=["Read routes.tsv", "Make backends", "Apply HAProxy", "Test HTTP 503"],
        before=["Step 05 is complete."],
        run=["./install.sh"],
        files=["install.sh", "verify.sh", "routes.tsv", "haproxy.tmpl.yaml"],
        goal="Route host names to the nginx controller of a namespace.",
        done=["verify.sh shows PASS. An unknown host gets HTTP 503."],
        notes=["To add an application: add a line to routes.tsv.",
               "Then run python3 ../00-common/plan.py and ./install.sh.",
               "routes.tsv is empty until applications exist."],
    ),
    "09-images": dict(
        title="JAVA BASE IMAGES",
        summary=["Build 7 images from Alpine and JDK 17.",
                 "Push the images to the local registry.",
                 "Analyzer namespaces get higher default limits."],
        flow=["Read images.tsv", "Build image", "Push image", "Apply LimitRange"],
        before=["Step 03 is complete."],
        run=["./install.sh"],
        files=["install.sh", "verify.sh", "Dockerfile", "images.tsv", "limitrange.tmpl.yaml"],
        goal="Make one base image for each application family.",
        done=["verify.sh shows PASS."],
        notes=["An image cannot hold CPU or memory limits.",
               "LimitRange holds the limits. Java reads them from the container.",
               "Standard: 500m CPU, 512Mi. Analyzer: 2 CPU, 2Gi.",
               "Image nw-mon is for the networking and monitoring clusters.",
               "Image database is for helper tools, not for database servers."],
    ),
    "10-demo-app": dict(
        title="DEMO APPLICATION (POSTPONED)",
        summary=["This step is postponed until the application exists.",
                 "Nothing is installed now.",
                 "The Dockerfile template is ready for app.jar."],
        flow=["Get app.jar", "Build image", "Push image", "Deploy to demo-first"],
        before=["Step 09 is complete.", "app.jar exists."],
        run=["No command now."],
        files=["Dockerfile.tmpl"],
        goal="Deploy the Java application to demo-first with image demo.",
        done=["The pod is Ready in demo-first.", "Ingress with class nginx-demo-first answers."],
        notes=["Do not start this step without the application.",
               "plan.py makes 00-common/generated/demo-app/Dockerfile."],
    ),
    "11-dnscore": dict(
        title="DNS (DNSCORE)",
        summary=["Install CoreDNS in namespace dnscore.",
                 "Each cluster sends $DOMAIN names to dnscore.",
                 "This host sends $DOMAIN names to dnscore."],
        flow=["Make zone", "Install dnscore", "Update clusters", "Update host", "Test names"],
        before=["Step 04 is complete."],
        run=["./install.sh"],
        files=["install.sh", "link.sh", "verify.sh", "records.tsv", "dnscore.tmpl.yaml"],
        goal="Give one DNS service for $DOMAIN to all clusters.",
        done=["verify.sh shows PASS in all clusters and on the host."],
        notes=["To add a name: add a line to records.tsv.",
               "Then run python3 ../00-common/plan.py and ./install.sh.",
               "Example line: xxx-test 192.168.84.10",
               "Host DNS settings do not stay after a reboot. Run 02-clusters/routes.sh."],
    ),
    "12-databases": dict(
        title="DATABASES",
        summary=["Install PostgreSQL and MongoDB in 3 database namespaces.",
                 "Install InfluxDB in monitoring-database.",
                 "Application databases come with the Java deployments."],
        flow=["Make secrets", "Install servers", "Wait for ready", "Test ports"],
        before=["Step 04 is complete."],
        run=["./install.sh"],
        files=["install.sh", "verify.sh", "postgres.tmpl.yaml", "mongodb.tmpl.yaml",
               "influxdb.tmpl.yaml"],
        goal="Run the database servers with fixed IPs.",
        done=["verify.sh shows PASS."],
        notes=["PostgreSQL uses svc1_ip. MongoDB uses svc2_ip. InfluxDB uses svc1_ip.",
               "Passwords are in $PLATFORM_ROOT/runtime/secrets. Do not copy them.",
               "MongoDB 8.x does not start on Linux 6.19 or newer. Use 9.0.4 or newer."],
    ),
    "13-central-operations": dict(
        title="CENTRAL OPERATIONS",
        summary=["Bitbucket and Bamboo need a license. They are not installed.",
                 "Cluster central-operations has namespace deployer.",
                 "The deployer application comes later."],
        flow=["Cluster exists", "Namespace deployer", "NGINX ready", "Write application later"],
        before=["Steps 02, 03 and 05 are complete."],
        run=["No install command. Other steps create all items."],
        files=["verify.sh"],
        goal="Keep cluster and namespace ready for the deployer application.",
        done=["verify.sh shows PASS."],
        notes=["GitHub connection comes with the deployer application.",
               "See ip-plan.tsv for the deployer range."],
    ),
    "14-final-review": dict(
        title="FINAL REVIEW",
        summary=["Check all scripts offline.",
                 "REVIEW.md holds the results of the live run.",
                 "Do the host tests by hand."],
        flow=["Run validate.sh", "Fix errors", "Run validate.sh again", "Test by hand"],
        before=["All scripts exist."],
        run=["../00-common/validate.sh"],
        files=["REVIEW.md"],
        goal="Find and fix errors before a live run.",
        done=["validate.sh shows RESULT: PASS.", "REVIEW.md lists all items that were not tested."],
        notes=["validate.sh skips a check if its tool is missing.", "Use the order in ../README.txt."],
    ),
    "16-control": dict(
        title="CONTROL MENU",
        summary=["One menu installs, checks, stops, starts and removes platform parts.",
                 "Only the parts that you use run, so the host uses less memory.",
                 "The menu has English, Turkish, German and Spanish texts."],
        flow=["Choose language", "Install components", "See status", "Stop or start",
              "Watch memory"],
        before=["Step 01 is complete. The menu can do the other steps."],
        run=["./vks.sh", "Without the menu: ./component.sh status",
             "Without the menu: ./control.sh stop cluster demo",
             "Without the menu: ./resources.sh host",
             "Check a language file: ./lang-check.sh"],
        files=["vks.sh", "setup.sh", "status.sh", "component.sh", "control.sh",
               "resources.sh", "lib-state.sh", "menu-lib.sh", "inventory.py", "catalog.py",
               "related.py", "plan-edit.py", "apps.tsv", "lang-check.sh", "lang/en.txt",
               "lang/tr.txt", "lang/de.txt", "lang/es.txt"],
        goal="Run only the parts of the platform that you need.",
        done=["./component.sh status shows the state of each component."],
        notes=["The default set is the key defaults in plan.json.",
               "plan.py makes generated/components.tsv from plan.json and apps.tsv.",
               "A stopped cluster uses no memory, because its node container stops.",
               "A stopped namespace or app runs no pods. The annotation "
               "$PLATFORM_NAME.local/replicas keeps the old replica count.",
               "Start of a cluster also starts all its namespaces and apps.",
               "Ingress, HTTPRoute and Gateway objects use no memory, so they stay. "
               "Their controller pod stops.",
               "New language: copy lang/en.txt to lang/<code>.txt and translate the "
               "text after =. A missing key shows the English text.",
               "Swap off and page cache need sudo. Use a normal terminal for them.",
               "The logs of menu actions are in $PLATFORM_ROOT/runtime/logs."],
    ),
}


def wrap(text, first="", rest=""):
    return textwrap.wrap(text, WIDTH, initial_indent=first, subsequent_indent=rest)


def mermaid(flow):
    lines = ["flowchart TD"]
    ids = [chr(65 + i) for i in range(len(flow))]
    for i, label in enumerate(flow):
        lines.append(f"    {ids[i]}[{label}]")
    for a, b in zip(ids, ids[1:]):
        lines.append(f"    {a} --> {b}")
    return lines


def section(name):
    return ["", f"{name}", "-" * len(name)]


def numbered(items):
    out = []
    for i, item in enumerate(items, 1):
        out += wrap(item, f"  {i}. ", "     ")
    return out


def readme(folder, step):
    number = folder.split("-")[0]
    lines = ["=" * WIDTH, f"STEP {number}: {step['title']}", "=" * WIDTH]
    lines += section("1. SUMMARY") + numbered(step["summary"])
    lines += section("2. DIAGRAM (MERMAID)")
    lines += ["  " + x for x in mermaid(step["flow"])]
    lines += section("3. BEFORE YOU START") + numbered(step["before"])
    lines += section("4. PROCEDURE") + numbered(step["run"])
    lines += section("5. TEST") + numbered(step["done"])
    lines += section("6. NOTES") + numbered(step["notes"])
    lines += section("7. FILES") + numbered(step["files"])
    lines += ["", "=" * WIDTH, FOOTER]
    return "\n".join(lines) + "\n"


def roadmap(folder, step):
    number = folder.split("-")[0]
    parts = [f"# Roadmap: step {number} - {step['title'].title()}", "",
             f"**Goal:** {step['goal']}", "", "## Input"]
    parts += [f"- {x}" for x in step["before"]]
    parts += ["- `00-common/plan.json`, `00-common/versions.env`", "", "## Tasks"]
    parts += [f"{i}. {x}." for i, x in enumerate(step["flow"], 1)]
    parts += ["", "## Commands"] + [f"- `{x}`" if x.startswith(("./", "..")) else f"- {x}" for x in step["run"]]
    parts += ["", "## Done when"] + [f"- {x}" for x in step["done"]]
    parts += ["", "## Facts"] + [f"- {x}" for x in step["notes"]]
    parts += ["", "## Rules"] + [f"- {x}" for x in COMMON_RULES]
    return "\n".join(parts) + "\n"


def index():
    lines = ["=" * WIDTH, "LOCAL KUBERNETES PLATFORM: INSTALLATION INDEX", "=" * WIDTH]
    lines += section("1. SUMMARY") + numbered([
        "This folder holds all steps, scripts and roadmaps.",
        "The platform uses kind and Calico. It replaces VMware VKS on one host.",
        "Run one step. Run its verify.sh. Then go to the next step."])
    lines += section("2. DIAGRAM (MERMAID)")
    lines += ["  " + x for x in mermaid(["Platform", "Clusters", "Namespaces",
              "Load balancer", "NGINX", "Other services", "Manual test"])]
    lines += section("3. BEFORE YOU START") + numbered([
        "Use sudo only for root-setup.sh, routes.sh and swap-on.sh, in a normal terminal.",
        "Close other programs. The full stack needs about 12 GiB of memory."])
    lines += section("4. PROCEDURE") + numbered([
        "Edit settings.env.",
        "python3 00-common/plan.py",
        "Do steps in number order: 01 to 09, then 11 and 12.",
        "Step 10 is postponed. Step 13 has only verify.sh."])
    lines += section("5. TEST") + numbered([
        "Run verify.sh in each step folder.",
        "Step 14 lists items that are not tested."])
    lines += section("6. NOTES") + numbered([
        "After a reboot run swap-on.sh, resume-all.sh and routes.sh in this order.",
        "Secrets are in $PLATFORM_ROOT/runtime/secrets.",
        "Runtime data is in $PLATFORM_ROOT/runtime."])
    lines += section("7. FILES") + numbered(["settings.env", "00-common"] + list(STEPS))
    lines += ["", "=" * WIDTH, FOOTER]
    return "\n".join(lines) + "\n"


def main():
    for folder, step in STEPS.items():
        (ROOT / folder / "README.txt").write_text(readme(folder, step))
        (ROOT / folder / "ROADMAP.md").write_text(roadmap(folder, step))
    (ROOT / "README.txt").write_text(index())
    (ROOT / "00-common/README.txt").write_text(readme("00-common", dict(
        title="COMMON FILES",
        summary=["settings.env and plan.json are the source of all site data.",
                 "plan.py makes generated/ from plan.json and the templates.",
                 "gen-docs.py makes all README.txt and ROADMAP.md files."],
        flow=["Edit settings.env or plan.json", "Run plan.py", "Run validate.sh"],
        before=["Python 3 exists on the host."],
        run=["python3 plan.py", "python3 gen-docs.py", "./validate.sh"],
        done=["validate.sh shows RESULT: PASS."],
        notes=["validate.sh does not touch Docker or a cluster.",
               "generated/ is not in Git. Run plan.py after a clone.",
               "Use @NAME@ in plan.json for PLATFORM_NAME."],
        files=["../settings.env", "plan.json", "versions.env", "lib.sh", "plan.py", "gen-docs.py", "validate.sh"])))
    for path in ROOT.rglob("README.txt"):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            assert len(line) <= WIDTH and line.isascii(), (path, number)
    print("OK")


if __name__ == "__main__":
    main()
