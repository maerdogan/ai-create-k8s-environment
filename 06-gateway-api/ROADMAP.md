# Roadmap: step 06 - Gateway Api

**Goal:** Make the Gateway API resources ready in all clusters.

## Input
- Step 02 is complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Get CRD file.
2. Apply CRDs.
3. Check CRDs.

## Commands
- `./install.sh`

## Done when
- verify.sh shows PASS.

## Facts
- This project does not use NGINX Gateway Fabric.
- A Gateway object has no effect until a controller exists.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
