==============================================================================
STEP 10: DEMO APPLICATION (POSTPONED)
==============================================================================

1. SUMMARY
----------
  1. This step is postponed until the application exists.
  2. Nothing is installed now.
  3. The Dockerfile template is ready for app.jar.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Get app.jar]
      B[Build image]
      C[Push image]
      D[Deploy to demo-first]
      A --> B
      B --> C
      C --> D

3. BEFORE YOU START
-------------------
  1. Step 09 is complete.
  2. app.jar exists.

4. PROCEDURE
------------
  1. No command now.

5. TEST
-------
  1. The pod is Ready in demo-first.
  2. Ingress with class nginx-demo-first answers.

6. NOTES
--------
  1. Do not start this step without the application.
  2. plan.py makes 00-common/generated/demo-app/Dockerfile.

7. FILES
--------
  1. Dockerfile.tmpl

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
