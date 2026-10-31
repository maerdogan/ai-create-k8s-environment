==============================================================================
STEP 06: GATEWAY API
==============================================================================

1. SUMMARY
----------
  1. Install the standard Gateway API CRDs in each cluster.
  2. No Gateway controller is installed.
  3. Gateway names come after the applications.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Get CRD file]
      B[Apply CRDs]
      C[Check CRDs]
      A --> B
      B --> C

3. BEFORE YOU START
-------------------
  1. Step 02 is complete.

4. PROCEDURE
------------
  1. ./install.sh

5. TEST
-------
  1. verify.sh shows PASS.

6. NOTES
--------
  1. This project does not use NGINX Gateway Fabric.
  2. A Gateway object has no effect until a controller exists.

7. FILES
--------
  1. install.sh
  2. verify.sh

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
