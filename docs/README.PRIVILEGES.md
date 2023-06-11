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

## Container privileges
There are four options to deploy, choose one of them. If you are unsure, you can start with option C. But make sure to later test A and B for security reasons! If your system is running podman based on SELinux, you can have a look here [Red Hat solution 3387631](https://access.redhat.com/solutions/3387631).
```bash
sudo setsebool -P container_manage_cgroup true
```
Also we need cgroup version one ```( CGroupsV1 )```. [Modify Fedora 31 to use CgroupsV2 by default](https://fedoraproject.org/wiki/Changes/CGroupsV2)
```bash
sudo dnf install libcgroup grubby || sudo yum install libcgroup grubby
sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
sudo reboot
```

For Debian 11 (bullseye) or Docker since version 20.10 with kernel 5.2 and later, check your runtime conditions too.
```bash
test $(docker info --format '{{.CgroupVersion}}') = 1 || echo "CGroupsV$(docker info --format '{{.CgroupVersion}}') isn't supported. Set your system to CGroupsV1! ( https://docs.docker.com/config/containers/runmetrics/#changing-cgroup-version )"
test $(docker info --format '{{.CgroupDriver}}' ) = systemd || echo "CGroupsDriver $(docker info --format '{{.CgroupDriver}}') isn't recommended. You can configure your runtime option to < dockerd --exec-opt native.cgroupdriver=systemd > ( https://docs.docker.com/engine/reference/commandline/dockerd/#docker-runtime-execution-options )"
```

And finaly, depend your Docker or Podman version, the option ( ```--cap-add CAP_MKNOD``` ) may not be supported or be called something else ( ```--cap-add MKNOD``` ). Test the deployment with both styles or without the option.

### (option -- A) container with minimal privileg excluding [Docker in Docker](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities) and excluding all types of packages that need higher system privileges.
```bash
docker run \
  --detach \
  --cap-add SYS_ADMIN \
  --cap-add CAP_MKNOD \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    univention-corporate-server
```

```bash
podman run \
  --detach \
  --cap-add SYS_ADMIN \
  --cap-add CAP_MKNOD \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --cap-add CAP_NET_RAW \
    univention-corporate-server
```

Podman >= 3.1.0[^1].
```bash
podman run \
  --detach \
  --systemd true \
  --cap-add SYS_ADMIN \
  --cap-add CAP_MKNOD \
    univention-corporate-server
```

This will likely generate a lot of warnings and errors in systemd journal ```( journalctl -xe )```.

### (option -- B) container privileg excluding [Docker in Docker](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities) but with most univention packages such as common internet file system ( CIFS ).
```bash
docker run \
  --detach \
  --cap-add SYS_ADMIN \
  --cap-add CAP_MKNOD \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --cap-add SYS_MODULE \
  --volume /lib/modules:/lib/modules:ro \
  --cap-add SYS_TIME \
    univention-corporate-server
```

```bash
podman run \
  --detach \
  --cap-add SYS_ADMIN \
  --cap-add CAP_MKNOD \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --cap-add SYS_MODULE \
  --volume /lib/modules:/lib/modules:ro \
  --cap-add SYS_TIME \
  --cap-add CAP_NET_RAW \
    univention-corporate-server
```

Podman >= 3.1.0[^1].
```bash
podman run \
  --detach \
  --systemd true \
  --cap-add SYS_ADMIN \
  --cap-add CAP_MKNOD \
  --cap-add SYS_MODULE \
  --volume /lib/modules:/lib/modules:ro \
  --cap-add SYS_TIME \
    univention-corporate-server
```

Read more about [SYS_ADMIN, CAP_MKNOD and SYS_MODULE](https://systemd.io/CONTAINER_INTERFACE/), also check [systemd](https://www.freedesktop.org/software/systemd/man/systemd-detect-virt.html) virt environment detection.

Also these container security options for [apparmor](https://docs.docker.com/engine/security/apparmor/) or [seccomp](https://docs.docker.com/engine/security/seccomp/) are good to know, use ```( --security-opt apparmor=unconfined ) OR ( --security-opt seccomp=unconfined )``` to disable apparmor or seccomp. Give it a try if you are in trouble with NFS. But make sure to later config apparmor/seccomp too.

### (option -- C) container has full privileges including [Docker in Docker](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities) and all univention packages such as univention app center.
```bash
docker run \
  --detach \
  --privileged \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --volume /lib/modules:/lib/modules:ro \
    univention-corporate-server
```

Podman >= 3.1.0[^1].
```bash
podman run \
  --detach \
  --privileged \
  --systemd true \
  --volume /lib/modules:/lib/modules:ro \
    univention-corporate-server
```

[^1]: Update for Podman >= 3.1.0 and/or a fresh installed fedora >= 37 (container runs from root user), maybe you don't need to fix your system for CgroupsV1. [Run Podman with systemd support ... podman run ... --systemd true](https://docs.podman.io/en/latest/markdown/podman-run.1.html#systemd-true-false-always).
