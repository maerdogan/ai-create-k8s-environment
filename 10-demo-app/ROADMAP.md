# Roadmap: step 10 - Demo Application (Postponed)

**Goal:** Deploy the Java application to demo-first with image demo.

## Input
- Step 09 is complete.
- app.jar exists.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Get app.jar.
2. Build image.
3. Push image.
4. Deploy to demo-first.

## Commands
- No command now.

## Done when
- The pod is Ready in demo-first.
- Ingress with class nginx-demo-first answers.

## Facts
- Do not start this step without the application.
- plan.py makes 00-common/generated/demo-app/Dockerfile.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
