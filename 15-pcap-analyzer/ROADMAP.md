# Roadmap: step 15 - Pcap Analyzer Application

**Goal:** Run the Python application with a fixed address and HTTPS.

## Input
- Steps 05 and 11 are complete.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Get source.
2. Build image.
3. Push image.
4. Make secrets.
5. Deploy.
6. Test login.

## Commands
- `./install.sh`
- Image only: ./install.sh --build-only

## Done when
- verify.sh shows PASS.

## Facts
- The image comes from the Containerfile of the application.
- The application uses Python, so it does not use the JDK images.
- The HTTPS certificate is self-signed. A browser shows a warning.
- Login needs HTTPS, because the session cookie is Secure.
- The user name is admin. The password file is pcap-analyzer-admin.env in $PLATFORM_ROOT/runtime/secrets.
- install.sh keeps an existing admin Secret.
- Run 11-dnscore/install.sh to publish the name.
- Keep one replica. Sessions and jobs are in memory.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
