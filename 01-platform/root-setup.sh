#!/usr/bin/env bash
# Step 01 root part. Run with sudo in a normal terminal, one time.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
HERE=$INSTALL_DIR/01-platform
SYSCTL=/etc/sysctl.d/90-$PLATFORM_NAME.conf
[[ $(id -u) -eq 0 && -n ${SUDO_USER:-} ]] || die 'Run with sudo.'
[[ -x $RUNTIME/docker-bin/dockerd ]] || die 'Run install.sh first.'

sed -e "s|@RUNTIME@|$RUNTIME|g" -e "s|@GROUP@|$(id -gn "$SUDO_USER")|g" \
    -e "s|@REGISTRY@|$REGISTRY_IP|g" "$HERE/daemon.tmpl.json" > "$RUNTIME/daemon.json"
sed -e "s|@RUNTIME@|$RUNTIME|g" -e "s|@NAME@|$PLATFORM_NAME|g" "$HERE/docker.tmpl.service" \
    > "/etc/systemd/system/$DOCKER_SERVICE"
install -m 644 "$HERE/sysctl.conf" "$SYSCTL"
sysctl --quiet -p "$SYSCTL"
systemctl daemon-reload
systemctl enable --now "$DOCKER_SERVICE"
systemctl is-active "$DOCKER_SERVICE"
