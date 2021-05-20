# Univention Corporate Server - Container Mode

This is a self deploying container for running a [Univention Corporate Server](https://www.univention.com/products/ucs/) ([UCS](https://docs.software-univention.de/manual.html)) with the role of [primary node](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node), [backup node](https://docs.software-univention.de/manual.html#domain-ldap:Backup_Directory_Node), [replica node](https://docs.software-univention.de/manual.html#domain-ldap:Replica_Directory_Node) or [managed node](https://docs.software-univention.de/manual.html#domain-ldap:Managed_Node).

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

## Clean deployed container image from sensitive credentials from environment
### Step 1. Stop and export the container to temporarily image
```bash
CONTAINER=sdc.ucs.example; IMAGE=univention-corporate-server; STAGE=export; TAG=latest; \
  docker stop ${CONTAINER} && \
    docker export ${CONTAINER} | \
    docker import - \
      ${IMAGE}:${STAGE}
```
### Step 2. Build new image from temporarlly image
This will also clean the whole [Docker in Docker](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities) environment! ```(rm -rfv /var/lib/docker/* /var/lib/containerd/*)```
```bash
CONTAINER=sdc.ucs.example; IMAGE=univention-corporate-server; STAGE=export; TAG=latest; \
  docker build \
    --build-arg COMMENT="$(docker image inspect --format '{{.Comment}}' univention-corporate-server-debootstrap:latest)" \
    --build-arg CONTAINER=${CONTAINER} \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg IMAGE=${IMAGE} \
    --build-arg STAGE=${STAGE} \
    --build-arg TAG=${TAG} \
    --tag ${CONTAINER}:${TAG} \
    --file clean.environment.Dockerfile .
```
Inspect the new image.
```bash
CONTAINER=sdc.ucs.example; TAG=latest; \
  docker image inspect ${CONTAINER}:${TAG} && \
  docker image inspect --format '{{ index .Config.Labels "org.label-schema.docker.cmd"}}' ${CONTAINER}:${TAG}
```
### Step 3. Redeploy the new container
```bash
CONTAINER=sdc.ucs.example; TAG=latest; \
  docker rm \
    --force \
    --volumes \
      ${CONTAINER} && \
$(docker image inspect --format '{{ index .Config.Labels "org.label-schema.docker.cmd"}}' ${CONTAINER}:${TAG})
```
