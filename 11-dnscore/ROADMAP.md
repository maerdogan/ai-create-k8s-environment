# Roadmap: step 11 - Dns (Dnscore)

**Goal:** Give one DNS service for $DOMAIN to all clusters.

## Input
- Step 04 is complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Make zone.
2. Install dnscore.
3. Update clusters.
4. Update host.
5. Test names.

## Commands
- `./install.sh`

## Done when
- verify.sh shows PASS in all clusters and on the host.

## Facts
- To add a name: add a line to records.tsv.
- Then run python3 ../00-common/plan.py and ./install.sh.
- Example line: xxx-test 192.168.84.10
- Host DNS settings do not stay after a reboot. Run 02-clusters/routes.sh.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
