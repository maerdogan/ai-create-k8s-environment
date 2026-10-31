==============================================================================
STEP 00: COMMON FILES
==============================================================================

1. SUMMARY
----------
  1. settings.env and plan.json are the source of all site data.
  2. plan.py makes generated/ from plan.json and the templates.
  3. gen-docs.py makes all README.txt and ROADMAP.md files.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Edit settings.env or plan.json]
      B[Run plan.py]
      C[Run validate.sh]
      A --> B
      B --> C

3. BEFORE YOU START
-------------------
  1. Python 3 exists on the host.

4. PROCEDURE
------------
  1. python3 plan.py
  2. python3 gen-docs.py
  3. ./validate.sh

5. TEST
-------
  1. validate.sh shows RESULT: PASS.

6. NOTES
--------
  1. validate.sh does not touch Docker or a cluster.
  2. generated/ is not in Git. Run plan.py after a clone.
  3. Use @NAME@ in plan.json for PLATFORM_NAME.

7. FILES
--------
  1. ../settings.env
  2. plan.json
  3. versions.env
  4. lib.sh
  5. plan.py
  6. gen-docs.py
  7. validate.sh

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
