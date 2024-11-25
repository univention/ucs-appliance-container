FROM alpine AS bootstrap
#
## install minimal dependencies ( python is not normally used )
#
ARG APK="apk add --quiet --update"
RUN ${APK} ca-certificates curl debootstrap dpkg gpg gpg-agent
#
## set target to slimify ( --build-arg SLIM=<at least one character> )
#
ARG SLIM=
#
## set target architecture
#
ARG ARCH=amd64
#
## set target major, minor and patch
#
ARG MAJOR=0
ARG MINOR=0
ARG PATCH=0
#
## set update mirror fqdn
#
ARG UPDATES="updates.software-univention.de"
#
## set update mirror uri ( uri + root => mirror url )
#
ARG PROTOCL="https://"
#
## set update mirror url ( https://manpages.debian.org/stretch/apt/sources.list.5.en.html#URI_SPECIFICATION )
#
ARG REPOSITORY="${PROTOCL}${UPDATES}"
#
## fix target version string ( get latest version from repository json file )
#
COPY <<-EOF repository.releases.py
import os; import sys; import json; import urllib.request;

### default univention repository mirrors
#
#  production: https://updates.software-univention.de/
# development: https://updates-test.software-univention.de/
#
url = os.environ.get('REPOSITORY', 'https://updates.software-univention.de')
#
status = 'maintained' if not 'test' in url else 'development'
#
### default univention ucs-releases.json from repository mirror
#
#{
#    "releases": [
#        {
#            "major": Number,
#            "minors": [
#                {
#                    "minor": Number,
#                    "patchlevels": [
#                        {
#                            "patchlevel": Number,
#                            "status": String("development", "maintained", "end-of-life")
#                        }
#                    ]
#                }
#            ]
#        }
#    ]
#}
#
try:
  request = urllib.request.urlopen(f'{url}/ucs-releases.json')
  content = request.info().get_content_charset('utf-8')
  response = json.loads(request.read().decode(content))
except:
  sys.exit(1)
#
### get releases filterd by status('maintained' or 'development')
#
for keys in response.keys():
  if keys == 'releases':
    for releases in response[keys]:
      for majors in releases.keys():
        if majors == 'major':
          MAJOR=releases[majors]

        if majors == 'minors':
          for minors in releases[majors]:
            for minor in minors.keys():
              if minor == 'minor':
                MINOR=minors[minor]

              if minor == 'patchlevels':
                for patches in minors[minor]:
                  if patches['status'] == status:
                    PATCH=patches['patchlevel']
                    print(f"{MAJOR}.{MINOR}-{PATCH}")
EOF
#
## set debootstrap minbase default environment ( is checked and adjusted at runtime )
# DEBOOTSTRAP: <string> ["PATH(/usr/sbin/debootstrap)"]
ARG DEBOOTSTRAP=/usr/sbin/debootstrap
# KEYRING: <string> ["PATH(/usr/share/keyrings/univention-archive-key-ucs-${MAJOR}x.gpg)"]
ARG KEYRING="/usr/share/keyrings/univention-archive-key-ucs-${MAJOR}x.gpg"
# DEFAULT: <string> ["apt-transport-https,apt-utils,debconf-utils"]
ARG DEFAULT="apt-transport-https,apt-utils,debconf-utils"
# INCLUDE: <string> ["python3-cffi-backend"]
ARG INCLUDE="python3-cffi-backend"
# OPTION: <string> ["/usr/sbin/debootstrap --help to see all option(s)"]
ARG OPTION="--force-check-gpg --include ${DEFAULT},${INCLUDE} --variant minbase --keyring ${KEYRING} --arch ${ARCH}"
# SUITE: <string> ["ucs${MAJOR}${MINOR}${PATCH}"]
ARG SUITE="ucs${MAJOR}${MINOR}${PATCH}"
# TARGET: <string> ["PATH(/var/cache/debootstrap)"]
ARG TARGET=/var/cache/debootstrap
# MIRROR: <string> ["https://updates.software-univention.de"]
ARG MIRROR="${REPOSITORY}/${MAJOR}.${MINOR}/maintained/${MAJOR}.${MINOR}-${PATCH}"
# SCRIPTS: <string> ["PATH(/usr/share/debootstrap/scripts)"]
ARG SCRIPTS=/usr/share/debootstrap/scripts
# SCRIPT: <string> ["PATH(${SCRIPTS}/stable)"]
ARG SCRIPT="${SCRIPTS}/stable"
# BOOTSTRAP: <string> ["debootstrap ${OPTION} ${SUITE} ${TARGET} ${MIRROR} ${SCRIPT}"]
ARG BOOTSTRAP="${DEBOOTSTRAP} --verbose ${OPTION} ${SUITE} ${TARGET} ${MIRROR} ${SCRIPT}"
#
#
## run debootstrap
#
RUN --mount=type=cache,target=${TARGET}-package-cache <<EOR
function getKeys() {
	local major=0
	while [ $((${MAJOR} + 1)) -gt ${major} ]; do
		major=$((${major} + 1))
		wget -q -P ${1:-${TARGET}}/etc/apt/trusted.gpg.d/ ${REPOSITORY}/univention-archive-key-ucs-${major}x.gpg 2>/dev/null || continue
	done
}

if echo "${MAJOR}.${MINOR}-${PATCH}" | grep -E -q -- "^0.0-0$"; then
	echo "WARN missing build arguments for major, minor and patch. The target version will be set to latest release, depend on repository url."
	${APK} python3

	export VERSION=$(
		python repository.releases.py | awk '/[[:digit:]]\.[[:digit:]]\-[[:digit:]]/{ print $0 }' | tail -1
	)

	export MAJOR=$(echo ${VERSION} | awk '{ gsub(/-/, ".", $0); split($0, VERSION, "."); printf VERSION[1] }')
	export MINOR=$(echo ${VERSION} | awk '{ gsub(/-/, ".", $0); split($0, VERSION, "."); printf VERSION[2] }')
	export PATCH=$(echo ${VERSION} | awk '{ gsub(/-/, ".", $0); split($0, VERSION, "."); printf VERSION[3] }')

	export SUITE="ucs${MAJOR}${MINOR}${PATCH}"

	export MIRROR="${REPOSITORY}/${MAJOR}.${MINOR}/maintained/${MAJOR}.${MINOR}-${PATCH}"
	export KEYRING="/usr/share/keyrings/univention-archive-key-ucs-${MAJOR}x.gpg"
	export OPTION="--force-check-gpg --include ${DEFAULT},${INCLUDE} --variant minbase --keyring ${KEYRING} --arch ${ARCH}"
	echo "INFO the target version is set to ${MAJOR}.${MINOR}-${PATCH} and keyring $(basename ${KEYRING}) is used."
fi

if echo "${MAJOR}.${MINOR}-${PATCH}" | grep -E -q -- "^[[:digit:]]{1,3}.[[:digit:]]{1,3}-[[:digit:]]{1,3}$"; then
	echo "INFO the target version is set to ${MAJOR}.${MINOR}-${PATCH} and repository url ${REPOSITORY} is used."

	sed -e '/required=/s/ usr-is-merged//' -i ${SCRIPTS}/debian-common

	if dpkg --compare-versions ${MAJOR} ge 5; then
		export MIRROR=${REPOSITORY}
	fi

	wget -q -P /tmp/ ${MIRROR}/dists/${SUITE}/Release
	wget -q -P /tmp/ ${MIRROR}/dists/${SUITE}/Release.gpg

	for i in $(seq 9); do
		test -e ${KEYRING} || curl -sSf -o ${KEYRING} -L ${REPOSITORY}/$(basename ${KEYRING}) || \
			curl -sSf -o ${KEYRING} -L ${REPOSITORY/updates-test./updates.}/$(basename ${KEYRING})

		gpg --import ${KEYRING}
		gpg --list-keys
		gpg --verify /tmp/Release.gpg /tmp/Release && break

		if dpkg --compare-versions ${MAJOR}.${MINOR}-${PATCH} ge 5.1-0; then
			export KEYRING="/usr/share/keyrings/univention-archive-key-ucs-${MAJOR}$(( ${MINOR} + ${i} - 1 ))x.gpg"
		else
			export KEYRING="/usr/share/keyrings/univention-archive-key-ucs-$(( ${MAJOR} + ${i} ))x.gpg"
		fi

		export OPTION="--force-check-gpg --include ${DEFAULT},${INCLUDE} --variant minbase --keyring ${KEYRING} --arch ${ARCH}"

	done

	if gpg --verify /tmp/Release.gpg /tmp/Release; then
		gpg --show-keys --with-fingerprint ${KEYRING} 2>/dev/null || gpg --fingerprint 2>/dev/null || /bin/true
	else
		echo "ERROR the target version ${MAJOR}.${MINOR}-${PATCH} on mirror ${MIRROR} has a missing gpg public key to verify."
		exit 1
	fi

	if dpkg --compare-versions ${MAJOR}.${MINOR}-${PATCH} ge 5.2-0; then
		export DEFAULT="${DEFAULT},usr-is-merged"
		export OPTION="--force-check-gpg --include ${DEFAULT},${INCLUDE} --variant minbase --keyring ${KEYRING} --arch ${ARCH}"
	fi

	if mountpoint -q ${TARGET}-package-cache && ${DEBOOTSTRAP} --help | grep -E -q -- --cache-dir; then
		export OPTION="${OPTION} --cache-dir ${TARGET}-package-cache"
	fi

	export BOOTSTRAP="${DEBOOTSTRAP} --verbose ${OPTION} ${SUITE} ${TARGET} ${MIRROR} ${SCRIPT}"

	for i in $(seq 3); do
		${BOOTSTRAP/verbose/download-only} && break || sleep 60
	done

	for i in $(seq 2); do
		${BOOTSTRAP} && break || sleep 300
	done

	if dpkg --compare-versions ${MAJOR} ge 5; then
		echo -e "deb [arch=${ARCH}] ${MIRROR} ${SUITE} main\ndeb [arch=${ARCH}] ${MIRROR} ${SUITE/ucs/errata} main" > \
			${TARGET}/etc/apt/sources.list
	else
		echo -e "deb [arch=${ARCH}] ${MIRROR} ${SUITE} main\ndeb [arch=${ARCH}] ${MIRROR/${MAJOR}.${MINOR}-${PATCH}/component} ${MAJOR}.${MINOR}-${PATCH}-errata/all/\ndeb [arch=${ARCH}] ${MIRROR/${MAJOR}.${MINOR}-${PATCH}/component} ${MAJOR}.${MINOR}-${PATCH}-errata/${ARCH}/" > \
			${TARGET}/etc/apt/sources.list
	fi

	test $(find ${TARGET} -type f -name "univention-archive-key-ucs-${MAJOR}*.gpg" | wc -l) -gt 0 && dpkg --compare-versions ${MAJOR}.${MINOR}-${PATCH} ge 4.4-5 || getKeys

	LANG=C.UTF-8 chroot ${TARGET} /bin/bash -c 'debconf-set-selections <<< "debconf debconf/frontend select Noninteractive"'
	LANG=C.UTF-8 chroot ${TARGET} /bin/bash -c 'apt-get -qq update'

	find ${TARGET}/var/lib/apt/lists ${TARGET}/var/log \
		-type f \
			-delete
	find ${TARGET}/var/cache/apt ${TARGET}/var/cache/debconf \
		-type f -name '*.bin' -or -name '*.deb' -or -name '*.dat-old' \
			-delete

	if test ${#SLIM} -gt 0; then

		find ${TARGET}/usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' \
			-exec rm -fr {} \;

	fi

else
	echo "ERROR the target version ${MAJOR}.${MINOR}-${PATCH} is out of syntax."
	exit 1
fi
EOR

FROM scratch AS build
ARG TARGET=/var/cache/debootstrap
COPY --from=bootstrap ${TARGET} /

ARG APT="apt-get --no-install-recommends -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false -o Acquire::Max-FutureTime=31536000 -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-overwrite -o DPkg::Options::=--force-overwrite-dir --trivial-only=no --assume-yes --quiet=1"

# set major, minor and patch
ARG MAJOR=0
ARG MINOR=0
ARG PATCH=0

# init Acquire User Agent for container build
ARG CICD=PRODUCTION
ARG UUID=00000000-0000-0000-0000-000000000000
RUN echo "Acquire\n{\n\thttp\n\t\t{\n\t\t\tUser-Agent \"UCS CONTAINER,${CICD} BUILD - ${MAJOR}.${MINOR}-${PATCH} - ${UUID} - ${UUID}\";\n\t\t};\n};" > /etc/apt/apt.conf.d/55user_agent

# podman run and build quick and dirty fix ( Creating new user ... chfn: PAM: System error )
# RUN $(which chfn) --full-name "ucs container root" root || ln --symbolic --force /bin/true $(which chfn)
# debian run and build quick and dirty fix ( Creating new user ... chfn: PAM: Authentication service cannot retrieve authentication info )
# since 2021-06-12 also on debian based systems ( maybe adduser vs useradd )
RUN \
  ln --symbolic --force /bin/true /bin/chfn;                      \
  ln --symbolic --force /bin/true /usr/bin/chfn;                  \
  ln --symbolic --force /bin/true /usr/local/bin/chfn

# Processing triggers for man-db (2.8.5-2) ... overlayfs ... ???
#  mandb --create need disk I/O ... force disabled for now
RUN \
  ln --symbolic --force /bin/true /bin/mandb;                     \
  ln --symbolic --force /bin/true /usr/bin/mandb;                 \
  ln --symbolic --force /bin/true /usr/local/bin/mandb

# systemd kmod-static-nodes service unit failed on startup/boot
#  ( Failed at step EXEC spawning /bin/kmod: No such file or directory )
#  ( kmod will installed with the join/00-aA-DEPENDENCIES-Aa-00 script )
RUN \
  ln --symbolic --force /bin/true /bin/kmod

# checking slimify from debootstrap ( no man pages, no locales, no ... )
ARG SLIMIFY=/etc/dpkg/dpkg.cfg.d/univention-container-mode-slimify
RUN \
  test -d /usr/share/locale/de >/dev/null 2>&1 || touch ${SLIMIFY}

# install minimal dependencies ( systemd )
RUN \
  ${APT} update;                                                  \
  ${APT} install systemd;                                         \
  ${APT} dist-upgrade;                                            \
  ${APT} autoremove;                                              \
  ${APT} clean

# set different repository online server by --build-arg UPDATES + PROTOCL
ARG UPDATES="updates.software-univention.de"
ARG PROTOCL="https://"
ARG MIRROR="${PROTOCL}${UPDATES}"
RUN printf "%s" ${MIRROR} > /etc/apt/mirror.url

# get univention-container-mode
COPY root /

RUN \
  find                                                            \
  /usr/lib/univention-container-mode                              \
  /usr/lib/univention-ldap/check-exec-condition                   \
  /usr/lib/univention-ldap/check-subschema-hash                   \
  /usr/sbin/update-initramfs                                      \
  /usr/sbin/update-grub                                           \
  /usr/sbin/grub-probe                                            \
  -type f -print0 | xargs -0 touch;                               \
  find                                                            \
  /usr/lib/univention-container-mode                              \
  /usr/lib/univention-ldap/check-exec-condition                   \
  /usr/lib/univention-ldap/check-subschema-hash                   \
  /usr/sbin/update-initramfs                                      \
  /usr/sbin/update-grub                                           \
  /usr/sbin/grub-probe                                            \
  -type f -print0 | xargs -0 chmod -v +x

RUN find /var/log -type f -delete
RUN \
  for file in                                                     \
    localtime timezone hostname shadow locale.conf machine-id;    \
  do rm --force /etc/${file}; done

RUN \
  rm --force /var/lib/dbus/machine-id;                            \
  rm --force --recursive                                          \
  /var/lib/apt/lists/* /tmp/* /var/tmp/* /run/* /var/run/*;       \
  rm --force                                                      \
  /var/cache/apt/archives/*.deb                                   \
  /var/cache/apt/archives/partial/*.deb                           \
  /var/cache/apt/*.bin                                            \
  /var/cache/debconf/*old                                         \
  /etc/rc*.d/*                                                    \
  /etc/systemd/system/*.wants/*                                   \
  /lib/systemd/system/multi-user.target.wants/*                   \
  /lib/systemd/system/systemd-update-utmp*                        \
  /lib/systemd/system/local-fs.target.wants/*                     \
  /lib/systemd/system/sockets.target.wants/*udev*                 \
  /lib/systemd/system/sockets.target.wants/*initctl*              \
  /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup*

# checking for slimify and/or clean up ...
RUN \
  test -f ${SLIMIFY} || find /etc/apt/apt.conf.d                  \
  -type f -name 'univention-container-mode*'                      \
  -exec rm --force --verbose {} \;;                               \
  test -f ${SLIMIFY} || find $(dirname ${SLIMIFY})                \
  -type f -name 'univention-container-mode*'                      \
  -exec rm --force --verbose {} \;
RUN /bin/bash -c "                                                \
  source /usr/lib/univention-container-mode/utils.sh;             \
  UniventionContainerModeSlimify"
RUN rm --force --verbose ${SLIMIFY}

# set univention-container-mode permission for systemd
RUN \
  find                                                            \
  /lib/systemd/system                                             \
  -type f -print0 | xargs -0 chmod -v 0644;                       \
  find                                                            \
  /lib/systemd/system                                             \
  -type d -print0 | xargs -0 chmod -v 0755

RUN ln -s /bin/false /usr/sbin/univention-check-join-status

# set the latest version of .bashrc and .profile from /etc/skel
RUN \
  ln -sf /etc/skel/.bashrc /root/.bashrc;                         \
  ln -sf /etc/skel/.profile /root/.profile

# univention-container-mode default target unit
#  systemd "last on boot, but first on halt"
RUN \
  test -f /lib/systemd/system/univention-container-mode.target && \
  ln                                                              \
  --force                                                         \
  --symbolic                                                      \
  /lib/systemd/system/univention-container-mode.target            \
  /etc/systemd/system/default.target

# univention-container-mode firstboot on failure ( a second try )
#  systemd need a real file for OnFailure service unit section
RUN \
  find                                                            \
  /lib/systemd/system                                             \
  -type l -name univention-container-mode*                        \
  -exec /bin/bash -c 'unit={}; cd $(dirname ${unit});             \
  cp --verbose --remove-destination $(readlink ${unit}) ${unit}' \;

# univention-container-mode default service unit(s)
RUN /bin/bash -c "                                                \
  source /usr/lib/univention-container-mode/utils.sh;             \
  UniventionContainerModeDockerfileInit"

RUN systemctl mask --                                             \
  tmp.mount

# we don't need this service unit(s) in the container
#  see root/usr/lib/systemd/system/systemd-*.service.d/*.conf
RUN systemctl mask --                                             \
  systemd-networkd-wait-online.service                            \
          ifupdown-wait-online.service
# systemd-timedated.service ( ConditionVirtualization=!container )
# systemd-resolved          ( ConditionVirtualization=!container )
# systemd-logind            ( ConditionVirtualization=!container )

RUN systemctl mask --                                             \
  lvm2.service lvm2-activation.service lvm2-monitor.service       \
  lvm2-lvmpolld.socket lvm2-lvmpolld.service                      \
  lvm2-lvmetad.socket lvm2-lvmetad.service                        \
  dm-event.socket dm-event.service

FROM scratch

COPY --from=build / /

ARG DATE="1970-01-01 00:00:00"

ARG MAJOR=0
ARG MINOR=0
ARG PATCH=0

LABEL maintainer="Univention GmbH <packages@univention.de>" \
  org.label-schema.build-date=${DATE} \
  org.label-schema.name="Univention Corporate Server (UCS) Container Mode" \
  org.label-schema.description="Self deploying container for running Univention Corporate Server (UCS) with role primary, backup, replica directory node or managed node." \
  org.label-schema.url="https://www.univention.com/products/ucs/" \
  org.label-schema.vcs-ref=${MAJOR}.${MINOR}-${PATCH} \
  org.label-schema.vcs-url="https://github.com/univention/ucs-appliance-container" \
  org.label-schema.vendor="Univention GmbH" \
  org.label-schema.version="1.0.0-dev" \
  org.label-schema.schema-version="1.0" \
  org.label-schema.docker.cmd="docker run --detach --cap-add SYS_ADMIN --volume /sys/fs/cgroup:/sys/fs/cgroup:rw --cap-add SYS_MODULE --volume /lib/modules:/lib/modules:ro --cap-add SYS_TIME --tmpfs /run/lock --tmpfs /run --tmpfs /tmp:exec --restart unless-stopped --hostname dc.ucs.example --name dc.ucs.example univention/univention-corporate-server:latest" \
  org.label-schema.docker.cmd.devel="docker run --env DEBUG=TRUE --detach --cap-add SYS_ADMIN --volume /sys/fs/cgroup:/sys/fs/cgroup:rw --cap-add SYS_MODULE --volume /lib/modules:/lib/modules:ro --cap-add SYS_TIME --tmpfs /run/lock --tmpfs /run --tmpfs /tmp:exec --restart unless-stopped --hostname dc.ucs.example --name dc.ucs.example univention/univention-corporate-server:latest"

ENV DEBIAN_FRONTEND noninteractive

# https://www.freedesktop.org/software/systemd/man/systemd-detect-virt.html
# https://www.freedesktop.org/software/systemd/man/systemd.unit.html#ConditionVirtualization=
ENV container docker

# HTTP(S)   (ucr search --key --brief security/packetfilter/package/univention-apache)
EXPOSE 80/tcp 443/tcp
# # SSH, NTP  (ucr search --key --brief security/packetfilter/package/univention-base-files)
# EXPOSE 22/tcp 123/tcp
# # DNS/BIND  (ucr search --key --brief security/packetfilter/package/univention-bind)
# EXPOSE 53/tcp 53/udp 7777/tcp 7777/udp
# # UDN       (ucr search --key --brief security/packetfilter/package/univention-directory-notifier)
# EXPOSE 6669/tcp
# # HEIMDAL   (ucr search --key --brief security/packetfilter/package/univention-heimdal)
# EXPOSE 544/tcp 88/tcp 88/udp 464/tcp 464/udp 749/tcp 749/udp
# # LDAP(S)   (ucr search --key --brief security/packetfilter/package/univention-ldap)
# EXPOSE 389/tcp 636/tcp 7389/tcp 7636/tcp
# # UMCS      (ucr search --key --brief security/packetfilter/package/univention-management-console-server)
# EXPOSE 6670/tcp
# # Nagios    (ucr search --key --brief security/packetfilter/package/univention-nagios-client)
# EXPOSE 5666/tcp
# # NFSv4     (ucr search --key --brief security/packetfilter/package/univention-nfs)
# EXPOSE 2049/tcp
# # NFSv3+4   (ucr search --key --brief security/packetfilter/package/univention-nfs)
# EXPOSE 111/tcp 111/udp 2049/tcp 2049/udp 32765-32769/tcp 32765-32769/udp
# # SAMBA     (ucr search --key --brief security/packetfilter/package/univention-samba*)
# EXPOSE 1024/tcp 135/tcp 137-139/tcp 137-139/udp 3268/tcp 3269/tcp 445/tcp 445/udp 49152-65535/tcp
# # MEMCACHED (ucr search --key --brief security/packetfilter/package/univention-saml)
# EXPOSE 11212/tcp

STOPSIGNAL SIGRTMIN+3

HEALTHCHECK --interval=5m --timeout=3s --retries=15 --start-period=25m \
  CMD curl --fail --output /dev/null --silent --location https://$(hostname --long)/univention/portal/ || exit 1

VOLUME /home /sys/fs/cgroup /lib/modules /run /run/lock /tmp \
  /var/lib/docker /var/lib/containerd \
  /var/lib/univention-appcenter \
  /var/univention-join \
  /var/backups

CMD [ "/bin/systemd" ]
