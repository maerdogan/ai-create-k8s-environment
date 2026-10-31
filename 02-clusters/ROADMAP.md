# Roadmap: step 02 - Clusters

**Goal:** Create all clusters in plan.json.

## Input
- Step 01 is complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Create cluster.
2. Add registry link.
3. Install Calico.
4. Wait for node.
5. Add host routes.

## Commands
- `./install.sh`
- One cluster only: ./install.sh demo
- In a normal terminal: sudo -v && ./routes.sh
- After a reboot: run routes.sh again.
- For kubectl: source env.sh
- Change cluster: kubectl config use-context test

## Done when
- verify.sh shows PASS.
- All 8 nodes are Ready.

## Facts
- network.infra in plan.json is the node network. It is part of network.vlan.
- Host routes send each /22 block to its node.
- The last /24 of each block is for system pods.
- Do not change podSubnet after the cluster exists.
- tune-memory.sh sets GOGC=40 on control planes. Without it the host thrashes.
- Run routes.sh after all clusters exist.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
