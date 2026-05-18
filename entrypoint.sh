#!/bin/bash
if [ -S /var/run/docker.sock ]; then
    SOCK_GID=$(stat -c '%g' /var/run/docker.sock)
    groupadd -f -g "${SOCK_GID}" dockersock 2>/dev/null || true
    usermod -aG dockersock engineer
fi

ENG_UID=$(id -u engineer)
ENG_GID=$(id -g engineer)
export HOME=/home/engineer
exec setpriv --reuid=${ENG_UID} --regid=${ENG_GID} --init-groups /bin/zsh
