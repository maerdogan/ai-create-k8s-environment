==============================================================================
STEP 16: CONTROL MENU
==============================================================================

1. SUMMARY
----------
  1. One menu installs, checks, stops, starts and removes platform parts.
  2. Only the parts that you use run, so the host uses less memory.
  3. The menu has English, Turkish, German and Spanish texts.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Choose language]
      B[Install components]
      C[See status]
      D[Stop or start]
      E[Watch memory]
      A --> B
      B --> C
      C --> D
      D --> E

3. BEFORE YOU START
-------------------
  1. Step 01 is complete. The menu can do the other steps.

4. PROCEDURE
------------
  1. ./vks.sh
  2. Without the menu: ./component.sh status
  3. Without the menu: ./control.sh stop cluster demo
  4. Without the menu: ./resources.sh host
  5. Check a language file: ./lang-check.sh

5. TEST
-------
  1. ./component.sh status shows the state of each component.

6. NOTES
--------
  1. The default set is the key defaults in plan.json.
  2. plan.py makes generated/components.tsv from plan.json and apps.tsv.
  3. A stopped cluster uses no memory, because its node container stops.
  4. A stopped namespace or app runs no pods. The annotation
     $PLATFORM_NAME.local/replicas keeps the old replica count.
  5. Start of a cluster also starts all its namespaces and apps.
  6. Ingress, HTTPRoute and Gateway objects use no memory, so they stay. Their
     controller pod stops.
  7. New language: copy lang/en.txt to lang/<code>.txt and translate the text
     after =. A missing key shows the English text.
  8. lang/order sets the order of the language list.
  9. Swap off and page cache need sudo. Use a normal terminal for them.
  10. The logs of menu actions are in $PLATFORM_ROOT/runtime/logs.

7. FILES
--------
  1. vks.sh
  2. setup.sh
  3. status.sh
  4. component.sh
  5. control.sh
  6. resources.sh
  7. lib-state.sh
  8. menu-lib.sh
  9. inventory.py
  10. catalog.py
  11. related.py
  12. plan-edit.py
  13. apps.tsv
  14. lang-check.sh
  15. lang/en.txt
  16. lang/tr.txt
  17. lang/de.txt
  18. lang/es.txt
  19. lang/order

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
