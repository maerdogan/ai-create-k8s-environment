==============================================================================
STEP 11: DNS (DNSCORE)
==============================================================================

1. SUMMARY
----------
  1. Install CoreDNS in namespace dnscore.
  2. Each cluster sends $DOMAIN names to dnscore.
  3. This host sends $DOMAIN names to dnscore.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Make zone]
      B[Install dnscore]
      C[Update clusters]
      D[Update host]
      E[Test names]
      A --> B
      B --> C
      C --> D
      D --> E

3. BEFORE YOU START
-------------------
  1. Step 04 is complete.

4. PROCEDURE
------------
  1. ./install.sh

5. TEST
-------
  1. verify.sh shows PASS in all clusters and on the host.

6. NOTES
--------
  1. To add a name: add a line to records.tsv.
  2. Then run python3 ../00-common/plan.py and ./install.sh.
  3. Example line: xxx-test 192.168.84.10
  4. Host DNS settings do not stay after a reboot. Run 02-clusters/routes.sh.

7. FILES
--------
  1. install.sh
  2. verify.sh
  3. records.tsv
  4. dnscore.tmpl.yaml

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
