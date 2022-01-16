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
## Build minbase bootstrap container image from scratch ```( optionally with time and/or --slimify )```
Script for docker or podman with debootstrap that imports the first container image to local registry. But, there are some dependencies for this. You can have a look into the script [bootstrap.sh](../bootstrap/bootstrap.sh) or maybe you will get some instructions to fix them. As you will see, the command option ``` --slimify ``` will disable and erase the man pages and unnecessary locales too. But remember that the ``` ${TAG} ``` will be expanded to include ``` -slim ```.
```bash
VERSION="5.0-1"; \
  time /bin/bash bootstrap/bootstrap.sh \
    --use-cache \
    --arch amd64 \
    --distribution univention-corporate-server \
    --codename ucs$(echo ${VERSION} | tr --complement --delete '[:digit:]')
...
I: Base system installed successfully.
...
real  0m43,683s
user  0m42,266s
sys   0m11,632s
...
```
If your an non root podman user, an extra step is requerd:
```bash
# sudo podman import --message "..." univention-corporate-server.tar univention-corporate-server-debootstrap:${VERSION}
# sudo podman image tag univention-corporate-server-debootstrap:${VERSION} univention-corporate-server-debootstrap:latest
```
For podman users, give this a try in your shell/bash. With or without sudo privileges.
```bash
alias docker="podman"
alias docker="sudo podman"
```
### Inspect the minbase bootstrap container image
```bash
docker image inspect univention-corporate-server-debootstrap:latest
```
## Build a deployment container image with docker ```( optionally with time )```
```bash
VERSION="5.0-1"; IMAGE="univention-corporate-server-debootstrap"; TAG="latest"; \
  time docker build \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VERSION=${VERSION} \
    --build-arg COMMENT="$(docker image inspect --format '{{.Comment}}' ${IMAGE}:${TAG})" \
    --build-arg IMAGE=${IMAGE} \
    --build-arg TAG=${TAG} \
    --tag univention-corporate-server:${VERSION} \
    --tag univention-corporate-server:${TAG} .
...
Successfully tagged univention-corporate-server:${VERSION}
Successfully tagged univention-corporate-server:latest
...
real  0m26,524s
user   0m0,118s
sys    0m0,083s
...
```
### Inspect the univention-corporate-server container image
```bash
docker image inspect univention-corporate-server:latest
```
## Build a deployment container image with podman ```( optionally with time )```
```bash
VERSION="5.0-1"; IMAGE="univention-corporate-server-debootstrap"; TAG="latest"; \
  time podman build \
    --format docker \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VERSION=${VERSION} \
    --build-arg COMMENT="$(podman image inspect --format '{{.Comment}}' ${IMAGE}:${TAG})" \
    --build-arg IMAGE=${IMAGE} \
    --build-arg TAG=${TAG} \
    --tag univention-corporate-server:${VERSION} \
    --tag univention-corporate-server:${TAG} .
...
COMMIT univention-corporate-server:${VERSION}
...
real  0m32,375s
user  0m24,320s
sys   0m14,723s
...
```
### Inspect the univention-corporate-server container image
```bash
podman image inspect univention-corporate-server:latest
```
