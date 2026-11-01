==============================================================================
STEP 05: NGINX CONTROLLERS
==============================================================================

1. SUMMARY
----------
  1. Install one NGINX controller in each of the 30 namespaces.
  2. Each controller has the fixed IP nginx_ip in ip-plan.tsv.
  3. Each controller watches only its own namespace.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Read namespace]
      B[Helm install]
      C[Fix IP]
      D[Test HTTP 404]
      A --> B
      B --> C
      C --> D

3. BEFORE YOU START
-------------------
  1. Step 04 is complete.

4. PROCEDURE
------------
  1. ./install.sh
  2. One namespace only: ./install.sh demo-first

5. TEST
-------
  1. verify.sh shows PASS. Each IP returns HTTP 404.

6. NOTES
--------
  1. The product is F5 NGINX Ingress Controller.
  2. Community ingress-nginx is retired. Do not use it.
  3. Ingress objects use ingressClassName nginx-<namespace>.

7. FILES
--------
  1. install.sh
  2. verify.sh
  3. values.tmpl.yaml

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
