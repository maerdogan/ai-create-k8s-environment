==============================================================================
STEP 13: CENTRAL OPERATIONS
==============================================================================

1. SUMMARY
----------
  1. Bitbucket and Bamboo need a license. They are not installed.
  2. Cluster central-operations has namespace deployer.
  3. The deployer application comes later.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Cluster exists]
      B[Namespace deployer]
      C[NGINX ready]
      D[Write application later]
      A --> B
      B --> C
      C --> D

3. BEFORE YOU START
-------------------
  1. Steps 02, 03 and 05 are complete.

4. PROCEDURE
------------
  1. No install command. Other steps create all items.

5. TEST
-------
  1. verify.sh shows PASS.

6. NOTES
--------
  1. GitHub connection comes with the deployer application.
  2. See ip-plan.tsv for the deployer range.

7. FILES
--------
  1. verify.sh

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
