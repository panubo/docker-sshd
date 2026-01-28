# SSHD

[![Build Status](https://github.com/panubo/docker-sshd/actions/workflows/build-push.yml/badge.svg)](https://github.com/panubo/docker-sshd/actions)
[![Release](https://img.shields.io/github/v/release/panubo/docker-sshd)](https://github.com/panubo/docker-sshd/releases/latest)
[![License](https://img.shields.io/github/license/panubo/docker-sshd.svg)](https://github.com/panubo/docker-sshd/blob/master/LICENSE)

Minimal Alpine Linux Docker image with `sshd` exposed and `rsync` installed.

> [!NOTE]
> We no longer publish images to Docker Hub. Please use [Quay.io](quay.io/panubo/sshd) or [AWS ECR Public](public.ecr.aws/panubo/sshd).

The image is available on quay.io `quay.io/panubo/sshd` and AWS ECR Public `public.ecr.aws/panubo/sshd`.

<!-- BEGIN_TOP_PANUBO -->
> [!IMPORTANT]
> **Maintained by Panubo** — Cloud Native & SRE Consultants in Sydney.
> [Work with us →](https://panubo.com.au)
<!-- END_TOP_PANUBO -->

## Table of Contents

- [Environment Options](#environment-options)
  - [General Options](#general-options)
  - [SSH Options](#ssh-options)
  - [Restricted Modes](#restricted-modes)
- [SSH Host Keys](#ssh-host-keys)
- [Authorized Keys](#authorized-keys)
- [SFTP mode](#sftp-mode)
- [SCP or Rsync modes](#scp-or-rsync-modes)
- [Custom Scripts](#custom-scripts)
- [Password Authentication](#password-authentication)
- [Usage Example](#usage-example)
- [Docker Compose](#docker-compose)
- [Testing](#testing)
- [Releases](#releases)
- [Status](#status)

## Environment Options

Configure the container with the following environment variables or optionally mount a custom sshd config at `/etc/ssh/sshd_config`:

### General Options

- `SSH_USERS` list of user accounts and uids/gids to create. eg `SSH_USERS=www:48:48,admin:1000:1000:/bin/bash`. The fourth argument for specifying the user shell is optional. If `SSH_GROUPS` is omitted, a group is created for each user with the same name as the user.
- `SSH_GROUPS` list of groups and gids to create. eg `SSH_GROUPS=guests:1005,other:1006`. Specifying this option disables automatic group creation of user-named groups if you also specify `SSH_USERS`.
- `SSH_ENABLE_ROOT` if "true" unlock the root account. Note: restricted modes do not apply to this account.
- `SSH_ENABLE_PASSWORD_AUTH` if "true" enable password authentication (disabled by default) (excluding the root user)
- `SSH_ENABLE_ROOT_PASSWORD_AUTH` if "true" enable password authentication for all users including root
- `MOTD` change the login message

### SSH Options

- `GATEWAY_PORTS` if "true" sshd will allow gateway ports
- `TCP_FORWARDING` if "true" sshd will allow TCP forwarding
- `DISABLE_SFTP` if "true" sshd will not accept sftp connections. Note: This does not
prevent file access unless you define a restricted shell for each user that prevents executing
programs that grant file access.

### Restricted Modes

The following three restricted modes, SFTP only, SCP only and Rsync only are mutually exclusive. If no mode is defined,
then all connection types will be accepted. Only one mode can be enabled at a time:

#### SFTP Only

- `SFTP_MODE` if "true" sshd will only accept sftp connections
- `SFTP_CHROOT` if in sftp only mode sftp will be chrooted to this directory. Default "/data"

#### SCP Only

- `SCP_MODE` if "true" sshd will only accept scp connections (uses rssh)

#### Rsync Only

- `RSYNC_MODE` if "true" sshd will only accept rsync connections (uses rssh)

## SSH Host Keys

SSH uses host keys to identify the server. To avoid receiving a security warning the host keys should be mounted on an external volume.

By default this image will create new host keys in `/etc/ssh/keys` which should be mounted on an external volume. If you are using existing keys and they are mounted in `/etc/ssh` this image will use the default host key location making this image compatible with existing setups.

If you wish to configure SSH entirely with environment variables it is suggested that you externally mount `/etc/ssh/keys` instead of `/etc/ssh`.

## Authorized Keys

Mount your .ssh credentials (RSA public keys) at `/root/.ssh/` in order to
access the container via root and set `SSH_ENABLE_ROOT=true` or mount each user's key in
`/etc/authorized_keys/<username>` and set `SSH_USERS` environment config to create the user accounts.

Authorized keys must be either owned by root (uid/gid 0), or owned by the uid/gid that corresponds to the
uid/gid and user specified in `SSH_USERS`.

## SFTP mode

When in sftp only mode (activated by setting `SFTP_MODE=true`) the container will only accept sftp connections. All sftp actions will be chrooted to the `SFTP_CHROOT` directory which defaults to "/data".

Please note that all components of the pathname in the ChrootDirectory directive must be root-owned directories that are not writable by any other user or group (see `man 5 sshd_config`).

## SCP or Rsync modes

When in scp or rsync only mode (activated by setting `SCP_MODE=true` or `RSYNC_MODE=true` respectively) the container will only accept scp or rsync connections. No chroot is provided.

This is provided by using [rssh](http://www.pizzashack.org/rssh/) restricted shell.

## Custom Scripts

Executable shell scripts and binaries can be mounted or copied in to `/etc/entrypoint.d`. These will be run when the container is launched but before sshd is started. These can be used to customise the behaviour of the container.

## Password authentication

**Password authentication is not recommended** however using `SSH_ENABLE_PASSWORD_AUTH=true` you can enable password authentication. The image doesn't provide any way to set user passwords via config but you can use the custom scripts support to run a custom script to set user passwords.
Setting `SSH_ENABLE_ROOT_PASSWORD_AUTH=true` also enables password authentication for the root account.

For example you could add the following script to `/etc/entrypoint.d/`

**setpasswd.sh**

```bash
#!/usr/bin/env bash

set -e

echo 'user1:$6$lAkdPbeeZR7YJiE3$ohWgU3LcSVit/hEZ2VOVKvxD.67.N9h5v4ML7.4X51ZK3kABbTPHkZUPzN9jxQQWXtkLctI0FJZR8CChIwz.S/' | chpasswd --encrypted

# Or if you don't pre-hash the password remove the line above and uncomment the line below.
# echo "user1:user1password" | chpasswd
```

It is strongly recommended to pre-hash passwords. Passwords that are not hashed are a security risk, other users may be able to read the `setpasswd.sh` script and see all other users passwords and keeping plain text passwords is considered bad practice.

To generate a hashed password use `mkpasswd` which is available in this image or use [https://trnubo.github.io/passwd.html](https://trnubo.github.io/passwd.html) to generate a hash in your browser. Example use of `mkpasswd` below.

```bash
docker run --rm -it --entrypoint /usr/bin/env quay.io/panubo/sshd:1.9.0 mkpasswd
Password:
$6$w0ZvF/gERVgv08DI$PTq73dIcZLfMK/Kxlw7rWDvVcYvnWJuOWtxC7sXAYZL69CnItCS.QM.nTUyMzaT0aYjDBdbCH1hDiwbQE8/BY1
```

To start sshd with the `setpasswd.sh` script

```bash
docker run -ti -p 2222:22 \
  -v $(pwd)/keys/:/etc/ssh/keys \
  -e SSH_USERS=user:1000:1000 \
  -e SSH_ENABLE_PASSWORD_AUTH=true \
  -v $(pwd)/entrypoint.d/:/etc/entrypoint.d/ \
  quay.io/panubo/sshd:1.9.0
```

To enable password authentication on the root account, the previous `setpasswd.sh` script must also define a password for the root user, then
the command will be:

```bash
docker run -ti -p 2222:22 \
  -e SSH_ENABLE_ROOT_PASSWORD_AUTH=true \
  -v $(pwd)/entrypoint.d/:/etc/entrypoint.d/ \
  quay.io/panubo/sshd:1.9.0
```

## Usage Example

The example below will run interactively and bind to port `2222`. `/data` will be
bind mounted to the host. And the ssh host keys will be persisted in a `keys`
directory.

You can access with `ssh root@localhost -p 2222` using your private key.

```bash
docker run -ti -p 2222:22 \
  -v ${HOME}/.ssh/id_rsa.pub:/root/.ssh/authorized_keys:ro \
  -v $(pwd)/keys/:/etc/ssh/keys \
  -v $(pwd)/data/:/data/ \
  -e SSH_ENABLE_ROOT=true \
  quay.io/panubo/sshd:1.9.0
```

Create a `www` user with gid/uid 48. You can access with `ssh www@localhost -p 2222` using your private key.

```bash
docker run -ti -p 2222:22 \
  -v ${HOME}/.ssh/id_rsa.pub:/etc/authorized_keys/www:ro \
  -v $(pwd)/keys/:/etc/ssh/keys \
  -v $(pwd)/data/:/data/ \
  -e SSH_USERS="www:48:48" \
  quay.io/panubo/sshd:1.9.0
```

## Docker Compose

Example `docker-compose.yml`:

```yaml
services:
  sshd:
    image: panubo/sshd
    ports:
      - "2222:22"
    environment:
      - SSH_USERS=user:1000:1000
    volumes:
      - ./keys:/etc/ssh/keys
      - ./id_rsa.pub:/etc/authorized_keys/user:ro
```

## Testing

This project uses `bats` for testing. You can run the tests using `make`:

```bash
make test
```

## Releases

For production usage, please use a versioned release rather than the floating 'latest' tag.

See the [releases](https://github.com/panubo/docker-sshd/releases) for tag usage
and release notes.

## Status

Production ready and stable.

<!-- BEGIN_BOTTOM_PANUBO -->
> [!IMPORTANT]
> ## About Panubo
>
> This project is maintained by Panubo, a technology consultancy based in Sydney, Australia. We build reliable, scalable systems and help teams master the cloud-native ecosystem.
>
> We are available for hire to help with:
>
> * SRE & Operations: Improving system reliability and incident response.
> * Platform Engineering: Building internal developer platforms that scale.
> * Kubernetes: Cluster design, security auditing, and migrations.
> * DevOps: Streamlining CI/CD pipelines and developer experience.
> * [See our other services](https://panubo.com.au/services)
>
> Need a hand with your infrastructure? [Let’s have a chat](https://panubo.com.au/contact) or email us at team@panubo.com.
<!-- END_BOTTOM_PANUBO -->
