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
## Build a deployment container image with different repository server using docker build ```( optionally with time )```
```bash
MAJOR=5; MINOR=2; PATCH=1; IMAGE="univention/univention-corporate-server"; TAG="test"; UPDATES="updates-test.software-univention.de"; \
  time docker build \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg UPDATES=${UPDATES} \
    --build-arg MAJOR=${MAJOR} \
    --build-arg MINOR=${MINOR} \
    --build-arg PATCH=${PATCH} \
    --tag ${IMAGE}:${MAJOR}.${MINOR}-${PATCH}-${TAG} \
    --tag ${IMAGE}:${TAG} .
...
Successfully tagged univention/univention-corporate-server:${MAJOR}.${MINOR}-${PATCH}-${TAG}
Successfully tagged univention/univention-corporate-server:test
...
real  6m57,659s
user   0m1,098s
sys    0m0,901s
...
```
### Inspect the univention-corporate-server container image
```bash
docker image inspect univention/univention-corporate-server:test
```
## Build a deployment container image with different repository server using podman build ```( optionally with time )```
```bash
MAJOR=5; MINOR=2; PATCH=1; IMAGE="univention/univention-corporate-server"; TAG="test"; UPDATES="updates-test.software-univention.de"; \
  time podman build \
    --format docker \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg UPDATES=${UPDATES} \
    --build-arg MAJOR=${MAJOR} \
    --build-arg MINOR=${MINOR} \
    --build-arg PATCH=${PATCH} \
    --tag ${IMAGE}:${MAJOR}.${MINOR}-${PATCH}-${TAG} \
    --tag ${IMAGE}:${TAG} .
...
Successfully tagged univention/univention-corporate-server:${MAJOR}.${MINOR}-${PATCH}-${TAG}
Successfully tagged univention/univention-corporate-server:test
...
real  6m58,351s
user   0m0,102s
sys    0m0,097s
...
```
### Inspect the univention-corporate-server container image
```bash
podman image inspect univention/univention-corporate-server:test
```
## Build a deployment container image as a slimify variant using docker build ```( optionally with time )```
```bash
MAJOR=5; MINOR=2; PATCH=1; IMAGE="univention/univention-corporate-server"; TAG="test"; SLIM="slim"; UPDATES="updates-test.software-univention.de"; \
  time docker build \
    --build-arg SLIM=${SLIM} \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg UPDATES=${UPDATES} \
    --build-arg MAJOR=${MAJOR} \
    --build-arg MINOR=${MINOR} \
    --build-arg PATCH=${PATCH} \
    --tag ${IMAGE}:${MAJOR}.${MINOR}-${PATCH}-${TAG}-${SLIM} \
    --tag ${IMAGE}:${TAG}-${SLIM} .
...
Successfully tagged univention/univention-corporate-server:${MAJOR}.${MINOR}-${PATCH}-${TAG}-${SLIM}
Successfully tagged univention/univention-corporate-server:test-slim
...
real  6m42,444s
user   0m0,999s
sys    0m0,819s
...
```
### Inspect the univention-corporate-server container image
```bash
docker image inspect univention/univention-corporate-server:test-slim
```
## Build a deployment container image as a slimify variant using podman build ```( optionally with time )```
```bash
MAJOR=5; MINOR=2; PATCH=1; IMAGE="univention/univention-corporate-server"; TAG="test"; SLIM="slim"; UPDATES="updates-test.software-univention.de"; \
  time podman build \
    --format docker \
    --build-arg SLIM=${SLIM} \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg UPDATES=${UPDATES} \
    --build-arg MAJOR=${MAJOR} \
    --build-arg MINOR=${MINOR} \
    --build-arg PATCH=${PATCH} \
    --tag ${IMAGE}:${MAJOR}.${MINOR}-${PATCH}-${TAG}-${SLIM} \
    --tag ${IMAGE}:${TAG}-${SLIM} .
...
Successfully tagged univention/univention-corporate-server:${MAJOR}.${MINOR}-${PATCH}-${TAG}-${SLIM}
Successfully tagged univention/univention-corporate-server:test-slim
...
real   7m2,239s
user   0m0,024s
sys    0m0,068s
...
```
### Inspect the univention-corporate-server container image
```bash
podman image inspect univention/univention-corporate-server:test-slim
```
## Build a deployment container image with the latest development version using docker build ```( optionally with time )```
```bash
MAJOR=0; MINOR=0; PATCH=0; IMAGE="univention/univention-corporate-server"; TAG="devel"; UPDATES="updates-test.software-univention.de"; \
  time docker build \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg UPDATES=${UPDATES} \
    --build-arg MAJOR=${MAJOR} \
    --build-arg MINOR=${MINOR} \
    --build-arg PATCH=${PATCH} \
    --tag ${IMAGE}:${MAJOR}.${MINOR}-${PATCH}-${TAG} \
    --tag ${IMAGE}:${TAG} .
...
Successfully tagged univention/univention-corporate-server:${MAJOR}.${MINOR}-${PATCH}-${TAG}
Successfully tagged univention/univention-corporate-server:devel
...
real  6m58,719s
user   0m1,197s
sys    0m0,765s
...
```
### Inspect the univention-corporate-server container image
```bash
docker image inspect univention/univention-corporate-server:devel
```
## Build a deployment container image with the latest development version using podman build ```( optionally with time )```
```bash
MAJOR=0; MINOR=0; PATCH=0; IMAGE="univention/univention-corporate-server"; TAG="devel"; UPDATES="updates-test.software-univention.de"; \
  time podman build \
    --format docker \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg UPDATES=${UPDATES} \
    --build-arg MAJOR=${MAJOR} \
    --build-arg MINOR=${MINOR} \
    --build-arg PATCH=${PATCH} \
    --tag ${IMAGE}:${MAJOR}.${MINOR}-${PATCH}-${TAG} \
    --tag ${IMAGE}:${TAG} .
...
Successfully tagged univention/univention-corporate-server:${MAJOR}.${MINOR}-${PATCH}-${TAG}
Successfully tagged univention/univention-corporate-server:devel
...
real  8m11,503s
user   0m0,125s
sys    0m0,137s
...
```
### Inspect the univention-corporate-server container image
```bash
podman image inspect univention/univention-corporate-server:devel
```