# Univention Corporate Server - Container Mode

This is a self deploying container for running a [Univention Corporate Server](https://www.univention.com/products/ucs/) ([UCS](https://docs.software-univention.de/manual.html)) with the role of [master](https://docs.software-univention.de/manual.html#domain-ldap:Domain_controller_master), [slave](https://docs.software-univention.de/manual.html#domain-ldap:Domain_controller_slave), [backup](https://docs.software-univention.de/manual.html#domain-ldap:Domain_controller_backup), [member](https://docs.software-univention.de/manual.html#domain-ldap:Member_server) or [basesystem](https://docs.software-univention.de/manual.html#domain-ldap:Base_system).

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

## Basic examples
First of all, the top-level domain [``` .example ```](https://en.wikipedia.org/wiki/.example) is reserved by the IETF for Testing and Documentation Examples. Don't use this for your production environment!

Read more about [Reserved Top Level DNS Names](https://tools.ietf.org/html/rfc2606) on the [IETF Tools website](https://tools.ietf.org/).

### Primary Directory Node ( legacy term: "master" ), default with minimum environment and auto generated root/Administrator password
#### deploy ```HOSTNAME(dc) DOMAINNAME(ucs.example) CONTAINERNAME(dc.ucs.example)```
```bash
FQDN=dc.ucs.example; \
  docker run \
    --detach \
    --cap-add SYS_ADMIN \
    --cap-add CAP_MKNOD \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --tmpfs /run \
    --tmpfs /tmp \
    --restart unless-stopped \
    --hostname ${FQDN} \
    --name ${FQDN} \
      univention-corporate-server
```
#### follow deploying proccess with one or more of these commands ```(CTRL+C OR CTRL+D TO EXIT)```
```bash
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-firstboot.service
...
Joined successfully
...

docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-init.service

docker exec --interactive --tty ${FQDN} watch -n 0,5 ps -axf

docker exec --interactive --tty ${FQDN} /bin/bash
```
Analyze the running time of deploy with ```( systemd-analyze blame )```.
```bash
docker exec --interactive --tty ${FQDN} /bin/bash -c 'systemd-analyze --no-pager blame | egrep univention-container-mode-firstboot'
...
  19min 5.546s univention-container-mode-firstboot.service
...
```
#### check the join status
```bash
docker exec --interactive --tty ${FQDN} /bin/bash -c '[ -e /var/univention-join/joined ] && univention-check-join-status'
... 
Joined successfully
...
```
#### get generated secrets
First look below at the example Replica Directory Node ( legacy term: "slave" ), and double check. This run's only once! In section "Advanced examples" you can find some join help for windows.
```bash
docker exec --interactive --tty ${FQDN} /bin/bash /usr/lib/univention-container-mode/secrets
... 
removed '/dev/shm/univention-container-mode.secrets'

PASSWORD FOR DOMAIN(ucs.example) ON HOST(dc) WITH ROLE(domaincontroller_master):
	LOCAL USER: USER(root)          PASS(ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r)
	DC    USER: USER(Administrator) PASS(ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r)
...
```

### Replica Directory Node ( legacy term: "slave" ), default with minimum environment, auto generated root password and sensitive credentials
#### deploy ```HOSTNAME(sdc) DOMAINNAME(ucs.example) CONTAINERNAME(sdc.ucs.example)```
```bash
MASTER=dc.ucs.example; FQDN=s${MASTER}; \
  docker run \
    --detach \
    --cap-add SYS_ADMIN \
    --cap-add CAP_MKNOD \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --tmpfs /run \
    --tmpfs /tmp \
    --restart unless-stopped \
    --env role=slave \
    --env nameserver="$(docker inspect -f '{{.NetworkSettings.GlobalIPv6Address}} {{.NetworkSettings.IPAddress}}' ${MASTER})" \
    --env dcname=${MASTER} \
    --env dcuser=Administrator \
    --env dcpass=$(docker exec --tty ${MASTER} cat /dev/shm/univention-container-mode.secrets) \
    --hostname ${FQDN} \
    --name ${FQDN} \
      univention-corporate-server
```
#### follow deploying proccess with one or more of these commands ```(CTRL+C OR CTRL+D TO EXIT)```
```bash
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-firstboot.service
... 
Joined successfully
...

docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-init.service

docker exec --interactive --tty ${FQDN} watch -n 0,5 ps -axf

docker exec --interactive --tty ${FQDN} /bin/bash
``` 
Analyze the running time of deploy with ```( systemd-analyze blame )```.
```bash
docker exec --interactive --tty ${FQDN} /bin/bash -c 'systemd-analyze --no-pager blame | egrep univention-container-mode-firstboot'
...
  14min 45.716s univention-container-mode-firstboot.service
...
```
#### check the join status
```bash
docker exec --interactive --tty ${FQDN} /bin/bash -c '[ -e /var/univention-join/joined ] && univention-check-join-status'
... 
Joined successfully
...
```
#### get generated secrets
```bash
docker exec --interactive --tty ${FQDN} /bin/bash /usr/lib/univention-container-mode/secrets
...
removed '/dev/shm/univention-container-mode.secrets'

PASSWORD FOR HOST(sdc.ucs.example) WITH ROLE(domaincontroller_slave):
	LOCAL USER: USER(root)          PASS(ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r)
...
```

### Backup Directory Node ( aka "backup" ), default with minimum environment, auto generated root password and sensitive credentials
#### deploy ```HOSTNAME(bdc) DOMAINNAME(ucs.example) CONTAINERNAME(bdc.ucs.example)```
```bash
MASTER=dc.ucs.example; FQDN=b${MASTER}; \
  docker run \
    --detach \
    --cap-add SYS_ADMIN \
    --cap-add CAP_MKNOD \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --tmpfs /run \
    --tmpfs /tmp \
    --restart unless-stopped \
    --env role=backup \
    --env nameserver="$(docker inspect -f '{{.NetworkSettings.GlobalIPv6Address}} {{.NetworkSettings.IPAddress}}' ${MASTER})" \
    --env dcname=${MASTER} \
    --env dcuser=Administrator \
    --env dcpass=$(docker exec --tty ${MASTER} cat /dev/shm/univention-container-mode.secrets) \
    --hostname ${FQDN} \
    --name ${FQDN} \
      univention-corporate-server
```
#### follow deploying proccess with one or more of these commands ```(CTRL+C OR CTRL+D TO EXIT)```
```bash
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-firstboot.service
... 
Joined successfully
...

docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-init.service

docker exec --interactive --tty ${FQDN} watch -n 0,5 ps -axf

docker exec --interactive --tty ${FQDN} /bin/bash
``` 
Analyze the running time of deploy with ```( systemd-analyze blame )```.
```bash
docker exec --interactive --tty ${FQDN} /bin/bash -c 'systemd-analyze --no-pager blame | egrep univention-container-mode-firstboot'
...
  20min 4.642s univention-container-mode-firstboot.service
...
```
#### check the join status
```bash
docker exec --interactive --tty ${FQDN} /bin/bash -c '[ -e /var/univention-join/joined ] && univention-check-join-status'
... 
Joined successfully
...
```
#### get generated secrets
```bash
docker exec --interactive --tty ${FQDN} /bin/bash /usr/lib/univention-container-mode/secrets
...
removed '/dev/shm/univention-container-mode.secrets'

PASSWORD FOR HOST(bdc.ucs.example) WITH ROLE(domaincontroller_backup):
	LOCAL USER: USER(root)          PASS(ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r)
...
```

### Memberserver, default with minimum environment, auto generated root password and sensitive credentials
#### deploy ```HOSTNAME(mdc) DOMAINNAME(ucs.example) CONTAINERNAME(mdc.ucs.example)```
```bash
MASTER=dc.ucs.example; FQDN=m${MASTER}; \
  docker run \
    --detach \
    --cap-add SYS_ADMIN \
    --cap-add CAP_MKNOD \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --tmpfs /run \
    --tmpfs /tmp \
    --restart unless-stopped \
    --env role=member \
    --env nameserver="$(docker inspect -f '{{.NetworkSettings.GlobalIPv6Address}} {{.NetworkSettings.IPAddress}}' ${MASTER})" \
    --env dcname=${MASTER} \
    --env dcuser=Administrator \
    --env dcpass=$(docker exec --tty ${MASTER} cat /dev/shm/univention-container-mode.secrets) \
    --hostname ${FQDN} \
    --name ${FQDN} \
      univention-corporate-server
```
#### follow deploying proccess with one or more of these commands ```(CTRL+C OR CTRL+D TO EXIT)```
```bash
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-firstboot.service
... 
Joined successfully
...

docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-init.service

docker exec --interactive --tty ${FQDN} watch -n 0,5 ps -axf

docker exec --interactive --tty ${FQDN} /bin/bash
``` 
Analyze the running time of deploy with ```( systemd-analyze blame )```.
```bash
docker exec --interactive --tty ${FQDN} /bin/bash -c 'systemd-analyze --no-pager blame | egrep univention-container-mode-firstboot'
...
  14min 37.323s univention-container-mode-firstboot.service
...
```
#### check the join status
```bash
docker exec --interactive --tty ${FQDN} /bin/bash -c '[ -e /var/univention-join/joined ] && univention-check-join-status'
... 
Joined successfully
...
```
#### get generated secrets
```bash
docker exec --interactive --tty ${FQDN} /bin/bash /usr/lib/univention-container-mode/secrets
...
removed '/dev/shm/univention-container-mode.secrets'

PASSWORD FOR HOST(mdc.ucs.example) WITH ROLE(memberserver):
	LOCAL USER: USER(root)          PASS(ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r)
...
```

### Basesystem, default with minimum environment and auto generated root password
#### deploy ```HOSTNAME(basesystem) DOMAINNAME(unassigned.invalid) CONTAINERNAME(basesystem.unassigned.invalid)```
```bash
FQDN=basesystem.unassigned.invalid; \
  docker run \
    --detach \
    --cap-add SYS_ADMIN \
    --cap-add CAP_MKNOD \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --tmpfs /run \
    --tmpfs /tmp \
    --restart unless-stopped \
    --env role=basesystem \
    --hostname ${FQDN} \
    --name ${FQDN} \
      univention-corporate-server
```
#### follow deploying proccess with one or more of these commands ```(CTRL+C OR CTRL+D TO EXIT)```
```bash
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-firstboot.service
...
Started Univention container mode firstboot
...

docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-init.service

docker exec --interactive --tty ${FQDN} watch -n 0,5 ps -axf

docker exec --interactive --tty ${FQDN} /bin/bash
```
Analyze the running time of deploy with ```( systemd-analyze blame )```.
```bash
docker exec --interactive --tty ${FQDN} /bin/bash -c 'systemd-analyze --no-pager blame | egrep univention-container-mode-firstboot'
...
  2min 10.057s univention-container-mode-firstboot.service
...
```
#### get generated secrets
```bash
docker exec --interactive --tty ${FQDN} /bin/bash /usr/lib/univention-container-mode/secrets
...
removed '/dev/shm/univention-container-mode.secrets'

PASSWORD FOR HOST(basesystem.unassigned.invalid) WITH ROLE(basesystem):
	LOCAL USER: USER(root)          PASS(ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r)
...
```