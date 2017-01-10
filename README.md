# SSHD

[![Docker Repository on Quay.io](https://quay.io/repository/macropin/sshd/status "Docker Repository on Quay.io")](https://quay.io/repository/macropin/sshd)

Minimal Alpine Linux Docker container with `sshd` exposed and `rsync` installed.

Mount your .ssh credentials (RSA public keys) at `/root/.ssh/` in order to
access the container via root ssh or mount each user's key in
`/etc/ssh/authorized_keys/<username>` and set `SSH_SERS` config to create user accounts (see below).

Optionally mount a custom sshd config at `/etc/ssh/`.

## Environment Options

- `SSH_USERS` list of user accounts and uid/gids to create. eg `SSH_USERS=www/48/48,admin/1000/1000`
- `MOTD` change the login message

## Usage Example

```
docker run -d -p 2222:22 -v /secrets/id_rsa.pub:/root/.ssh/authorized_keys -v /mnt/data/:/data/ macropin/sshd
```

or

```
docker run -d -p 2222:22 -v $(pwd)/id_rsa.pub:/etc/ssh/authorized_keys/www -e SSH_USERS="www/48/48" foo bash
```
