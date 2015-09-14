#!/usr/bin/env bash

set -e

[ "$DEBUG" == 'true' ] && set -x

# Generate Host keys
ssh-keygen -A

# Fix permissions, if writable
if [ -w ~/.ssh ]; then
    chown -R root:root ~/.ssh && chmod 700 ~/.ssh/ && chmod 600 ~/.ssh/*
fi

DAEMON=sshd

stop() {
    echo "Received SIGINT or SIGTERM. Shutting down $DAEMON"
    # Get PID
    pid=$(cat /var/run/$DAEMON/$DAEMON.pid)
    # Set TERM
    kill -SIGTERM "${pid}"
    # Wait for exit
    wait "${pid}"
    # All done.
    echo "Done."
}

echo "Running $@"
if [ "$1" == "/usr/sbin/sshd" ]; then
    trap stop SIGINT SIGTERM
    $@ &
    pid="$!"
    mkdir -p /var/run/$DAEMON && echo "${pid}" > /var/run/$DAEMON/$DAEMON.pid
    wait "${pid}" && exit $?
else
    exec "$@"
fi
