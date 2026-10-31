# Roadmap: step 13 - Central Operations

**Goal:** Keep cluster and namespace ready for the deployer application.

## Input
- Steps 02, 03 and 05 are complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Cluster exists.
2. Namespace deployer.
3. NGINX ready.
4. Write application later.

## Commands
- No install command. Other steps create all items.

## Done when
- verify.sh shows PASS.

## Facts
- GitHub connection comes with the deployer application.
- See ip-plan.tsv for the deployer range.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
