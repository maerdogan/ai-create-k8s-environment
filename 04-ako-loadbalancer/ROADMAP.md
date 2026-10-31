# Roadmap: step 04 - Load Balancer (Ako Replacement)

**Goal:** Give LoadBalancer Services a fixed IP from the namespace range.

## Input
- Step 03 is complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Install MetalLB.
2. Apply namespace pools.
3. Check pool count.

## Commands
- `./install.sh`

## Done when
- verify.sh shows PASS.

## Facts
- The MetalLB speaker is off. Host routes carry the traffic.
- Use annotation metallb.io/loadBalancerIPs to fix an IP.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
