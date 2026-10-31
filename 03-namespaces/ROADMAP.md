# Roadmap: step 03 - Namespaces And Ip Ranges

**Goal:** Create namespaces and hold each one in its 50 IP range.

## Input
- Step 02 is complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Read ip-plan.tsv.
2. Create Calico pools.
3. Create namespaces.
4. Test pod IP.

## Commands
- `./install.sh`

## Done when
- verify.sh shows PASS. Each test pod has an IP in pod_start to pod_end.

## Facts
- Namespace number N uses block start + 50 x (N-1) + 1 to + 50.
- central-operations has only namespace deployer.
- A pod stays Pending if the 30 pod IPs are in use. This is correct.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
