# Roadmap: step 01 - Local Platform

**Goal:** Make the container platform for all clusters.

## Input
- The host has internet access.
- The user has sudo access.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Check host.
2. Install binaries.
3. Start Docker.
4. Create network.
5. Start registry.

## Commands
- `./install.sh`
- In a normal terminal: sudo ./root-setup.sh
- `./install.sh`
- Optional, if memory is low: ./swap-on.sh 16

## Done when
- verify.sh shows PASS.
- Docker data is in $PLATFORM_ROOT/runtime/docker-data.

## Facts
- VMware VKS needs vCenter, ESXi and Supervisor. One host cannot run them.
- sudo writes two files: /etc/systemd/system/$PLATFORM_NAME-docker.service and /etc/sysctl.d/90-$PLATFORM_NAME.conf.
- This Docker service uses its own socket. Load it with lib.sh.
- sudo does not work in app terminals. Use a normal terminal.
- K8S_VERSION in versions.env sets the Kubernetes version.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
