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
## Build a deployment container image with docker ```( optionally with time )```
```bash
MAJOR=5; MINOR=0; PATCH=9; IMAGE="univention/univention-corporate-server"; TAG="latest"; \
  time docker build \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg MAJOR=${MAJOR} \
    --build-arg MINOR=${MINOR} \
    --build-arg PATCH=${PATCH} \
    --tag ${IMAGE}:${MAJOR}.${MINOR}-${PATCH} \
    --tag ${IMAGE}:${TAG} .
...
Successfully tagged univention/univention-corporate-server:${MAJOR}.${MINOR}-${PATCH}
Successfully tagged univention/univention-corporate-server:latest
...
real  6m57,659s
user   0m1,098s
sys    0m0,901s
...
```
### Inspect the univention-corporate-server container image
```bash
docker image inspect univention/univention-corporate-server:latest
```
## Build a deployment container image with podman ```( optionally with time )```
```bash
MAJOR=5; MINOR=0; PATCH=9; IMAGE="univention/univention-corporate-server"; TAG="latest"; \
  time podman build \
    --format docker \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg MAJOR=${MAJOR} \
    --build-arg MINOR=${MINOR} \
    --build-arg PATCH=${PATCH} \
    --tag ${IMAGE}:${MAJOR}.${MINOR}-${PATCH} \
    --tag ${IMAGE}:${TAG} .
...
Successfully tagged univention/univention-corporate-server:${MAJOR}.${MINOR}-${PATCH}
Successfully tagged univention/univention-corporate-server:latest
...
real  7m12,531s
user   0m0,105s
sys    0m0,126s
...
```
### Inspect the univention-corporate-server container image
```bash
podman image inspect univention/univention-corporate-server:latest
```
