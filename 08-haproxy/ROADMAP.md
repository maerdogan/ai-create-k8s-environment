# Roadmap: step 08 - Haproxy

**Goal:** Route host names to the nginx controller of a namespace.

## Input
- Step 05 is complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Read routes.tsv.
2. Make backends.
3. Apply HAProxy.
4. Test HTTP 503.

## Commands
- `./install.sh`

## Done when
- verify.sh shows PASS. An unknown host gets HTTP 503.

## Facts
- To add an application: add a line to routes.tsv.
- Then run python3 ../00-common/plan.py and ./install.sh.
- routes.tsv is empty until applications exist.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
