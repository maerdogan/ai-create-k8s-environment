==============================================================================
STEP 03: NAMESPACES AND IP RANGES
==============================================================================

1. SUMMARY
----------
  1. Create 30 namespaces.
  2. Give each namespace 50 IPs: 20 for Services, 30 for pods.
  3. Calico pools hold pods in the range of the namespace.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Read ip-plan.tsv]
      B[Create Calico pools]
      C[Create namespaces]
      D[Test pod IP]
      A --> B
      B --> C
      C --> D

3. BEFORE YOU START
-------------------
  1. Step 02 is complete.

4. PROCEDURE
------------
  1. ./install.sh

5. TEST
-------
  1. verify.sh shows PASS. Each test pod has an IP in pod_start to pod_end.

6. NOTES
--------
  1. Namespace number N uses block start + 50 x (N-1) + 1 to + 50.
  2. central-operations has only namespace deployer.
  3. A pod stays Pending if the 30 pod IPs are in use. This is correct.

7. FILES
--------
  1. install.sh
  2. verify.sh
  3. namespace.tmpl.yaml
  4. ippool.tmpl.yaml
  5. ../00-common/generated/ip-plan.tsv

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
