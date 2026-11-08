#!/usr/bin/env bash
# Usage: verify.sh [--images-only]
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
while IFS=$'\t' read -r name _ _ _ _ _; do
  image=$(image_ref "$name")
  out=$(docker run --rm --entrypoint java "$image" -version 2>&1)
  [[ $out == *'version "17'* ]] || die "$image does not have JDK 17."
  log "$image OK"
done < <(tail -n +2 "$INSTALL_DIR/09-images/images.tsv")
[[ ${1:-} != --images-only ]] || { log 'PASS'; exit 0; }
limit=$(kc analyzer -n log-analyzer get limitrange "$PLATFORM_NAME-defaults" \
  -o jsonpath='{.spec.limits[0].default.memory}')
[[ $limit == 2Gi ]] || die "Analyzer limit is $limit, expected 2Gi."
log 'PASS'
