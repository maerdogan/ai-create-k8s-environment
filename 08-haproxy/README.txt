==============================================================================
STEP 08: HAPROXY
==============================================================================

1. SUMMARY
----------
  1. Install HAProxy in 3 namespaces.
  2. nw-haproxy-1 and nw-haproxy-2 reach nginx in all clusters.
  3. live-haproxy-1 reaches nginx in the live cluster only.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Read routes.tsv]
      B[Make backends]
      C[Apply HAProxy]
      D[Test HTTP 503]
      A --> B
      B --> C
      C --> D

3. BEFORE YOU START
-------------------
  1. Step 05 is complete.

4. PROCEDURE
------------
  1. ./install.sh

5. TEST
-------
  1. verify.sh shows PASS. An unknown host gets HTTP 503.

6. NOTES
--------
  1. To add an application: add a line to routes.tsv.
  2. Then run python3 ../00-common/plan.py and ./install.sh.
  3. routes.tsv is empty until applications exist.

7. FILES
--------
  1. install.sh
  2. verify.sh
  3. routes.tsv
  4. haproxy.tmpl.yaml

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
