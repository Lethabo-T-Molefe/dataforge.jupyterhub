#!/bin/sh
# A mounted disk arrives owned by root, but notebooks are written by the unprivileged jupyter user.
# Started as root, this hands the workspace to that user and then drops to it; started as any other
# user, it just runs the command.
set -e

if [ "$(id -u)" = "0" ]; then
    mkdir -p "$JUPYTER_WORKSPACE"
    chown jupyter:jupyter "$JUPYTER_WORKSPACE"
    export HOME=/home/jupyter
    exec setpriv --reuid=jupyter --regid=jupyter --init-groups "$@"
fi

exec "$@"
