ARG IMAGE=univention-corporate-server-debootstrap
ARG TAG=latest
FROM ${IMAGE}:${TAG}

ARG DATE
ARG COMMENT
ARG VERSION
LABEL maintainer="Univention GmbH <packages@univention.de>" \
  org.label-schema.build-date=${DATE} \
  org.label-schema.name="Univention Corporate Server (UCS) Container Mode" \
  org.label-schema.description="Self deploying container for running Univention Corporate Server (UCS) with role primary, backup, replica directory node or managed node." \
  org.label-schema.url="https://www.univention.com/products/ucs/" \
  org.label-schema.vcs-ref=${VERSION} \
  org.label-schema.vcs-url="https://github.com/univention/ucs-appliance-container" \
  org.label-schema.vendor="Univention GmbH" \
  org.label-schema.version="1.0.0-dev" \
  org.label-schema.schema-version="1.0" \
  org.label-schema.docker.cmd="docker run --detach --cap-add SYS_ADMIN --volume /sys/fs/cgroup:/sys/fs/cgroup:ro --cap-add SYS_MODULE --volume /lib/modules:/lib/modules:ro --cap-add SYS_TIME --tmpfs /run/lock --tmpfs /run --tmpfs /tmp --restart unless-stopped --hostname dc.ucs.example --name dc.ucs.example univention-corporate-server:latest" \
  org.label-schema.docker.cmd.devel="docker run --env DEBUG=TRUE --detach --cap-add SYS_ADMIN --volume /sys/fs/cgroup:/sys/fs/cgroup:ro --cap-add SYS_MODULE --volume /lib/modules:/lib/modules:ro --cap-add SYS_TIME --tmpfs /run/lock --tmpfs /run --tmpfs /tmp --restart unless-stopped --hostname dc.ucs.example --name dc.ucs.example univention-corporate-server:latest" \
  org.label-schema.docker.build.from=${COMMENT}

ENV DEBIAN_FRONTEND noninteractive
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# clean only for UCS 4.x default sources.list from debootstrap
RUN \
  which ucr > /dev/null 2>&1 &&                                 \
  ucr get version/version | egrep --silent -- ^4 &&             \
  echo > /etc/apt/sources.list || /bin/true

ARG APT="apt-get --no-install-recommends -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false -o Acquire::Max-FutureTime=31536000 -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-overwrite -o DPkg::Options::=--force-overwrite-dir --trivial-only=no --assume-yes --quiet=1"

# podman run and build quick and dirty fix ( Creating new user ... chfn: PAM: System error )
RUN $(which chfn) --full-name "ucs container root" root || ln --symbolic --force /bin/true $(which chfn)

# install dependencies
RUN \
  ${APT} update;                                                \
  ${APT} --verbose-versions install                             \
  univention-base-files univention-updater                      \
  cron systemd systemd-sysv;                                    \
  ${APT} dist-upgrade --assume-yes;                             \
  ${APT} autoremove --assume-yes;                               \
  ${APT} clean

# set different repository online server by --build-arg MIRROR
ARG MIRROR="https://updates.software-univention.de/"
RUN ucr set repository/online/server=${MIRROR}

# get univention-container-mode
COPY root /

RUN \
  find                                                          \
  /usr/lib/univention-container-mode                            \
  /usr/sbin/update-initramfs                                    \
  /usr/sbin/grub-probe                                          \
  -type f | xargs touch;                                        \
  find                                                          \
  /usr/lib/univention-container-mode                            \
  /usr/sbin/update-initramfs                                    \
  /usr/sbin/grub-probe                                          \
  -type f | xargs chmod -v +x

RUN \
  rm --force                                                    \
  /etc/{machine-id,localtime,hostname,shadow,locale.conf}       \
  /var/lib/dbus/machine-id;                                     \
  rm --force --recursive                                        \
  /var/lib/apt/lists/* /tmp/* /var/tmp/* /run/* /var/run/*;     \
  rm --force                                                    \
  /var/cache/apt/archives/*.deb                                 \
  /var/cache/apt/archives/partial/*.deb                         \
  /var/cache/apt/*.bin;                                         \
  rm --force --verbose                                          \
  /var/log/univention/*.log                                     \
  /var/log/apt/*.log                                            \
  /var/log/*.log                                                \
  /var/log/{btmp,debug,faillog,lastlog,messages,syslog,wtmp}    \
  /etc/rc*.d/*                                                  \
  /etc/systemd/system/*.wants/*                                 \
  /lib/systemd/system/multi-user.target.wants/*                 \
  /lib/systemd/system/systemd-update-utmp*                      \
  /lib/systemd/system/local-fs.target.wants/*                   \
  /lib/systemd/system/sockets.target.wants/*udev*               \
  /lib/systemd/system/sockets.target.wants/*initctl*            \
  /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup*

RUN ln -s /bin/false /usr/sbin/univention-check-join-status

RUN systemctl enable --                                         \
  univention-container-mode-environment.service                 \
  univention-container-mode-firstboot.service                   \
  univention-container-mode-fixes.service                       \
  univention-container-mode-init.service

# mask tmp.mount only for UCS 4.x ( Debian Stretch )
RUN ucr get version/version | egrep --silent -- ^4 &&           \
  systemctl mask --                                             \
  tmp.mount || /bin/true

RUN systemctl mask --                                           \
  lvm2.service lvm2-activation.service lvm2-monitor.service     \
  lvm2-lvmpolld.socket lvm2-lvmpolld.service                    \
  lvm2-lvmetad.socket lvm2-lvmetad.service                      \
  dm-event.socket dm-event.service

RUN \
  sed -i 's/^#CONFIGURE_INTERFACES=yes/CONFIGURE_INTERFACES=no/g' /etc/default/networking

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

# VOLUME UCS    /etc/{univention,postfix,postgresql} /var/{lib,cache}
# VOLUME DIND   /var/lib/{docker,containerd}
# VOLUME LDAP   /var/lib/univention-ldap
# VOLUME SAMBA  /var/lib/ (sysvol, ...)

# /etc/univention /etc/machine.secret /etc/ldap.secret
VOLUME /home /sys/fs/cgroup /lib/modules /run /run/lock /tmp \
  /var/lib/docker /var/lib/containerd \
  /var/lib/univention-ldap

CMD [ "/sbin/init" ]
