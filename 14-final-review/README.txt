==============================================================================
STEP 14: FINAL REVIEW
==============================================================================

1. SUMMARY
----------
  1. Check all scripts offline.
  2. REVIEW.md holds the results of the live run.
  3. Do the host tests by hand.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Run validate.sh]
      B[Fix errors]
      C[Run validate.sh again]
      D[Test by hand]
      A --> B
      B --> C
      C --> D

3. BEFORE YOU START
-------------------
  1. All scripts exist.

4. PROCEDURE
------------
  1. ../00-common/validate.sh

5. TEST
-------
  1. validate.sh shows RESULT: PASS.
  2. REVIEW.md lists all items that were not tested.

6. NOTES
--------
  1. validate.sh skips a check if its tool is missing.
  2. Use the order in ../README.txt.

7. FILES
--------
  1. REVIEW.md

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
