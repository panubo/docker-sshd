# SSHD

[![Docker Repository on Quay.io](https://quay.io/repository/macropin/sshd/status "Docker Repository on Quay.io")](https://quay.io/repository/macropin/sshd)

Minimal Alpine Linux Docker container with `sshd` exposed and `rsync` installed.

Mount your .ssh credentials (RSA public keys) at `/root/.ssh/` in order to access the container via root ssh.

Optionally mount a custom sshd config at `/etc/ssh/`.

## Usage Example

```
docker run -d -p 2222:22 -v /secrets/id_rsa.pub:/root/.ssh/authorized_keys -v /mnt/data/:/data/ quay.io/macropin/sshd
````
