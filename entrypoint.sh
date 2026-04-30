#!/bin/bash
if [ -S /var/run/docker.sock ]; then
    SOCK_GID=$(stat -c '%g' /var/run/docker.sock)
    groupadd -f -g "${SOCK_GID}" dockersock 2>/dev/null || true
    usermod -aG dockersock devel
fi

DEVEL_UID=$(id -u devel)
DEVEL_GID=$(id -g devel)
export HOME=/home/devel
exec setpriv --reuid=${DEVEL_UID} --regid=${DEVEL_GID} --init-groups /bin/zsh
