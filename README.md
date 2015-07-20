# SSHD

Docker container with `bash`, `sshd` and `rsync` installed.

Mount your .ssh credentials at `/root/.ssh/` in order to access the container.

## Usage Example

```
docker run --rm quay.io/macropin/sshd -v /secrets/id_rsa.pub:/root/.ssh/authorized_keys:ro -v /mnt/data/:/data/
````
