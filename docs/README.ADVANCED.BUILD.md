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
## Advanced build minbase bootstrap container image from scratch ```( optionally with time and/or --slimify )```
Script for docker or podman with debootstrap that imports the first container image directly from testing repository ( [updates-test.software-univention.de](https://updates-test.software-univention.de/) ) to your local container registry. As you will see, the command option ``` --slimify ``` will disable and erase the man pages and unnecessary locales too. But remember that the ``` ${TAG} ``` will be expanded to include ``` -slim ```. All dpkg -- Debian package manager config files are located under [dpkg.cfg.d](../root/etc/dpkg/dpkg.cfg.d)
.
```bash
VERSION="5.0-2"; \
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
# sudo podman import --message "..." univention-corporate-server-test.tar univention-corporate-server-debootstrap:${VERSION}-test
# sudo podman image tag univention-corporate-server-debootstrap:${VERSION}-test univention-corporate-server-debootstrap:test
```
### Inspect the minbase bootstrap container image
```bash
docker image inspect univention-corporate-server-debootstrap:test
```
## Build a deployment container image with different repository server using docker build ```( optionally with time )```
```bash
VERSION="5.0-2"; IMAGE="univention-corporate-server-debootstrap"; TAG="test"; MIRROR="https://updates-test.software-univention.de/"; \
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
Successfully tagged univention-corporate-server:${VERSION}-${TAG}
Successfully tagged univention-corporate-server:test
...
real  0m44,781s
user  0m40,974s
sys   0m12,485s
...
```
### Inspect the univention-corporate-server container image
```bash
docker image inspect univention-corporate-server:test
```
## Build a deployment container image with different repository server using podman build ```( optionally with time )```
```bash
VERSION="5.0-2"; IMAGE="univention-corporate-server-debootstrap"; TAG="test"; MIRROR="https://updates-test.software-univention.de/"; \
  time podman build \
    --format docker \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg MIRROR=${MIRROR} \
    --build-arg VERSION="${VERSION}-${TAG}" \
    --build-arg COMMENT="$(podman image inspect --format '{{.Comment}}' ${IMAGE}:${TAG})" \
    --build-arg IMAGE=${IMAGE} \
    --build-arg TAG=${TAG} \
    --tag univention-corporate-server:${VERSION}-${TAG} \
    --tag univention-corporate-server:${TAG} .
...
COMMIT univention-corporate-server:${VERSION}-${TAG}
...
real  0m31,228s
user  0m24,455s
sys   0m14,547s
...
```
### Inspect the univention-corporate-server container image
```bash
podman image inspect univention-corporate-server:test
```
