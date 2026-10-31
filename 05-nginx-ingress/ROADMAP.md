# Roadmap: step 05 - Nginx Controllers

**Goal:** Run one controller for each namespace with a fixed IP.

## Input
- Step 04 is complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Read namespace.
2. Helm install.
3. Fix IP.
4. Test HTTP 404.

## Commands
- `./install.sh`
- One namespace only: ./install.sh demo-first

## Done when
- verify.sh shows PASS. Each IP returns HTTP 404.

## Facts
- The product is F5 NGINX Ingress Controller.
- Community ingress-nginx is retired. Do not use it.
- Ingress objects use ingressClassName nginx-<namespace>.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
