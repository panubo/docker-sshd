#!/usr/bin/env bash

set -e

[ "$DEBUG" == 'true' ] && set -x

DAEMON=sshd

# Copy default config from cache
if [ ! "$(ls -A /etc/ssh)" ]; then
   cp -a /etc/ssh.cache/* /etc/ssh/
fi

# Generate Host keys, if required
if ! ls /etc/ssh/ssh_host_* 1> /dev/null 2>&1; then
    ssh-keygen -A
fi

# Fix permissions, if writable
if [ -w ~/.ssh ]; then
    chown root:root ~/.ssh && chmod 700 ~/.ssh/
fi
if [ -w ~/.ssh/authorized_keys ]; then
    chown root:root ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi
if [ -w /etc/ssh/authorized_keys ]; then
    chown root:root /etc/ssh/authorized_keys
    chmod 755 /etc/ssh/authorized_keys
    find /etc/ssh/authorized_keys/ -type f -exec chmod 644 {} \;
fi

# Add users if SSH_USERS=user/uid/gid set
if [ -v SSH_USERS ]; then
    USERS=$(echo $SSH_USERS | tr "," "\n")
    for USER in $USERS; do
        IFS='/' read -ra UA <<< "$USER"
        NAME=${UA[0]}
        echo ">> Adding user $NAME with uid: ${UA[1]} gid: ${UA[2]}."
        if [ ! -e " /etc/ssh/authorized_keys/$NAME" ]; then
            echo "WARNING: No SSH authorized_keys found for $NAME!"
        fi
        adduser -D -u ${UA[1]} -g ${UA[2]} $NAME
    done
else
    # Warn if no authorized_keys
    if [ ! -e ~/.ssh/authorized_keys ] && [ ! $(ls -A /etc/ssh/authorized_keys) ]; then
      echo "WARNING: No SSH authorized_keys found!"
    fi
fi

# Update MOTD
if [ -v MOTD ]; then
    echo -e "$MOTD" > /etc/motd
fi

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
if [ "$(basename $1)" == "$DAEMON" ]; then
    trap stop SIGINT SIGTERM
    $@ &
    pid="$!"
    mkdir -p /var/run/$DAEMON && echo "${pid}" > /var/run/$DAEMON/$DAEMON.pid
    wait "${pid}" && exit $?
else
    exec "$@"
fi
