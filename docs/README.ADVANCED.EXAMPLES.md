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

## Advanced example(s) ```( --security-opt apparmor=univention-corporate-server )``` or ``` ( --privileged ) ```

Basic example for apparmor security option:
```bash
apt install apparmor-utils curl

mkdir --parents /etc/apparmor.d/{containers,abstractions} && curl \
  --silent \
  --location https://raw.githubusercontent.com/lxc/lxc/master/config/apparmor/abstractions/container-base \
  --output /etc/apparmor.d/abstractions/container-base

touch \
  /etc/apparmor.d/local/univention-corporate-server \
  /etc/apparmor.d/containers/univention-corporate-server

cat << EOF > /etc/apparmor.d/containers/univention-corporate-server
#include <tunables/global>

profile univention-corporate-server flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/container-base>

  ptrace (trace,read,tracedby,readby) peer=univention-corporate-server,

  # CGroupsV1 and CGroupsV2
  mount fstype=cgroup -> /sys/fs/cgroup/**,
  mount fstype=cgroup2 -> /sys/fs/cgroup/**,

  # nfs-server
  mount fstype=nfs*,
  mount fstype=rpc_pipefs,

  # systemd PrivateTmp
  mount options=(rw,rbind) -> **,
  mount options=(rw,make-slave) -> **,
  mount options=(rw,make-rslave) -> **,
  mount options=(rw,make-shared) -> **,
  mount options=(rw,make-rshared) -> **,
  mount options=(rw,make-private) -> **,
  mount options=(rw,make-rprivate) -> **,
  mount options=(rw,make-unbindable) -> **,
  mount options=(rw,make-runbindable) -> **,

  #include <local/univention-corporate-server>
}
EOF

ln --symbolic \
  /etc/apparmor.d/containers/univention-corporate-server \
  /etc/apparmor.d/univention-corporate-server

apparmor_parser --replace --write-cache /etc/apparmor.d/univention-corporate-server
```

Now you can use the container option ```( --security-opt apparmor=univention-corporate-server )```, but you can also activate some debugging options.
```bash
aa-status && \
  aa-complain univention-corporate-server && \
    aa-audit univention-corporate-server

tail -F /var/log/kern.log | grep "audit:"
```

### prepare container network bridge
#### deploy ```NETWORK(ucs)```
```bash
NETWORK=ucs; \
  docker network create \
    --driver bridge \
    --ipv6 \
    --subnet 172.26.0.0/24 \
    --gateway 172.26.0.1 \
    --subnet FDFF:172:26:0::/64 \
    --gateway FDFF:172:26:0::1 \
    --attachable \
    --opt "com.docker.network.bridge.name"="${NETWORK}" \
      ${NETWORK}
```

### Primary Directory Node ( legacy term: "master" ), default with minimum environment including debug and some apps, container network bridge plus security option, external root certificate and auto generated root/Administrator password
It's highly recommended to switch the option ( ```--publish-all``` ) to ( ```--publish <CONTAINER-OUTSIDE-PORT>:<CONTAINER-INSIDE-PORT>/<TCP OR UDP>```) like ( ```--publish 443:443/tcp``` ) for HTTPS or ( ```--publish 80:80/tcp``` ) for HTTP trafic over TCP depend on your services to deploy.

Read more about Container networking with [published ports](https://docs.docker.com/config/containers/container-networking/#published-ports) on Docker's documentation site [https://docs.docker.com/](https://docs.docker.com/).

#### Create a self signed root certificate
```bash
NETWORK=ucs; FQDN=dc.${NETWORK}.example; CERT=rootCA.crt; SIGN=rootCA.key; PASS=rootCA.pass; \
  echo $(pwgen -1 -${machine_password_complexity:-scn} ${machine_password_length:-64} | tr --delete '\n') > \
    ${PASS}

NETWORK=ucs; FQDN=dc.${NETWORK}.example; CERT=rootCA.crt; SIGN=rootCA.key; PASS=rootCA.pass; \
  openssl genrsa \
    -${ssl_ca_cipher:-aes256} \
    -passout pass:"$(<${PASS})" \
    -out ${SIGN} \
      ${ssl_default_bits:-4096}

NETWORK=ucs; FQDN=dc.${NETWORK}.example; DN=${NETWORK}.example; CERT=rootCA.crt; SIGN=rootCA.key; PASS=rootCA.pass; \
  openssl req -x509 -new \
    -batch \
    -nodes \
    -out ${CERT} \
    -key ${SIGN} \
    -passin pass:"$(<${PASS})" \
    -days ${ssl_default_days:-1825} \
    -${ssl_default_hashfunction:-sha256} \
    -addext "crlDistributionPoints=URI:http://${FQDN}:80/ucsCA.crl" \
    -addext "authorityInfoAccess=caIssuers;URI:http://${FQDN}:80/ucs-root-ca.crt" \
    -subj "/C=US/ST=US/L=US/O=UCS/OU=Univention Corporate Server/CN=Univention Corporate Server Root CA (ID=$(pwgen -1 -scn 9 | tr --delete '\n'))/emailAddress=ssl@${DN}" \
    -set_serial 00
```

##### take a look into your self signed root certificate
``` openssl x509 -noout -text -in rootCA.crt ```

#### (option -- A) deploy ```HOSTNAME(dc) DOMAINNAME(ucs.example) CONTAINERNAME(dc.ucs.example)``` on ```NETWORK(ucs)``` with container security option ``` ( --security-opt apparmor=univention-corporate-server ) ``` for network file system ( NFS )

Note: Depend your Docker version, the option ( ```--cap-add CAP_MKNOD``` ) may not be supported or be called ( ```--cap-add MKNOD``` ). Test the deployment with both styles or without the option.

```bash
NETWORK=ucs; FQDN=dc.${NETWORK}.example; CERT=rootCA.crt; SIGN=rootCA.key; PASS=rootCA.pass; \
  docker run \
    --detach \
    --security-opt apparmor=univention-corporate-server \
    --cap-add SYS_ADMIN \
    --cap-add CAP_MKNOD \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --cap-add SYS_MODULE \
    --volume /lib/modules:/lib/modules:ro \
    --cap-add SYS_TIME \
    --tmpfs /run \
    --tmpfs /run/lock \
    --tmpfs /tmp:exec \
    --restart unless-stopped \
    --ip 172.26.0.2 \
    --ip6 FDFF:172:26:0::2 \
    --publish-all \
    --network ${NETWORK} \
    --hostname ${FQDN} \
    --name ${FQDN} \
    --env DEBUG=TRUE \
    --env install='{"add-app":["samba4","cups"]}' \
    $(echo --env certificates=\''{"root":{"certificate":{"crt":"'$(openssl x509 -outform PEM -in ${CERT} | awk '{ if( NF==1 ){ printf $0 } }')'"},"rsa":{"encryption":{"signkey":"'$(awk '{ if( NF==1 ){ printf $0 } }' ${SIGN})'","encrypted":'$(awk '/^Proc-Type/{ split($2,TYPE,","); if ( TYPE[2]=="ENCRYPTED" ) { printf "true" } }' ${SIGN})',"version":'$(awk '/^Proc-Type/{ split($2,TYPE,","); printf TYPE[1] }' ${SIGN})',"algorithm":"'$(awk '/^DEK-Info/{ split($2,DEK,","); printf DEK[1] }' ${SIGN})'","password":"'$(tr --delete '\n' < ${PASS})'","salt":"'$(awk '/^DEK-Info/{ split($2,DEK,","); printf DEK[2] }' ${SIGN})'"}}}}'\') \
      univention-corporate-server
```

#### (option -- B) deploy ```HOSTNAME(dc) DOMAINNAME(ucs.example) CONTAINERNAME(dc.ucs.example)``` on ```NETWORK(ucs)``` with container security option ``` ( --privileg ) ``` for Docker in Docker ( dind ) and network file system ( NFS ) too

```bash
NETWORK=ucs; FQDN=dc.${NETWORK}.example; CERT=rootCA.crt; SIGN=rootCA.key; PASS=rootCA.pass; \
  docker run \
    --detach \
    --privileged \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --volume /lib/modules:/lib/modules:ro \
    --tmpfs /run \
    --tmpfs /run/lock \
    --tmpfs /tmp:exec \
    --restart unless-stopped \
    --ip 172.26.0.2 \
    --ip6 FDFF:172:26:0::2 \
    --publish-all \
    --network ${NETWORK} \
    --hostname ${FQDN} \
    --name ${FQDN} \
    --env DEBUG=TRUE \
    --env install='{"add-app":["samba4","cups"]}' \
    $(echo --env certificates=\''{"root":{"certificate":{"crt":"'$(openssl x509 -outform PEM -in ${CERT} | awk '{ if( NF==1 ){ printf $0 } }')'"},"rsa":{"encryption":{"signkey":"'$(awk '{ if( NF==1 ){ printf $0 } }' ${SIGN})'","encrypted":'$(awk '/^Proc-Type/{ split($2,TYPE,","); if ( TYPE[2]=="ENCRYPTED" ) { printf "true" } }' ${SIGN})',"version":'$(awk '/^Proc-Type/{ split($2,TYPE,","); printf TYPE[1] }' ${SIGN})',"algorithm":"'$(awk '/^DEK-Info/{ split($2,DEK,","); printf DEK[1] }' ${SIGN})'","password":"'$(tr --delete '\n' < ${PASS})'","salt":"'$(awk '/^DEK-Info/{ split($2,DEK,","); printf DEK[2] }' ${SIGN})'"}}}}'\') \
      univention-corporate-server
```

#### follow deploying proccess with one or more of these commands ```(CTRL+C OR CTRL+D TO EXIT)```
```bash
docker exec --interactive --tty ${FQDN} journalctl --all --no-hostname --follow --unit univention-container-mode-firstboot.service
...
univention-check-join-status: Joined successfully
...
```
Analyze the running time of deploy with ```( systemd-analyze blame )```.
```bash
docker exec --interactive --tty ${FQDN} /bin/bash -c 'systemd-analyze --no-pager blame | egrep univention-container-mode-firstboot'
...
  22min 34.035s univention-container-mode-firstboot.service
...
```

#### get generated secrets with join help
```bash
docker exec --interactive --tty ${FQDN} /bin/bash /usr/lib/univention-container-mode/secrets --join-help
...
removed '/dev/shm/univention-container-mode.secrets'

SET PROFILEPATH, SAMBAHOME AND HOMEDRIVE FOR DC USER(Administrator) TO
	PROFILEPATH(%LOGONSERVER%\%USERNAME%\windows-profiles\default)
	SAMBAHOME(\\dc.ucs.example\Administrator)
	HOMEDRIVE(U:)

PASSWORD FOR DOMAIN(ucs.example) ON HOST(dc) WITH ROLE(domaincontroller_master):
	LOCAL USER(root)          PASS(ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r)
	DC    USER(Administrator) PASS(ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r)

--join-help

0.	DC    HELP: SOME USEFUL COMMANDS ON YOUR LOCAL WINDOWS MACHINE WITH ADMINISTRATIVE PRIVILEGES ...
0.1	   COMMAND: YOU CAN COPY AND PASTE THE PowerShell( ... ) COMMANDS DIRECTLY TO YOUR POWERSHELL ...

1.	DC     DNS: DO NOT FORGET TO SETUP THE DOMAIN NAME SERVICE CONFIGURATION ON YOUR LOCAL MACHINE ;)
1.1	     CHECK: PowerShell(nslookup dc.ucs.example)

2.	DC ROOT CA: PowerShell(curl.exe --silent --location http://dc.ucs.example/ucs-root-ca.crt --output C:\ucs.example-root-ca.crt)
2.1	  TRUST CA: PowerShell(Import-Certificate -FilePath C:\ucs.example-root-ca.crt -CertStoreLocation 'Cert:\LocalMachine\Root' -Verbose)
2.2	  CLEAN CA: PowerShell(Remove-Item -Path C:\ucs.example-root-ca.crt -Force)
2.3	 INTERFACE: HTTPS(https://dc.ucs.example) OR BUT NOT RECOMMANDED HTTP(http://dc.ucs.example)

3.	DC    JOIN: PowerShell($D="ucs.example"; $P="ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r" | ConvertTo-SecureString -asPlainText -Force; $U="$D\Administrator"; $C=New-Object System.Management.Automation.PSCredential($U,$P); Add-Computer -DomainName $D -Credential $C)
3.1	    REBOOT: PowerShell(Restart-Computer -ComputerName localhost -Force)
3.2	     LOGIN: AFTER SUCCESSFULY JOIN YOU CAN LOGIN WITH USER(UCS\Administrator) AND PASS(ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r)
3.3	      ADMX: GET ADMINISTRATIVE TEMPLATES FROM(https://www.microsoft.com/en-us/search?q=Administrative+Templates+admx+Windows+10) AND SYNC THE DIRECTORY(PolicyDefinitions) TO(\\dc.ucs.example\sysvol\ucs.example\Policies\)
...
```

Some useful links for Microsoft Windows:

 - [Installing Microsoft Remote Server Administration Tools](https://wiki.samba.org/index.php/Installing_RSAT) and use ```gpmc.msc``` to manage your Group Policy.

 - [Download and copy the Administrative Templates (.admx) for Windows 10](https://www.microsoft.com/en-us/search?q=Administrative+Templates+admx+Windows+10) into your domain sysvol.

 - [Configuring Windows clients for single sign-on (SSO) with Kerberos logins](https://help.univention.com/t/configuring-windows-clients-for-single-sign-on-sso-with-kerberos-logins/8719)


### (backup directory node, replica directory node, managed node), you can follow the pattern from basic examples with container option ```( --network ${NETWORK} AND --ip <IPv4> --ip6 <IPv6> )```
