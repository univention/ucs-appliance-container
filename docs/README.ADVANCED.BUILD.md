# Univention Corporate Server - Container Mode

This is a self deploying container for running a [Univention Corporate Server](https://www.univention.com/products/ucs/) ([UCS](https://docs.software-univention.de/manual.html)) with the role of [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node), [backup](https://docs.software-univention.de/manual.html#domain-ldap:Backup_Directory_Node), [replica](https://docs.software-univention.de/manual.html#domain-ldap:Replica_Directory_Node) directory node or [managed](https://docs.software-univention.de/manual.html#domain-ldap:Managed_Node) node.

CLI SYNTAX:
```bash
KEY=VALUE; ...; \
  COMMAND \
    --<COMMAND OPTION(S)> \
      <COMMAND ARGUMENT(S)>
...
STDOUT ( succeed )
...
STDOUT ( timeing )
...
```
## Advanced build minbase bootstrap container image from scratch ```( optionally with time )```
Script for docker or podman with debootstrap that imports the first container image directly from testing repository ( [updates-test.software-univention.de](https://updates-test.software-univention.de/) ) to your local container registry.
```bash
VERSION="5.0-0"; \
  time /bin/bash bootstrap/bootstrap.sh \
    --use-cache \
    --arch amd64 \
    --distribution univention-corporate-server-test \
    --codename ucs$(echo ${VERSION} | tr --complement --delete '[:digit:]')
...
I: Base system installed successfully.
...
real  0m45,367s
user  0m41,346s
sys   0m12,882s
...
```
If your an non root podman user, an extra step is requerd:
```bash
# sudo sudo tar --create --directory=<...debootstrap...> . | podman import --message "..." - univention-corporate-server-debootstrap:test
```
### Inspect the minbase bootstrap container image
```bash
docker image inspect univention-corporate-server-debootstrap:test
```
## Build a deployment container image with different repository server ```( optionally with time )```
```bash
VERSION="5.0-0"; IMAGE="univention-corporate-server-debootstrap"; TAG="test"; MIRROR="https://updates-test.software-univention.de/"; \
  time docker build \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg MIRROR=${MIRROR} \
    --build-arg VERSION="${VERSION}-${TAG}" \
    --build-arg COMMENT="$(docker image inspect --format '{{.Comment}}' ${IMAGE}:${TAG})" \
    --build-arg IMAGE=${IMAGE} \
    --build-arg TAG=${TAG} \
    --tag univention-corporate-server:${VERSION}-${TAG} \
    --tag univention-corporate-server:${TAG} .
...
Successfully tagged univention-corporate-server:test
...
real  1m33,056s
user   0m0,190s
sys    0m0,294s
...
```
### Inspect the univention-corporate-server container image
```bash
docker image inspect univention-corporate-server:test
```
