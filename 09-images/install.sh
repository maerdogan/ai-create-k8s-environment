#!/usr/bin/env bash
# Step 09: build and push images. Apply limits to namespaces.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
HERE=$INSTALL_DIR/09-images
# The static Docker package has no buildx plugin.
export DOCKER_BUILDKIT=0
while IFS=$'\t' read -r name _ _ _ _ pct; do
  image=$(image_ref "$name")
  log "Build $image"
  docker build -q -t "$image" "$HERE" \
    --build-arg "ALPINE_VERSION=$ALPINE_VERSION" \
    --build-arg "IMAGE_ROLE=$name" \
    --build-arg "JAVA_RAM_PCT=$pct"
  docker push -q "$image"
done < <(tail -n +2 "$HERE/images.tsv")
for f in "$GEN"/limits/*.yaml; do
  ns=$(basename "$f" .yaml)
  kc "$(cluster_of "$ns")" apply -f "$f"
done
log 'Step 09 is complete. Run verify.sh.'
