ARG IMAGE=univention/univention-corporate-server-debootstrap
ARG TAG=latest
FROM ${IMAGE}:${TAG} AS BUILD

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

ARG APT="apt-get --no-install-recommends -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false -o Acquire::Max-FutureTime=31536000 -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-overwrite -o DPkg::Options::=--force-overwrite-dir --trivial-only=no --assume-yes --quiet=1"

# init Acquire User Agent for container build
ARG VERSION=0.0-0
ARG CICD=PRODUCTION
ARG UUID=00000000-0000-0000-0000-000000000000
RUN echo "Acquire\n{\n\thttp\n\t\t{\n\t\t\tUser-Agent \"UCS CONTAINER,${CICD} BUILD - ${VERSION} - ${UUID} - ${UUID}\";\n\t\t};\n};" > /etc/apt/apt.conf.d/55user_agent

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

# set different repository online server by --build-arg MIRROR
ARG MIRROR="https://updates.software-univention.de/"
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

RUN \
  rm --force                                                      \
  /etc/{machine-id,localtime,hostname,shadow,locale.conf}         \
  /var/lib/dbus/machine-id;                                       \
  rm --force --recursive                                          \
  /var/lib/apt/lists/* /tmp/* /var/tmp/* /run/* /var/run/*;       \
  rm --force                                                      \
  /var/cache/apt/archives/*.deb                                   \
  /var/cache/apt/archives/partial/*.deb                           \
  /var/cache/apt/*.bin                                            \
  /var/cache/debconf/*old                                         \
  /var/log/apt/*.log.*                                            \
  /var/log/apt/*.log                                              \
  /var/log/*.log                                                  \
  /var/log/{btmp,debug,faillog,lastlog,messages,syslog,wtmp}      \
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
  test -f ${SLIMIFY} && rm --force --recursive                    \
  /usr/share/{groff,info,linda,lintian,man} /var/cache/man;       \
  test -f ${SLIMIFY} &&                                           \
  find /usr/share/doc -depth -type f ! -name copyright -delete;   \
  test -f ${SLIMIFY} &&                                           \
  find / -regex '^.*\(__pycache__\|\.py[co]\)$' -delete;          \
  test -f ${SLIMIFY} &&                                           \
  find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*'    \
  -exec rm --force --verbose --recursive {} \;;                   \
  find /usr/share/doc -depth -empty -delete
RUN \
  test -f ${SLIMIFY} || find /etc/apt/apt.conf.d                  \
  -type f -name 'univention-container-mode*'                      \
  -exec rm --force --verbose {} \;;                               \
  test -f ${SLIMIFY} || find $(dirname ${SLIMIFY})                \
  -type f -name 'univention-container-mode*'                      \
  -exec rm --force --verbose {} \;
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
RUN bash -c "source /usr/lib/univention-container-mode/utils.sh;  \
  UniventionContainerModeDockerfileInit"

RUN systemctl mask --                                             \
  tmp.mount

# we don't need this service unit(s) in the container
#  see root/usr/lib/systemd/system/systemd-*.service.d/*.conf
RUN systemctl mask --                                             \
  systemd-networkd-wait-online.service
# systemd-timedated.service ( ConditionVirtualization=!container )
# systemd-resolved          ( ConditionVirtualization=!container )
# systemd-logind            ( ConditionVirtualization=!container )

RUN systemctl mask --                                             \
  lvm2.service lvm2-activation.service lvm2-monitor.service       \
  lvm2-lvmpolld.socket lvm2-lvmpolld.service                      \
  lvm2-lvmetad.socket lvm2-lvmetad.service                        \
  dm-event.socket dm-event.service

FROM scratch

COPY --from=BUILD / /

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
  org.label-schema.docker.cmd="docker run --detach --cap-add SYS_ADMIN --volume /sys/fs/cgroup:/sys/fs/cgroup:ro --cap-add SYS_MODULE --volume /lib/modules:/lib/modules:ro --cap-add SYS_TIME --tmpfs /run/lock --tmpfs /run --tmpfs /tmp:exec --restart unless-stopped --hostname dc.ucs.example --name dc.ucs.example univention/univention-corporate-server:latest" \
  org.label-schema.docker.cmd.devel="docker run --env DEBUG=TRUE --detach --cap-add SYS_ADMIN --volume /sys/fs/cgroup:/sys/fs/cgroup:ro --cap-add SYS_MODULE --volume /lib/modules:/lib/modules:ro --cap-add SYS_TIME --tmpfs /run/lock --tmpfs /run --tmpfs /tmp:exec --restart unless-stopped --hostname dc.ucs.example --name dc.ucs.example univention/univention-corporate-server:latest" \
  org.label-schema.docker.build.from=${COMMENT}

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
  /var/univention-join \
  /var/backups

CMD [ "/bin/systemd" ]
