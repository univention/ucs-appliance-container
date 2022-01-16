# Univention Corporate Server - Container Mode

This is a self deploying container for running a [Univention Corporate Server](https://www.univention.com/products/ucs/) ([UCS](https://docs.software-univention.de/manual.html)) with the role of [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node), [backup](https://docs.software-univention.de/manual.html#domain-ldap:Backup_Directory_Node), [replica](https://docs.software-univention.de/manual.html#domain-ldap:Replica_Directory_Node) directory node or [managed](https://docs.software-univention.de/manual.html#domain-ldap:Managed_Node) node.

## Environment and recommended container options
This is the container environment with the minimum and/or maximum amount settings. The environment variables can also set and/or unset the [univention config registry](https://docs.software-univention.de/developer-reference.html#chap:ucr) (ucr) entryes.

For minimum amount setting, you need the container option ( ``` --hostname ${hostname}.${domainname} ``` ) and you get a ucs [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node) directory node with auto generated root/Administrator password. But, take a look at all the environment options, it will explaine you the features of this project.

### First start/boot ```( systemctl status univention-container-mode-firstboot.service )```

#### set the ucs hostname by container option
  ```--hostname hostname```

#### set the ucs domainname by container option
  ```--domainname domainname```

#### or set the ucs hostname and domainname in once by container option ```( recommended )```
  ```--hostname hostname.domainname```

#### optional set the containername with container option
  ```--name hostname.domainname```

#### debug the first start/boot process DEFAULT(FALSE)
```bash
--env DEBUG=(1|yes|true|YES|TRUE)
```
This will also set some ```BASH``` options
```bash
  set -o xtrace
  set -o errexit
  set -o errtrace
  set -o nounset
  set -o pipefail
```

#### restarts the container after first start/boot succeeded DEFAULT(FALSE)
```bash
--env RESTART=(1|yes|true|YES|TRUE)
```

#### restore/recreate a primary directory node after first start/boot succeeded DEFAULT(FALSE)
Read more in section [container volumes](README.CONTAINER.VOLUMES.md).
```bash
--env BACKUPS=(1|yes|true|YES|TRUE)
```

#### maximum/special environment variables ```(egrep -- "^--env" README.ENVIRONMENT.md | sed 's/^\-\-env\s//g')```
You need a alternative way to ``` ( docker run ... --env key=value ... ) ``` or like to use the [docker swarm secrets](https://docs.docker.com/engine/swarm/secrets/) style?

This works also as read only volume mount and will be used inside the container as environment variable.

STEP 1. ``` echo ${value} > ${key} ``` or ``` jq --compact-output . ${key}.json > ${key} ```

STEP 2. ``` docker run ... --volume ${key}:/run/secrets/${key}:ro ... ``` or all in once

*SECRETS* ``` docker run ... --volume ${hostname}.secrets.${domainname}:/run/secrets:ro ... ```

Finaly, you find the secret ```key``` with ```value``` by the container path ``` /run/secrets/${key} ```, but it's not inside the environment ``` ( docker exec ... env ) ```. Pleas note, each key will be transferred into a environment file ``` ( /dev/shm/univention-container-mode.env ) ``` separately. For *PLAN B*; collect all your environment variables into one file and mount the environment file as read only volume.

```bash
cat ${PWD}/environment.env
...
key=value
...
```

*PLAN B*. ``` docker run ... --volume ${PWD}/environment.env:/dev/shm/univention-container-mode.env:ro ... ```

##### role<string DEFAULT(master)>
Set the system role to [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node), [backup](https://docs.software-univention.de/manual.html#domain-ldap:Backup_Directory_Node), [replica](https://docs.software-univention.de/manual.html#domain-ldap:Replica_Directory_Node) directory node or [managed](https://docs.software-univention.de/manual.html#domain-ldap:Managed_Node) node.

```bash
--env role=(master|slave|backup|member)
```

##### [[ role != master ]] && {
If the system role isn't a [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node) directory node, we need to join a master with a vaild accout plus password. The default value for ```dcuser``` is ```Administrator```.
```bash
--env dcname=DomainControllerName
--env dcuser=DomainControllerUserAccount
--env dcpass=DomainControllerUserPassWord
```
You have to wait for a [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node) directory node? Use ```dcwait```, but be sure that this option will wait forever! ( ``` curl --silent --fail --output /dev/null http://${dcname}/joined ``` )
```bash
--env dcwait=(1|yes|true|YES|TRUE)
```
It's also possible to set a master nameserver by using one or more vaild master ip address(es) ( IPv4 and/or IPv6 ).
```bash
--env nameserver='first second third'
```
##### }

##### rootpw<string DEFAULT(generated)>
###### DEFAULT: ```echo $(pwgen -1 -${machine_password_complexity:-scn} ${machine_password_length:-64} | tr --delete '\n') > ${FILE}```
###### FILE: ```/dev/shm/univention-container-mode.secrets``` ( will removed on second boot )
###### ONLY USE ONCE AS ROOT: ```/bin/bash /usr/lib/univention-container-mode/secrets``` optionally with join help ```/bin/bash /usr/lib/univention-container-mode/secrets --join-help```
Sets the root/Administrator password for system role master. If not a master, only the container root password will set.
```bash
--env rootpw=ADm1nAndRo0tPaSSw0rdFoRsYst3mRoleMaSt3r
```

##### sshkey<string ( PUBLIC KEY )>
###### FILE: ```echo ${sshkey} > /root/.ssh/authorized_keys```
Only the container root user will get this ssh public key.
```bash
--env sshkey='ssh-rsa key user@${hostname}.${domainname}'
```

##### nameserver<string ip list> will overwrite [univention config registry](https://docs.software-univention.de/developer-reference.html#chap:ucr) ( IPv4 and/or IPv6 )
Default for the system role master is forced as the localhost configuration ( "::1" "127.0.0.1" "127.0.1.1" ) and with the forwarder defined as ( "1.1.1.1" "8.8.8.8" "9.9.9.9" ) if any given forwarder isn't valid.
```bash
--env nameserver='first second third'
```

##### dns/forwarder<string ip list> will overwrite [univention config registry](https://docs.software-univention.de/developer-reference.html#chap:ucr) ( IPv4 and/or IPv6 )
Fallback forwarder defined as ( "1.1.1.1" "8.8.8.8" "9.9.9.9" ) if any given forwarders isn't valid.
```bash
--env forwarder='first second third'
```

##### language DEFAULT(en_US)
```bash
--env language=de_DE
```

##### encoding DEFAULT(UTF-8)
```bash
--env encoding=UTF-8
```

##### timezone DEFAULT(UTC)
```bash
--env timezone=Europe/Berlin
```

##### install/remove extra packages and/or add apps into the univention app center from JSON
Packages that start with univention ```/^univention-/``` will try to be installed via univention app center ```/^univention-<APP>/```. Removed packages are marked as automaticly installed and the value ```add-app``` instead of ```install``` will perform ``` ( univention-add-app --all <APP> ) ``` or ``` ( univention-app install --noninteractive <APP> ) ```.

Example: The package univention-samba4 will be installed via apt ``` ( apt-get install univention-samba4 ) ``` and via app center ``` ( univention-add-app --all samba4 ) ``` too. But if you need an AD-compatible domain controller ( [samba4](https://www.univention.com/products/univention-app-center/app-catalog/samba4/) ), keep it simple and use ``` ( --env install='{"add-app":["samba4"]}' ) ``` maybe with print server ( [cups](https://www.univention.com/products/univention-app-center/app-catalog/cups/) ) ``` ( --env install='{"add-app":["samba4","cups"]}' ) ```.

Read more about the app center ( [Univention App Center](https://www.univention.com/products/univention-app-center/) ) and find some useful apps ( [Univention App Center Catalog](https://www.univention.com/products/univention-app-center/app-catalog/) ).

```bash
--env install='{"(add-app|install|remove)":["(app|package)","(app|package)",...]}'
```

##### import ```key=value``` into the [univention config registry](https://docs.software-univention.de/developer-reference.html#chap:ucr) form ENV
All lowercase environment variables ```/^[a-z]/``` will overwrite the univention config registry ([ucr](https://docs.software-univention.de/developer-reference.html#chap:ucr)) entries with ```key=value``` or remove with ```key=''```, underline keys will converted to forward slash ```gsub(/\_/, "/")```. ( Excluded keys are: rootpw, sshkey, dcname, dcuser, dcpass, dcwait, language, encoding, timezone, role, license, nameserver, forwarder, domainname, hostname, registry, install, container, certificates, credentials )

```bash
--env key=value (ucr set key=value)
--env key='' (ucr unset key)
--env key_sub=value (ucr set key/sub=value)
```

##### import ```key=value``` into the [univention config registry](https://docs.software-univention.de/developer-reference.html#chap:ucr) from JSON
To remove an entry, use ```{"key":null}```, this will perform ``` ( ucr unset key ) ```.
```bash
--env registry='{"key":"value"[,"key":"value",...]}'
```

##### import external certificate(s) from JSON
Import an external root certificate. For that you need a ```CERTIFICATE(rootCA.crt)```, ```RSA-PRIVATE-KEY(rootCA.key)``` as signkey and the ```RSA-PRIVATE-PASS-PHRASE(rootCA.pass)```. The algorithm cipher is depend on the [univention config registry](https://docs.software-univention.de/developer-reference.html#chap:ucr) value ```ssl/ca/cipher``` ( ```univention-config-registry search ssl/ca/cipher``` ) and will be updated during the installation, this will be automaticly converted from JSON field ``` .root.certificate.(rsa|dsa|ecdsa).encryption.algorithm ```. It's also possible to import a host and/or sso ( ``` ucs-sso.${domainname} ``` ) certificate(s). Below you will find a minimum and a maximum JSON string to import. Default, the openssl ```PEM``` format is recommended.

This option will only work for the system role [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node) directory node ( legacy term: "[master](https://docs.software-univention.de/manual-4.4.html#domain-ldap:Domain_controller_master)" ).
```bash
--env certificates='{"root":{"certificate":{"crt":"<string(single line base64)>"},"(rsa|dsa|ecdsa)":{"encryption":{"signkey":"<string(single line base64)>","encrypted":<bool(true)>,"version":<int>,"algorithm":"<string>","password":"<string>","salt":"<string(hex)>"}}}}'
```

###### minimum certificate string, for external root certificate with passphrase and signkey ( optionally with unencrypted private key and public key )
```bash
# certificates<string JSON({
#   "root": {
#     "certificate": {
#       "crt": "<string(single line base64)>"
#     },
#     "(rsa|dsa|ecdsa)": {
#       "key": {
#         "private": "<string(single line base64)>",
#         "public": "<string(single line base64)>"
#       },
#       "encryption": {
#         "signkey": "<string(single line base64)>",
#         "encrypted": <bool(true)>,
#         "version": <int>,
#         "algorithm": "<string>",
#         "password": "<string>",
#         "salt": "<string(hex)>"
#       }
#     }
#   }
# }
# )>
```

###### maximum certificate string, for external root certificate with passphrase and optionally host and/or sso certificate
```bash
# certificates<string JSON({
#   "root": {
#     "certificate": {
#       "req": "<string(single line base64)>",
#       "crt": "<string(single line base64)>",
#       "crl": "<string(single line base64)>"
#     },
#     "(rsa|dsa|ecdsa)": {
#       "key": {
#         "private": "<string(single line base64)>",
#         "public": "<string(single line base64)>"
#       },
#       "encryption": {
#         "signkey": "<string(single line base64)>",
#         "encrypted": <bool(true)>,
#         "version": <int>,
#         "algorithm": "<string>",
#         "password": "<string>",
#         "salt": "<string(hex)>"
#       }
#     }
#   },
#   "host": {
#     "fqdn": "${hostname}.${domainname}",
#     "certificate": {
#       "req": "<string(single line base64)>",
#       "crt": "<string(single line base64)>"
#     },
#     "(rsa|dsa|ecdsa)": {
#       "key": {
#         "private": "<string(single line base64)>",
#         "public": "<string(single line base64)>"
#       }
#     }
#   },
#   "sso": {
#     "fqdn": "ucs-sso.${domainname}",
#     "certificate": {
#       "req": "<string(single line base64)>",
#       "crt": "<string(single line base64)>"
#     },
#     "(rsa|dsa|ecdsa)": {
#       "key": {
#         "private": "<string(single line base64)>",
#         "public": "<string(single line base64)>"
#       }
#     }
#   }
# }
# )>
```

If you would like to test with a self signed root certificate, you can use the following commands to generate them.

###### first: generate passphrase
``` echo $(pwgen -1 -${machine_password_complexity:-scn} ${machine_password_length:-64} | tr --delete '\n') > rootCA.pass ```

###### second: generate rsa private key with passphrase as signkey
``` openssl genrsa -${ssl_ca_cipher:-aes256} -passout pass:"$(<rootCA.pass)" -out rootCA.key ${ssl_default_bits:-4096} ```

###### third: generate the root certificate from rsa private sign key with the passphrase ( optionally noninteractiv with additional informations )
```bash
openssl req -x509 -new \
  -nodes \
  -out rootCA.crt \
  -key rootCA.key \
  -passin pass:"$(<rootCA.pass)" \
  -days ${ssl_default_days:-1825} \
  -${ssl_default_hashfunction:-sha256} \
  -set_serial 00
```

```bash
openssl req -x509 -new \
  -batch \
  -nodes \
  -out rootCA.crt \
  -key rootCA.key \
  -passin pass:"$(<rootCA.pass)" \
  -days ${ssl_default_days:-1825} \
  -${ssl_default_hashfunction:-sha256} \
  -addext "crlDistributionPoints=URI:http://dc.ucs.example:80/ucsCA.crl" \
  -addext "authorityInfoAccess=caIssuers;URI:http://dc.ucs.example:80/ucs-root-ca.crt" \
  -subj "/C=US/ST=US/L=US/O=UCS/OU=Univention Corporate Server/CN=Univention Corporate Server Root CA (ID=$(pwgen -1 -scn 9 | tr --delete '\n'))/emailAddress=ssl@ucs.example" \
  -set_serial 00
```

###### take a look into your root certificate
``` openssl x509 -noout -text -in rootCA.crt ```

###### finally: generate the option to read in the root certificate into JSON ( optionally directly from your [UCS](https://docs.software-univention.de/manual.html) or from [UCS](https://docs.software-univention.de/manual.html) container mode )
```bash
CERT=rootCA.crt; SIGN=rootCA.key; PASS=rootCA.pass; \
  echo --env certificates=\''{"root":{"certificate":{"crt":"'$(openssl x509 -outform PEM -in ${CERT} | awk '{ if( NF==1 ){ printf $0 } }')'"},"rsa":{"encryption":{"signkey":"'$(awk '{ if( NF==1 ){ printf $0 } }' ${SIGN})'","encrypted":'$(awk '/^Proc-Type/{ split($2,TYPE,","); if ( TYPE[2]=="ENCRYPTED" ) { printf "true" } }' ${SIGN})',"version":'$(awk '/^Proc-Type/{ split($2,TYPE,","); printf TYPE[1] }' ${SIGN})',"algorithm":"'$(awk '/^DEK-Info/{ split($2,DEK,","); printf DEK[1] }' ${SIGN})'","password":"'$(tr --delete '\n' < ${PASS})'","salt":"'$(awk '/^DEK-Info/{ split($2,DEK,","); printf DEK[2] }' ${SIGN})'"}}}}'\'
```

```bash
CERT=/etc/univention/ssl/ucsCA/CAcert.pem; SIGN=/etc/univention/ssl/ucsCA/private/CAkey.pem; PASS=/etc/univention/ssl/password; \
  echo --env certificates=\''{"root":{"certificate":{"crt":"'$(openssl x509 -outform PEM -in ${CERT} | awk '{ if( NF==1 ){ printf $0 } }')'"},"rsa":{"encryption":{"signkey":"'$(awk '{ if( NF==1 ){ printf $0 } }' ${SIGN})'","encrypted":'$(awk '/^Proc-Type/{ split($2,TYPE,","); if ( TYPE[2]=="ENCRYPTED" ) { printf "true" } }' ${SIGN})',"version":'$(awk '/^Proc-Type/{ split($2,TYPE,","); printf TYPE[1] }' ${SIGN})',"algorithm":"'$(awk '/^DEK-Info/{ split($2,DEK,","); printf DEK[1] }' ${SIGN})'","password":"'$(tr --delete '\n' < ${PASS})'","salt":"'$(awk '/^DEK-Info/{ split($2,DEK,","); printf DEK[2] }' ${SIGN})'"}}}}'\'
```

```bash
/bin/bash /usr/lib/univention-container-mode/certificates --minimum
```

##### license<string ( LDAP OBJECT )> [Univention License Models](https://www.univention.com/downloads/license-models/)
```bash
--env license="(-: FIXME >> LICENSE IMPORT NOT YET IMPLEMENTED << FIXME :-)"
```
