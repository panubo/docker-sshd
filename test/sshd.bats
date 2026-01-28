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

@test "entry.sh: Check basic execution" {
    run /entry.sh true
    [ "$status" -eq 0 ]
}

@test "entry.sh: Generates host keys if missing" {
    # Move existing keys aside
    mkdir -p /tmp/keys_backup
    mv /etc/ssh/keys/* /tmp/keys_backup/ 2>/dev/null || true
    mv /etc/ssh/ssh_host_* /tmp/keys_backup/ 2>/dev/null || true

    # Ensure keys directory exists so entry.sh doesn't fail if it expects it or create it empty
    mkdir -p /etc/ssh/keys

    run /entry.sh true
    [ "$status" -eq 0 ]
    [ -f /etc/ssh/keys/ssh_host_rsa_key ]
    [ -f /etc/ssh/keys/ssh_host_ecdsa_key ]
    [ -f /etc/ssh/keys/ssh_host_ed25519_key ]
}

@test "entry.sh: SSH_ENABLE_PASSWORD_AUTH=true enables PasswordAuthentication" {
    run env SSH_ENABLE_PASSWORD_AUTH=true /entry.sh true
    [ "$status" -eq 0 ]
    run grep "^PasswordAuthentication yes" /etc/ssh/sshd_config
    [ "$status" -eq 0 ]
}

@test "entry.sh: SSH_ENABLE_PASSWORD_AUTH=false disables PasswordAuthentication" {
    run env SSH_ENABLE_PASSWORD_AUTH=false /entry.sh true
    [ "$status" -eq 0 ]
    run grep "^PasswordAuthentication no" /etc/ssh/sshd_config
    [ "$status" -eq 0 ]
}

@test "entry.sh: SSH_USERS creates a user" {
    run env SSH_USERS="testuser:2000:2000" /entry.sh true
    [ "$status" -eq 0 ]
    run id testuser
    [ "$status" -eq 0 ]
}

@test "entry.sh: SFTP_MODE=true configures internal-sftp" {
    mkdir -p /data
    run env SFTP_MODE=true /entry.sh true
    [ "$status" -eq 0 ]
    run grep "ForceCommand internal-sftp" /etc/ssh/sshd_config
    [ "$status" -eq 0 ]
}

@test "entry.sh: SSH_ENABLE_ROOT=true unlocks root account" {
    run env SSH_ENABLE_ROOT=true /entry.sh true
    [ "$status" -eq 0 ]
    echo "$output" | grep "Unlocking root account"
}

@test "entry.sh: SCP_MODE=true configures rssh for scp" {
    # SSH_USERS is required for SCP_MODE loop in entry.sh to set shell, but config is global
    run env SCP_MODE=true SSH_USERS="scpuser:2001:2001" /entry.sh true
    [ "$status" -eq 0 ]
    run grep "allowscp" /etc/rssh.conf
    [ "$status" -eq 0 ]
}

@test "entry.sh: RSYNC_MODE=true configures rssh for rsync" {
    run env RSYNC_MODE=true SSH_USERS="rsyncuser:2002:2002" /entry.sh true
    [ "$status" -eq 0 ]
    run grep "allowrsync" /etc/rssh.conf
    [ "$status" -eq 0 ]
}

@test "entry.sh: SSH_GROUPS creates group" {
    run env SSH_GROUPS="testgroup:3000" /entry.sh true
    [ "$status" -eq 0 ]
    run getent group testgroup
    [ "$status" -eq 0 ]
}
