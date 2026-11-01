==============================================================================
STEP 15: PCAP ANALYZER APPLICATION
==============================================================================

1. SUMMARY
----------
  1. Build the application image from the main branch on GitHub.
  2. Deploy it to namespace pcap-analyzer.
  3. NGINX serves it with HTTPS at pcap-analyzer.$DOMAIN.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Get source]
      B[Build image]
      C[Push image]
      D[Make secrets]
      E[Deploy]
      F[Test login]
      A --> B
      B --> C
      C --> D
      D --> E
      E --> F

3. BEFORE YOU START
-------------------
  1. Steps 05 and 11 are complete.

4. PROCEDURE
------------
  1. ./install.sh
  2. Image only: ./install.sh --build-only

5. TEST
-------
  1. verify.sh shows PASS.

6. NOTES
--------
  1. The image comes from the Containerfile of the application.
  2. The application uses Python, so it does not use the JDK images.
  3. The HTTPS certificate is self-signed. A browser shows a warning.
  4. Login needs HTTPS, because the session cookie is Secure.
  5. The user name is admin. The password file is pcap-analyzer-admin.env in
     $PLATFORM_ROOT/runtime/secrets.
  6. install.sh keeps an existing admin Secret.
  7. Run 11-dnscore/install.sh to publish the name.
  8. Keep one replica. Sessions and jobs are in memory.

7. FILES
--------
  1. install.sh
  2. verify.sh
  3. app.tmpl.yaml

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
