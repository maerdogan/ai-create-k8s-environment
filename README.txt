==============================================================================
LOCAL KUBERNETES PLATFORM: INSTALLATION INDEX
==============================================================================

1. SUMMARY
----------
  1. This folder holds all steps, scripts and roadmaps.
  2. The platform uses kind and Calico. It replaces VMware VKS on one host.
  3. Run one step. Run its verify.sh. Then go to the next step.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Platform]
      B[Clusters]
      C[Namespaces]
      D[Load balancer]
      E[NGINX]
      F[Other services]
      G[Manual test]
      A --> B
      B --> C
      C --> D
      D --> E
      E --> F
      F --> G

3. BEFORE YOU START
-------------------
  1. Use sudo only for root-setup.sh, routes.sh and swap-on.sh, in a normal
     terminal.
  2. Close other programs. The full stack needs about 12 GiB of memory.

4. PROCEDURE
------------
  1. Edit settings.env.
  2. python3 00-common/plan.py
  3. Do steps in number order: 01 to 09, then 11 and 12.
  4. Step 10 is postponed. Step 13 has only verify.sh.

5. TEST
-------
  1. Run verify.sh in each step folder.
  2. Step 14 lists items that are not tested.

6. NOTES
--------
  1. After a reboot run swap-on.sh, resume-all.sh and routes.sh in this order.
  2. Secrets are in $PLATFORM_ROOT/runtime/secrets.
  3. Runtime data is in $PLATFORM_ROOT/runtime.

7. FILES
--------
  1. settings.env
  2. 00-common
  3. 01-platform
  4. 02-clusters
  5. 03-namespaces
  6. 04-ako-loadbalancer
  7. 05-nginx-ingress
  8. 06-gateway-api
  9. 07-prometheus-grafana
  10. 08-haproxy
  11. 09-images
  12. 10-demo-app
  13. 11-dnscore
  14. 12-databases
  15. 13-central-operations
  16. 14-final-review

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
