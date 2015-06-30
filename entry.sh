#!/usr/bin/env sh

# Generate Host keys
ssh-keygen -A

# Fix permissions
mkdir -p ~/.ssh && chown -R root:root ~/.ssh && chmod 700 ~/.ssh/ && chmod 600 ~/.ssh/*

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

trap stop SIGINT SIGTERM

echo "Running $@"
$@ &
pid="$!"
mkdir -p /var/run/$DAEMON && echo "${pid}" > /var/run/$DAEMON/$DAEMON.pid
wait "${pid}" && exit $?
