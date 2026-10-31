==============================================================================
STEP 12: DATABASES
==============================================================================

1. SUMMARY
----------
  1. Install PostgreSQL and MongoDB in 3 database namespaces.
  2. Install InfluxDB in monitoring-database.
  3. Application databases come with the Java deployments.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Make secrets]
      B[Install servers]
      C[Wait for ready]
      D[Test ports]
      A --> B
      B --> C
      C --> D

3. BEFORE YOU START
-------------------
  1. Step 04 is complete.

4. PROCEDURE
------------
  1. ./install.sh

5. TEST
-------
  1. verify.sh shows PASS.

6. NOTES
--------
  1. PostgreSQL uses svc1_ip. MongoDB uses svc2_ip. InfluxDB uses svc1_ip.
  2. Passwords are in $PLATFORM_ROOT/runtime/secrets. Do not copy them.
  3. MongoDB 8.x does not start on Linux 6.19 or newer. Use 9.0.4 or newer.

7. FILES
--------
  1. install.sh
  2. verify.sh
  3. postgres.tmpl.yaml
  4. mongodb.tmpl.yaml
  5. influxdb.tmpl.yaml

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
