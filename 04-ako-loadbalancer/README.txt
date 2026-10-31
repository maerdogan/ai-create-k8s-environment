==============================================================================
STEP 04: LOAD BALANCER (AKO REPLACEMENT)
==============================================================================

1. SUMMARY
----------
  1. Install the MetalLB controller in each cluster.
  2. Each namespace gets its own IP pool of 20 Service IPs.
  3. AKO is not installed. AKO needs an Avi Controller.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Install MetalLB]
      B[Apply namespace pools]
      C[Check pool count]
      A --> B
      B --> C

3. BEFORE YOU START
-------------------
  1. Step 03 is complete.

4. PROCEDURE
------------
  1. ./install.sh

5. TEST
-------
  1. verify.sh shows PASS.

6. NOTES
--------
  1. The MetalLB speaker is off. Host routes carry the traffic.
  2. Use annotation metallb.io/loadBalancerIPs to fix an IP.

7. FILES
--------
  1. install.sh
  2. verify.sh
  3. values.yaml
  4. controller-rbac.yaml
  5. ipaddresspool.tmpl.yaml

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
