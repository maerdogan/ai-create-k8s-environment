# Roadmap: step 16 - Control Menu

**Goal:** Run only the parts of the platform that you need.

## Input
- Step 01 is complete. The menu can do the other steps.
- `00-common/plan.json`, `00-common/versions.env`

## Tasks
1. Choose language.
2. Install components.
3. See status.
4. Stop or start.
5. Watch memory.

## Commands
- `./vks.sh`
- Without the menu: ./component.sh status
- Without the menu: ./control.sh stop cluster demo
- Without the menu: ./resources.sh host
- Check a language file: ./lang-check.sh

## Done when
- ./component.sh status shows the state of each component.

## Facts
- The default set is the key defaults in plan.json.
- plan.py makes generated/components.tsv from plan.json and apps.tsv.
- A stopped cluster uses no memory, because its node container stops.
- A stopped namespace or app runs no pods. The annotation $PLATFORM_NAME.local/replicas keeps the old replica count.
- Start of a cluster also starts all its namespaces and apps.
- Ingress, HTTPRoute and Gateway objects use no memory, so they stay. Their controller pod stops.
- New language: copy lang/en.txt to lang/<code>.txt and translate the text after =. A missing key shows the English text.
- lang/order sets the order of the language list.
- Swap off and page cache need sudo. Use a normal terminal for them.
- The logs of menu actions are in $PLATFORM_ROOT/runtime/logs.

## Rules
- Do not write outside $PLATFORM_ROOT, except for the sudo items in step 01.
- Do not use the latest tag. Change versions in 00-common/versions.env.
- Do not edit 00-common/generated. Edit plan.json or a template.
- After each change run 00-common/validate.sh.
- If a check fails, stop. Do not go to the next step.
