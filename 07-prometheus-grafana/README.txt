==============================================================================
STEP 07: PROMETHEUS AND GRAFANA
==============================================================================

1. SUMMARY
----------
  1. Install Prometheus in the 3 prometheus namespaces.
  2. demo and tst watch other namespaces in their cluster.
  3. live-prometheus runs in monitoring and watches the live cluster.
  4. Install Grafana in tst-grafana and live-grafana.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Install Prometheus]
      B[Scrape pods]
      C[Install Grafana]
      D[Connect data source]
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
  1. verify.sh shows PASS. Each Prometheus has targets.

6. NOTES
--------
  1. A pod needs annotations prometheus.io/scrape and prometheus.io/port.
  2. Grafana admin passwords are in $PLATFORM_ROOT/runtime/secrets.
  3. The fixed IP is svc1_ip in ip-plan.tsv.
  4. remote_prometheus in plan.json sets the watched cluster.
  5. A remote Prometheus reads pods with a token of that cluster.

7. FILES
--------
  1. install.sh
  2. verify.sh
  3. prometheus.tmpl.yaml
  4. grafana.tmpl.yaml
  5. remote-reader.tmpl.yaml

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
