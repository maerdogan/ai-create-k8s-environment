==============================================================================
STEP 02: CLUSTERS
==============================================================================

1. SUMMARY
----------
  1. Create 8 kind clusters with one node each.
  2. Install Calico in each cluster.
  3. Add one host route for each /22 block.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Create cluster]
      B[Add registry link]
      C[Install Calico]
      D[Wait for node]
      E[Add host routes]
      A --> B
      B --> C
      C --> D
      D --> E

3. BEFORE YOU START
-------------------
  1. Step 01 is complete.

4. PROCEDURE
------------
  1. ./install.sh
  2. One cluster only: ./install.sh demo
  3. In a normal terminal: sudo -v && ./routes.sh
  4. After a reboot: run routes.sh again.
  5. For kubectl: source env.sh
  6. Change cluster: kubectl config use-context test

5. TEST
-------
  1. verify.sh shows PASS.
  2. All 8 nodes are Ready.

6. NOTES
--------
  1. network.infra in plan.json is the node network. It is part of
     network.vlan.
  2. Host routes send each /22 block to its node.
  3. The last /24 of each block is for system pods.
  4. Do not change podSubnet after the cluster exists.
  5. tune-memory.sh sets GOGC=40 on control planes. Without it the host
     thrashes.
  6. Run routes.sh after all clusters exist.

7. FILES
--------
  1. install.sh
  2. verify.sh
  3. routes.sh
  4. node-routes.sh
  5. tune-memory.sh
  6. resume-all.sh
  7. patch-calico.sh
  8. kind.tmpl.yaml
  9. merge-kubeconfig.sh
  10. env.sh

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
