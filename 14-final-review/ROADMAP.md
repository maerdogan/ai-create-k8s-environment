# Roadmap: step 14 - Final Review

**Goal:** Find and fix errors before a live run.

## Input
- All scripts exist.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Run validate.sh.
2. Fix errors.
3. Run validate.sh again.
4. Test by hand.

## Commands
- `../00-common/validate.sh`

## Done when
- validate.sh shows RESULT: PASS.
- REVIEW.md lists all items that were not tested.

## Facts
- validate.sh skips a check if its tool is missing.
- Use the order in ../README.txt.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
