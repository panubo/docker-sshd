# SSHD

[![Docker Repository on Quay.io](https://quay.io/repository/macropin/sshd/status "Docker Repository on Quay.io")](https://quay.io/repository/macropin/sshd)

Docker container with `bash`, `sshd` and `rsync` installed.

Mount your .ssh credentials at `/root/.ssh/` in order to access the container.

## Usage Example

```
docker run --d -p 2222:22 -v /secrets/id_rsa.pub:/root/.ssh/authorized_keys:ro -v /mnt/data/:/data/ quay.io/macropin/sshd
````
