#!/usr/bin/env bats

setup() {
    # Backup sshd_config and rssh.conf
    if [ -f /etc/ssh/sshd_config ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    fi
    if [ -f /etc/rssh.conf ]; then
        cp /etc/rssh.conf /etc/rssh.conf.bak
    fi

    # Ensure keys directory exists
    mkdir -p /etc/ssh/keys
    ssh-keygen -A
}

teardown() {
    # Stop sshd
    pkill sshd || true

    # Restore config files
    if [ -f /etc/ssh/sshd_config.bak ]; then
        mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
    fi
    if [ -f /etc/rssh.conf.bak ]; then
        mv /etc/rssh.conf.bak /etc/rssh.conf
    fi

    # Cleanup keys
    rm -rf /tmp/test_keys_*
    rm -f /etc/authorized_keys/sftp* /etc/authorized_keys/scp* /etc/authorized_keys/rsync*
}

wait_for_sshd() {
    local RETRY=0
    local MAX_RETRY=30
    while ! nc -z 127.0.0.1 22; do
        sleep 0.5
        RETRY=$((RETRY+1))
        if [ $RETRY -ge $MAX_RETRY ]; then
            echo "SSHD failed to start"
            return 1
        fi
    done
}

prepare_user() {
    local USERNAME="$1"
    local KEYS_DIR="/tmp/test_keys_${USERNAME}"
    mkdir -p "${KEYS_DIR}"
    ssh-keygen -t rsa -b 2048 -f "${KEYS_DIR}/id_rsa" -N "" -C "test_key_${USERNAME}"

    mkdir -p /etc/authorized_keys
    cp "${KEYS_DIR}/id_rsa.pub" "/etc/authorized_keys/${USERNAME}"
    chmod 644 "/etc/authorized_keys/${USERNAME}"
}

@test "restricted: SFTP_MODE=true allows SFTP, blocks SSH shell" {
    local USER="sftpuser"
    local TEST_UID="3001"
    local TEST_GID="3001"
    prepare_user "${USER}"

    # Configure and start
    mkdir -p /data
    env SFTP_MODE=true SSH_USERS="${USER}:${TEST_UID}:${TEST_GID}" /entry.sh true
    /usr/sbin/sshd -e -f /etc/ssh/sshd_config
    wait_for_sshd

    # 1. Test SFTP (Should Succeed)
    # Create a dummy file to upload/list
    touch /tmp/sftp_test_upload

    # Connect via SFTP. We use batch mode to just list root (which is chrooted)
    echo "ls" > /tmp/sftp_batch
    run sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
             -i "/tmp/test_keys_${USER}/id_rsa" \
             -P 22 -b /tmp/sftp_batch \
             ${USER}@127.0.0.1
    if [ "$status" -ne 0 ]; then
        echo "SFTP failed: $output"
    fi
    [ "$status" -eq 0 ]

    # 2. Test SSH Shell (Should Fail)
    run ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -i "/tmp/test_keys_${USER}/id_rsa" \
            -p 22 \
            ${USER}@127.0.0.1 "ls"
    [ "$status" -ne 0 ]

    # 3. Test SCP (Should Fail)
    local SRC_FILE="/tmp/scp_test_src_sftp"
    echo "hello" > "${SRC_FILE}"
    run scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -i "/tmp/test_keys_${USER}/id_rsa" \
            -P 22 \
            "${SRC_FILE}" ${USER}@127.0.0.1:/tmp/scp_test_remote_sftp
    [ "$status" -ne 0 ]
}

@test "restricted: SCP_MODE=true allows SCP, blocks SSH shell and SFTP" {
    local USER="scpuser"
    local TEST_UID="3002"
    local TEST_GID="3002"
    prepare_user "${USER}"

    # Configure and start
    env SCP_MODE=true SSH_USERS="${USER}:${TEST_UID}:${TEST_GID}" /entry.sh true
    /usr/sbin/sshd -e -f /etc/ssh/sshd_config
    wait_for_sshd

    # 1. Test SCP (Should Succeed)
    local SRC_FILE="/tmp/scp_test_src"
    echo "hello" > "${SRC_FILE}"

    # Copy file TO the container
    # -O: Use legacy SCP protocol (rssh doesn't support SFTP protocol)
    run scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -i "/tmp/test_keys_${USER}/id_rsa" \
            -P 22 \
            "${SRC_FILE}" ${USER}@127.0.0.1:/tmp/scp_test_remote

    if [ "$status" -ne 0 ]; then
        echo "SCP failed: $output"
    fi
    [ "$status" -eq 0 ]

    # 2. Test SSH Shell (Should Fail)
    run ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -i "/tmp/test_keys_${USER}/id_rsa" \
            -p 22 \
            ${USER}@127.0.0.1 "ls"

    [ "$status" -ne 0 ]
    # Check for rssh restricted message
    echo "$output" | grep -i "restricted"

    # 3. Test SFTP (Should Fail)
    echo "ls" > /tmp/sftp_batch
    run sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
             -i "/tmp/test_keys_${USER}/id_rsa" \
             -P 22 -b /tmp/sftp_batch \
             ${USER}@127.0.0.1

    [ "$status" -ne 0 ]
}

@test "restricted: RSYNC_MODE=true allows RSYNC, blocks SSH shell" {
    local USER="rsyncuser"
    local TEST_UID="3003"
    local TEST_GID="3003"
    prepare_user "${USER}"

    # Configure and start
    env RSYNC_MODE=true SSH_USERS="${USER}:${TEST_UID}:${TEST_GID}" /entry.sh true
    /usr/sbin/sshd -e -f /etc/ssh/sshd_config
    wait_for_sshd

    # 1. Test RSYNC (Should Succeed)
    local SRC_DIR="/tmp/rsync_src"
    mkdir -p "${SRC_DIR}"
    touch "${SRC_DIR}/file1"

    # rsync -e ssh ...
    run rsync -av -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/test_keys_${USER}/id_rsa -p 22" \
        "${SRC_DIR}/" ${USER}@127.0.0.1:/tmp/rsync_remote/

    if [ "$status" -ne 0 ]; then
        echo "RSYNC failed: $output"
    fi
    [ "$status" -eq 0 ]

    # 2. Test SSH Shell (Should Fail)
    run ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -i "/tmp/test_keys_${USER}/id_rsa" \
            -p 22 \
            ${USER}@127.0.0.1 "ls"

    [ "$status" -ne 0 ]
    echo "$output" | grep -i "restricted"

    # 3. Test SFTP (Should Fail)
    echo "ls" > /tmp/sftp_batch_rsync
    run sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
             -i "/tmp/test_keys_${USER}/id_rsa" \
             -P 22 -b /tmp/sftp_batch_rsync \
             ${USER}@127.0.0.1

    [ "$status" -ne 0 ]
}
