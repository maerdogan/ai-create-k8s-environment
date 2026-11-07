# Roadmap: step 07 - Prometheus And Grafana

**Goal:** Collect metrics in each cluster. Show test and live in Grafana.

## Input
- Step 05 is complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Install Prometheus.
2. Scrape pods.
3. Install Grafana.
4. Connect data source.

## Commands
- `./install.sh`

## Done when
- verify.sh shows PASS. Each Prometheus has targets.

## Facts
- A pod needs annotations prometheus.io/scrape and prometheus.io/port.
- Grafana admin passwords are in $PLATFORM_ROOT/runtime/secrets.
- The fixed IP is svc1_ip in ip-plan.tsv.
- remote_prometheus in plan.json sets the watched cluster.
- A remote Prometheus reads pods with a token of that cluster.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
