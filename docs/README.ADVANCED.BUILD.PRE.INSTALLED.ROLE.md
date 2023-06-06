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
## Build a deployment container image with pre installed role ```( ... build --build-arg ${ARG} ... Dockerfile )```
As you can see it is possible to install apps during container build, this hidden feature is still experimental and could be used as is ( ``` --build-arg APPS="samba4 cups" ``` ).
```
# set pre installed systemd service unit, build arguments and packages for role(master) ROLE(primary directory node) and NAME(${ROLE// /-})
#  role=(master|slave|backup|member)
#  ROLE=(
#    primary directory node
#    replica directory node
#    backup directory node
#    managed node
#  )
#  APPS=<app list separated by spaces, validated by server role and non-container apps only>
ARG fail=univention-container-mode-pre-installed-role-on-failure.service
ARG unit=univention-container-mode-pre-installed-role.service
ARG role=master
ARG ROLE=primary directory node
ARG NAME=primary-directory-node
ARG APPS
ARG FILES='00-aA-DEPENDENCIES-Aa-00 \
  50-setup-system-container-role-common \
  50-setup-system-role 99-system-cleanup'

ENV role ${role}
```
Furthermore, the container labels have been adapted to the new images and can be accessed after the build process as follows:
```
docker image inspect --format '{{ index .Config.Labels "org.label-schema.docker.cmd"}}' univention-corporate-server-${role:-master}:latest
```
**Attention, if you plan to use ```CIFS/SAMBA``` as Active Directory-compatible Domain Controller, please do not use any "-" in the ```${hostname}``` and remember that the [primary directory node](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node) also needs all the necessary packages for an AD-DC!**
## Build a deployment container image with docker and pre installed role ```( optionally with time )```
```bash
declare -A roles[master]="primary directory node" roles[slave]="replica directory node" roles[backup]="backup directory node" roles[member]="managed node"; \
VERSION="5.0-3"; IMAGE="univention-corporate-server"; TAG="latest"; \
for role in ${!roles[*]}; do \
  time docker build \
    --build-arg role="${role}" \
    --build-arg ROLE="${roles[${role}]}" \
    --build-arg NAME="${roles[${role}]// /-}" \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VERSION=${VERSION} \
    --build-arg IMAGE=${IMAGE} \
    --build-arg TAG=${TAG} \
    --tag ${IMAGE}-${role}:${VERSION} \
    --tag ${IMAGE}-${role}:${TAG} \
    --file ./pre.installed.role.Dockerfile . ; \
done
...
Successfully tagged univention-corporate-server-${role}:${VERSION}
Successfully tagged univention-corporate-server-${role}:latest
...
```
### Container image build with docker, pre installed role and as Active Directory-compatible Domain Controller ```( experimental )```
```bash
declare -A roles[master]="primary directory node" roles[slave]="replica directory node" roles[backup]="backup directory node" roles[member]="managed node"; \
VERSION="5.0-3"; IMAGE="univention-corporate-server"; TAG="latest"; APPS="samba4"; \
for role in ${!roles[*]}; do \
  apps=$([[ ${role} =~ member ]] && echo -e '' || echo -e '-ad-dc'); \
  time docker build \
    --build-arg role="${role}" \
    --build-arg ROLE="${roles[${role}]}" \
    --build-arg NAME="${roles[${role}]// /-}" \
    --build-arg APPS="$([[ ${role} =~ member ]] && echo ${APPS//samba[[:digit:]]/} || echo ${APPS} )" \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VERSION=${VERSION} \
    --build-arg IMAGE=${IMAGE} \
    --build-arg TAG=${TAG} \
    --tag ${IMAGE}-${role}${apps}:${VERSION} \
    --tag ${IMAGE}-${role}${apps}:${TAG} \
    --file ./pre.installed.role.Dockerfile . ; \
done
...
Successfully tagged univention-corporate-server-${role}${apps}:${VERSION}
Successfully tagged univention-corporate-server-${role}${apps}:latest
...
```
### Inspect the univention-corporate-server-${role} container image size
```bash
docker images --format 'table {{ .Repository }}\t\t{{ .Size }}' univention-corporate-server*latest
```
## Build a deployment container image with podman and pre installed role ```( optionally with time )```
```bash
declare -A roles[master]="primary directory node" roles[slave]="replica directory node" roles[backup]="backup directory node" roles[member]="managed node"; \
VERSION="5.0-3"; IMAGE="univention-corporate-server"; TAG="latest"; \
for role in ${!roles[*]}; do \
  time podman build \
    --format docker \
    --build-arg role="${role}" \
    --build-arg ROLE="${roles[${role}]}" \
    --build-arg NAME="${roles[${role}]// /-}" \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VERSION=${VERSION} \
    --build-arg IMAGE=${IMAGE} \
    --build-arg TAG=${TAG} \
    --tag ${IMAGE}-${role}:${VERSION} \
    --tag ${IMAGE}-${role}:${TAG} \
    --file ./pre.installed.role.Dockerfile . ; \
done
...
COMMIT univention-corporate-server-${role}:${VERSION}
...
```
### Container image build with podman, pre installed role and as Active Directory-compatible Domain Controller ```( experimental )```
```bash
declare -A roles[master]="primary directory node" roles[slave]="replica directory node" roles[backup]="backup directory node" roles[member]="managed node"; \
VERSION="5.0-3"; IMAGE="univention-corporate-server"; TAG="latest"; APPS="samba4"; \
for role in ${!roles[*]}; do \
  apps=$([[ ${role} =~ member ]] && echo -e '' || echo -e '-ad-dc'); \
  time podman build \
    --format docker \
    --build-arg role="${role}" \
    --build-arg ROLE="${roles[${role}]}" \
    --build-arg NAME="${roles[${role}]// /-}" \
    --build-arg APPS="$([[ ${role} =~ member ]] && echo ${APPS//samba[[:digit:]]/} || echo ${APPS} )" \
    --build-arg DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VERSION=${VERSION} \
    --build-arg IMAGE=${IMAGE} \
    --build-arg TAG=${TAG} \
    --tag ${IMAGE}-${role}${apps}:${VERSION} \
    --tag ${IMAGE}-${role}${apps}:${TAG} \
    --file ./pre.installed.role.Dockerfile . ; \
done
...
COMMIT univention-corporate-server-${role}${apps}:${VERSION}
...
```
### Inspect the univention-corporate-server-${role} container image size
```bash
podman images --format 'table {{ .Repository }}\t\t{{ .Size }}' univention-corporate-server*latest
```
