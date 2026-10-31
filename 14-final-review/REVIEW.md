# Final review

## Live run on 2026-10-31
| Step | Result | Note |
|---|---|---|
| 01 Platform | PASS | root-setup.sh ran with sudo |
| 02 Clusters | PASS | 8 clusters, Kubernetes 1.35.8 |
| 03 Namespaces | PASS | 30 of 30 test pods had an IP in range |
| 04 MetalLB | PASS | Fix: controller-rbac.yaml |
| 05 NGINX | PASS | 30 of 30 fixed IPs return 404 |
| 06 Gateway API | PASS | CRDs only, no controller |
| 07 Prometheus, Grafana | PASS | |
| 08 HAProxy | PASS | routes.tsv is empty |
| 09 Images | PASS | 7 images, pull from a cluster works |
| 10 Demo application | NOT DONE | Waits for the application |
| 11 dnscore | PASS | Failed once under memory pressure, before swap |
| 12 Databases | PASS | Fix: MongoDB 9.0.4 |
| 13 Central operations | PASS | deployer only |

## Current state
- All 8 clusters run together with 16 GiB swap in $PLATFORM_ROOT/runtime/swapfile.
- Swap does not stay after a reboot. Run swap-on.sh again.
- Without swap, 8 clusters are not stable on this host.

## After a reboot
1. In a normal terminal: `sudo 01-platform/swap-on.sh 16`
2. `02-clusters/resume-all.sh`
3. In a normal terminal: `sudo -v && 02-clusters/routes.sh`

## Errors found in the live run and fixed
- sudo does not work in app terminals. root-setup.sh is now separate.
- MetalLB controller had no permission to read pods with the speaker off.
- Control planes used too much memory. tune-memory.sh sets GOGC=40.
- MongoDB 8.0 and 8.3 do not start on kernel 6.19 or newer. Version is 9.0.4.
- A StatefulSet stays on a broken pod. Delete the pod after a version change.
- Tests needed host routes. They now run in a node.

## Host test
- 8 host routes exist. 30 of 30 nginx IPs return 404 from the host.
- The host resolves $DOMAIN names through dnscore.

## Not tested
- Reboot recovery.
- A value of settings.env other than the default, on a live platform.
