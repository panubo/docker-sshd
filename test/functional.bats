#!/usr/bin/env bats

setup() {
    # Backup sshd_config
    if [ -f /etc/ssh/sshd_config ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    fi
}

teardown() {
    # Restore sshd_config
    if [ -f /etc/ssh/sshd_config.bak ]; then
        mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
    fi
}

@test "functional: Can ssh in as a local user" {
    # 1. Setup user and keys
    local TEST_USER="sshuser"
    local TEST_UID="2005"
    local TEST_GID="2005"

    # Create SSH key for the test user
    mkdir -p /tmp/test_keys
    ssh-keygen -t rsa -b 2048 -f /tmp/test_keys/id_rsa -N "" -C "test_key"

    # Pre-create the user directory structure and authorized_keys so entry.sh picks it up
    # Note: In the container, authorized_keys are typically handled via /etc/authorized_keys/{user}
    # as per entry.sh logic: `check_authorized_key_ownership /etc/authorized_keys/${_NAME}`
    mkdir -p /etc/authorized_keys
    cp /tmp/test_keys/id_rsa.pub /etc/authorized_keys/${TEST_USER}
    chmod 644 /etc/authorized_keys/${TEST_USER}

    # 2. Start SSHD in background
    # We use setsid to run it in a new session so we can kill it later easily if needed,
    # though strictly in bats we might just run it in background.
    # We need to make sure keys are generated first or available.

    # Generate host keys first to avoid race condition during startup
    ssh-keygen -A

    # Run entry.sh to configure user but NOT exec sshd (pass 'true' to just configure)
    # Actually, we need entry.sh to configure users and THEN start sshd.
    # But entry.sh execs sshd at the end if no arguments provided, or executes arguments.
    # To run sshd in background, we can't easily use entry.sh's exec.
    # Instead, we'll use entry.sh to configure everything (passing 'true'),
    # and then manually start sshd.

    env SSH_USERS="${TEST_USER}:${TEST_UID}:${TEST_GID}" /entry.sh true

    # Start sshd manually
    /usr/sbin/sshd -e -f /etc/ssh/sshd_config

    # 3. Wait for SSHD to be ready
    local RETRY=0
    local MAX_RETRY=10
    while ! nc -z 127.0.0.1 22; do
        sleep 1
        RETRY=$((RETRY+1))
        if [ $RETRY -ge $MAX_RETRY ]; then
            echo "SSHD failed to start"
            return 1
        fi
    done

    # 4. Attempt SSH connection
    # -o StrictHostKeyChecking=no: Don't ask for host verification
    # -o UserKnownHostsFile=/dev/null: Don't save host key
    # -i ...: Identity file
    # -p 22: Port
    run ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -i /tmp/test_keys/id_rsa \
            -p 22 \
            ${TEST_USER}@127.0.0.1 "echo 'success'"

    if [ "$status" -ne 0 ]; then
        echo "SSH failed with status $status"
        echo "Output: $output"
    fi

    [ "$status" -eq 0 ]
    echo "$output" | grep "success"

    # 5. Cleanup
    pkill sshd
    rm -rf /tmp/test_keys
    rm -f /etc/authorized_keys/${TEST_USER}

    [ "$status" -eq 0 ]
}
