==============================================================================
STEP 09: JAVA BASE IMAGES
==============================================================================

1. SUMMARY
----------
  1. Build 7 images from Alpine and JDK 17.
  2. Push the images to the local registry.
  3. Analyzer namespaces get higher default limits.

2. DIAGRAM (MERMAID)
--------------------
  flowchart TD
      A[Read images.tsv]
      B[Build image]
      C[Push image]
      D[Apply LimitRange]
      A --> B
      B --> C
      C --> D

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
  1. An image cannot hold CPU or memory limits.
  2. LimitRange holds the limits. Java reads them from the container.
  3. Standard: 500m CPU, 512Mi. Analyzer: 2 CPU, 2Gi.
  4. Image nw-mon is for the networking and monitoring clusters.
  5. Image database is for helper tools, not for database servers.

7. FILES
--------
  1. install.sh
  2. verify.sh
  3. Dockerfile
  4. images.tsv
  5. limitrange.tmpl.yaml

==============================================================================
# vim: set ft=text tw=78 nowrap nospell:
