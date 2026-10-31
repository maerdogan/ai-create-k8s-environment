# Roadmap: step 09 - Java Base Images

**Goal:** Make one base image for each application family.

## Input
- Step 03 is complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Read images.tsv.
2. Build image.
3. Push image.
4. Apply LimitRange.

## Commands
- `./install.sh`

## Done when
- verify.sh shows PASS.

## Facts
- An image cannot hold CPU or memory limits.
- LimitRange holds the limits. Java reads them from the container.
- Standard: 500m CPU, 512Mi. Analyzer: 2 CPU, 2Gi.
- Image nw-mon is for the networking and monitoring clusters.
- Image database is for helper tools, not for database servers.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
