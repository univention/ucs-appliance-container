# Univention Corporate Server - Container Mode

This is a self deploying container for running a [Univention Corporate Server](https://www.univention.com/products/ucs/) ([UCS](https://docs.software-univention.de/manual.html)) with the role of [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node), [backup](https://docs.software-univention.de/manual.html#domain-ldap:Backup_Directory_Node), [replica](https://docs.software-univention.de/manual.html#domain-ldap:Replica_Directory_Node) directory node or [managed](https://docs.software-univention.de/manual.html#domain-ldap:Managed_Node) node.

## Environment, container volumes and recommended container options
This is the container environment with additional amount settings and some recommendations to store your files.

### first and second start/boot ```( systemctl status univention-container-mode-firstboot.service univention-container-mode-recreate.service )```
The systemd service units [univention-container-mode-firstboot](../root/usr/lib/systemd/system/univention-container-mode-firstboot.service) and [univention-container-mode-recreate](../root/usr/lib/systemd/system/univention-container-mode-recreate.service) has some start conditions to detect an old container environment.

```bash
systemctl cat univention-container-mode-firstboot.service
...
[Unit]
...
ConditionPathExists=!/var/univention-join/joined
ConditionPathExists=!/var/univention-join/status
ConditionPathExists=!/etc/univention/base.conf
...
```

```bash
systemctl cat univention-container-mode-recreate.service
...
[Unit]
...
ConditionPathExists=/var/univention-join/joined
ConditionPathExists=/var/univention-join/status
ConditionPathExists=!/etc/univention/base.conf
...
```

#### container volumes ```(egrep -- "^--volume" README.CONTAINER.VOLUMES.md | sed 's/^\-\-volume\s//g')```
Based on the [Dockerfile](../Dockerfile) you can find some default volumes, but follow up you will find some recommendations to store your files.

##### volumes for a primary directory node only

###### volume for restoring/recreating ```( experimental )```
There is a systemd service unit called [univention-container-mode-backup](../root/usr/lib/systemd/system/univention-container-mode-backup.service). This unit will create a basic backup loop on each container stop/shutdown and once at first start/boot. Backups ```( univention-container-mode.$(date --utc +%FT%T.%3NZ).xz )``` older then 120 ```( ${backup_clean_min_backups:-120} )``` days will be removed during the shutdown automaticly. To enable this feature use the environment variable:
```bash
--env BACKUPS=(1|yes|true|YES|TRUE)
```
This be expected to fix the problem of losing your manual changes with ``` docker-compose pull && docker-compose up ( --force-recreate ) ``` in future for rudimentary services like ldap, ssl, ssh ... . But remember, you can't change the ```${hostname}``` or ```${domainname}```!

```bash
--volume ${CONTAINER-VOLUME-BACKUPS}:/var/backups:rw
```

Otherwise, use a volume like ``` --volume ${DOCKER-VOLUME-BACKUP}:/var/backups/univention-container-mode:rw ``` to enable the feature without any backup loop. ( With this option you don't need the environment variable! )

```bash
--volume ${CONTAINER-VOLUME-BACKUP}:/var/backups/univention-container-mode:rw
--volume ${CONTAINER-VOLUME-JOINED}:/var/univention-join:rw ( optionally )
```

```bash
ls -1 /var/backups/univention-container-mode*

/var/backups/univention-container-mode.$(date --utc +%FT%T.%3NZ).xz
/var/backups/univention-container-mode.xz

/var/backups/univention-container-mode:
( 99 ) certificates
( 99 ) ldap *without any APPs*
( 99 ) ldap *SAMBA, CUPS, ...*
( 99 ) packages
( 99 ) registry
( 99 ) samba
( 99 ) saml
( 99 ) secrets
( 99 ) ssh
```

```bash
( STATUS IN PERCERNT ) package(s) synonym
```

To be sure that the systemd service unit [univention-container-mode-backup](../root/usr/lib/systemd/system/univention-container-mode-backup.service) will work well, check your default [StopTimeout](https://docs.docker.com/engine/reference/commandline/stop/) for minimum of 300 seconds or use the container run / container compose option ``` --stop-timeout 300 ``` / ``` --stop-grace-period 300 ``` ( [docker run ... --stop-timeout 300](https://docs.docker.com/engine/reference/commandline/run/#stop-container-with-timeout---stop-timeout) / [docker service create ... --stop-grace-period 300](https://docs.docker.com/compose/compose-file/compose-file-v3/#stop_grace_period) ).
Alternative just add ``` --shutdown-timeout 300 ``` or ``` { ..."shutdown-timeout": 300... } ``` to your docker daemon or docker daemon config file.

```bash
ucr search --brief ^appcenter/apps | awk '/installed$/{ split($1,APP,"/"); print APP[3] }'

systemd-analyze blame | egrep -- univention-container-mode-recreate.service
  18min 41.336s univention-container-mode-recreate.service

rm --force --recursive /var/backups/univention-container-mode/* && \
  time systemctl restart univention-container-mode-backup.service

real  0m2.659s
user  0m0.014s
sys   0m0.004s
```

```bash
ucr search --brief ^appcenter/apps | awk '/installed$/{ split($1,APP,"/"); print APP[3] }'
cups
samba4

systemd-analyze blame | egrep -- univention-container-mode-recreate.service
  29min 52.170s univention-container-mode-recreate.service

rm --force --recursive /var/backups/univention-container-mode/* && \
  time systemctl restart univention-container-mode-backup.service

real  0m40.941s
user  0m0.004s
sys   0m0.016s
```

###### volume for LDIF<( LDAP Data Interchange Format )> ```( experimental )```
Expand LDAP with [LDIF](https://datatracker.ietf.org/doc/html/rfc2849) file(s) on a [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node) directory node ( legacy term: "[master](https://docs.software-univention.de/manual-4.4.html#domain-ldap:Domain_controller_master)" ). Optionally in [univention config registry template format](https://docs.software-univention.de/developer-reference.html#chap:ucr).

```bash
cat *.ldif
dn: ...,dc=ucs,dc=example
```

```bash
cat *.ldif ( with ucr template format )
dn: ...,@%@ldap/base@%@
```

There is a temporary univention config registry key called ``` net/get/domain/sid ``` to get the domains security identifier during the LDIF import. Hopefully useful, you find the max relative identifier and the well known identifiers for domain users, guests and admins too.

```bash
cat domain.users.ldif ( with ucr template format )
dn: uid=<UserID>,cn=users,@%@ldap/base@%@
changetype: add
...
uidNumber: @!@
ucr = dict(); ucr.update(configRegistry); print('%s' % ( int(ucr.get('net/get/domain/uid/max')) + 1 ))
@!@gidNumber: @%@net/get/domain/gid/users@%@
...
sambaSID: @%@net/get/domain/sid@%@-@!@
ucr = dict(); ucr.update(configRegistry); print('%s' % ( int(ucr.get('net/get/domain/rid/max')) + 1 ))
@!@sambaPrimaryGroupSID: @%@net/get/domain/sid@%@-@%@net/get/domain/rid/users@%@
...

dn: cn=Domain Users,cn=groups,@%@ldap/base@%@
changetype: modify
add: uniqueMember
uniqueMember: uid=<UserID>,cn=users,@%@ldap/base@%@

dn: cn=Domain Users,cn=groups,@%@ldap/base@%@
changetype: modify
add: memberUid
memberUid: <UserID>
```

```bash
cat domain.admins.ldif ( with ucr template format )
dn: uid=<AdminID>,cn=users,@%@ldap/base@%@
changetype: add
...
gidNumber: @%@net/get/domain/gid/admins@%@
...
sambaPrimaryGroupSID: @%@net/get/domain/sid@%@-@%@net/get/domain/rid/admins@%@
...
```

Read more about SIDs ([security identifiers](https://docs.microsoft.com/en-us/windows/security/identity-protection/access-control/security-identifiers)).

STEP 1. collect the LDIF file(s) in a directory like ``` ${PWD}/univention-ldap-ldif ```, maybe with a new ldap/ldap-backup secrect too

STEP 2. finally mount the volume read only

```bash
--volume ${CONTAINER-VOLUME-LDIF}:/usr/local/share/univention-ldap:ro
```

| **UCR TEMPORARY KEYS**          | DEFAULTS AND RANGES           |
|:------------------------------- |:----------------------------- |
| **net/get/domain/sid**          | domain security identifier    |
| **net/get/domain/rid/admins**   | rID(512) domain admins        |
| **net/get/domain/rid/users**    | rID(513) domain users         |
| **net/get/domain/rid/guests**   | rID(514) domain guests        |
| **net/get/domain/rid/max**      | rIDAllocationPool{1100..1599} |
| **net/get/domain/gid/admins**   | gidNumber(5000) domain admins |
| **net/get/domain/gid/users**    | gidNumber(5001) domain users  |
| **net/get/domain/gid/guests**   | gidNumber(5002) domain guests |
| **net/get/domain/uid/max**      | uidNumber{2000..????}         |

##### volumes for primary and/or backup directory node

###### volume for univention-backup ```( /usr/sbin/univention-ldap-backup )```

```bash
--volume ${CONTAINER-VOLUME-UNIVENTION-BACKUP}:/var/univention-backup:rw
```

##### volumes for every type of directory nodes and maybe a managed node too
It’s always a good idea to save your ``` home ``` and/or ``` root ``` directory and if you plan to use ``` cifs ``` ( aka: samba ).

```bash
--volume ${CONTAINER-VOLUME-CIFS}:/<YOUR PREFERRED STORAGE POINT>:rw
```

```bash
--volume ${CONTAINER-VOLUME-HOME}:/home:rw
```

```bash
--volume ${CONTAINER-VOLUME-ROOT}:/root:rw
```

If you plan to use [Docker in Docker](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities), try this for a small perfomance boost for any inner containers ( [overlay storage inside overlay storage isn't nice](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/) ).

STEP 1.) ```mkfs.xfs -f /dev/<EXCLUSIVE-CONTAINER-DISK or EXCLUSIVE-CONTAINER-VOLUME>``` ( **ATTENTION**: ``` mkfs.xfs -f ``` **will force erase the whole disk/volume** )

```bash
--volume /dev/${EXCLUSIVE-CONTAINER-DISK}:/dev/storage:rw
```