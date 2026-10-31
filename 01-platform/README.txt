==============================================================================
STEP 01: LOCAL PLATFORM
==============================================================================

1. SUMMARY
----------
  1. Install Docker, kind, kubectl and helm in $PLATFORM_ROOT/runtime.
  2. Create the Docker network and the local image registry.
  3. This platform replaces VMware VKS on one host.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Check host]
      B[Install binaries]
      C[Start Docker]
      D[Create network]
      E[Start registry]
      A --> B
      B --> C
      C --> D
      D --> E

3. BEFORE YOU START
-------------------
  1. The host has internet access.
  2. The user has sudo access.

4. PROCEDURE
------------
  1. ./install.sh
  2. In a normal terminal: sudo ./root-setup.sh
  3. ./install.sh
  4. Optional, if memory is low: ./swap-on.sh 16

5. TEST
-------
  1. verify.sh shows PASS.
  2. Docker data is in $PLATFORM_ROOT/runtime/docker-data.

6. NOTES
--------
  1. VMware VKS needs vCenter, ESXi and Supervisor. One host cannot run them.
  2. sudo writes two files: /etc/systemd/system/$PLATFORM_NAME-docker.service
     and /etc/sysctl.d/90-$PLATFORM_NAME.conf.
  3. This Docker service uses its own socket. Load it with lib.sh.
  4. sudo does not work in app terminals. Use a normal terminal.
  5. K8S_VERSION in versions.env sets the Kubernetes version.

7. FILES
--------
  1. install.sh
  2. root-setup.sh
  3. verify.sh
  4. swap-on.sh
  5. daemon.tmpl.json
  6. docker.tmpl.service
  7. sysctl.conf

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
