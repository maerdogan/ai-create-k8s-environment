# Roadmap: step 12 - Databases

**Goal:** Run the database servers with fixed IPs.

## Input
- Step 04 is complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Make secrets.
2. Install servers.
3. Wait for ready.
4. Test ports.

## Commands
- `./install.sh`

## Done when
- verify.sh shows PASS.

## Facts
- PostgreSQL uses svc1_ip. MongoDB uses svc2_ip. InfluxDB uses svc1_ip.
- Passwords are in $PLATFORM_ROOT/runtime/secrets. Do not copy them.
- MongoDB 8.x does not start on Linux 6.19 or newer. Use 9.0.4 or newer.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
