ARG IMAGE=univention/univention-corporate-server
ARG TAG=latest
FROM ${IMAGE}:${TAG} AS BUILD

# init Acquire User Agent for container build
ARG VERSION=0.0-0
ARG CICD=PRODUCTION
ARG UUID=00000000-0000-0000-0000-000000000000
RUN echo "Acquire\n{\n\thttp\n\t\t{\n\t\t\tUser-Agent \"UCS CONTAINER,${CICD} BUILD - ${VERSION} - ${UUID} - ${UUID}\";\n\t\t};\n};" > /etc/apt/apt.conf.d/55user_agent

# set different repository online server by --build-arg MIRROR
ARG MIRROR="https://updates.software-univention.de/"
RUN printf "%s" ${MIRROR} > /etc/apt/mirror.url

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

# (re)init Acquire User Agent for container build with pre installed role=${role^^}
RUN /bin/bash -c '                                                \
  sed -i "s/BUILD/BUILD-PRE-INSTALLED-ROLE,${role^^}/g"           \
  /etc/apt/apt.conf.d/55user_agent'

# pre installed role=${role}, add non-container app(s) and fix missing /etc/apt/mirror.url
RUN --mount=type=cache,target=/var/cache/apt/archives             \
  --mount=type=cache,target=/var/cache/univention-appcenter       \
  for file in ${FILES}; do                                        \
  /bin/bash /usr/lib/univention-container-mode/join/${file};      \
  done && find /etc/apt/sources.list.d -maxdepth 1 -type f -delete
RUN --mount=type=cache,target=/var/cache/apt/archives             \
  --mount=type=cache,target=/var/cache/univention-appcenter       \
  bash -c 'source /usr/lib/univention-container-mode/utils.sh;    \
  apps="${APPS}"; test ${#apps} -eq 0 || UniventionAddApp ${apps}'
RUN printf "%s" ${MIRROR} > /etc/apt/mirror.url

# univention config registry, set known keys to false
RUN univention-config-registry set                                \
  appcenter/docker=false repository/online=false

# univention config registry, unsetting known keys ( nicely )
RUN univention-config-registry unset                              \
  ssl/common ssl/state ssl/country ssl/locality ssl/organization  \
  mail/alias/root ssl/email repository/online                     \
  ldap/base ldap/server/name kerberos/realm

# univention config registry, unsetting known keys ( forced )
RUN for key in nameserver dns.forwarder; do                       \
  sed -i "/^${key}[[:digit:]]\:/d" /etc/univention/base.conf;     \
  done

# set installed role=${role}, fix the description and override the environment variable
RUN sed -i "s/role=%%ROLE%%/role=${role}/g"                       \
  /lib/systemd/system/${fail}.d/override.conf                     \
  /lib/systemd/system/${unit}.d/override.conf
RUN sed -i "s/%%ROLE%%/${ROLE}/g"                                 \
  /lib/systemd/system/${fail}.d/override.conf                     \
  /lib/systemd/system/${unit}.d/override.conf
RUN sed -i "s/WantedBy.*/WantedBy=multi-user.target/g"            \
  /lib/systemd/system/${unit}.d/override.conf

# pre installed packages; config file(s) and secret(s) cleanup
#  remove /etc/ldap/slapd.conf to disable slapd.service
RUN rm --force --verbose /etc/ldap/slapd.conf
#  remove all secrets ( ldap admin and backup secret, ... )
RUN find /etc -maxdepth 1 -type f -name '*.secret' -delete
#  remove all private ssh keys ( see join/{30,70}-ssh-server-keys )
RUN find /etc/ssh -type f -name '*key' -delete
#  remove all log files
RUN find /var/log -type f -delete
#  remove debian generated config file
RUN \
  find \
  /etc/ldap/slapd.d \
  -maxdepth 1 -type f -name 'cn=config.ldif' -delete || /bin/true
#  cleanup default and univention ldap directories
RUN \
  find                                                            \
  /var/lib/ldap                                                   \
  /var/lib/univention-ldap/ldap                                   \
  /var/lib/univention-ldap/translog                               \
  /var/lib/univention-directory-listener                          \
  -maxdepth 1 -type f -delete || /bin/true
#  cleanup generated sources.list from univention-config-registry
RUN find /etc/apt/sources.list.d -maxdepth 1 -type f -delete

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
RUN bash -c "source /usr/lib/univention-container-mode/utils.sh;  \
  UniventionContainerModeSlimify"

# fix ( 30univention-monitoring-client.inst ... missing subdir de )
RUN bash -c "source /usr/lib/univention-container-mode/utils.sh;  \
  UniventionContainerModeSlimifyCheck &&                          \
  mkdir --parents --verbose /usr/share/locale/de || /bin/true"

# univention-container-mode default service unit(s)
RUN bash -c "source /usr/lib/univention-container-mode/utils.sh;  \
  UniventionContainerModeDockerfileInit"

# (re)init Acquire User Agent for container build
RUN echo "Acquire\n{\n\thttp\n\t\t{\n\t\t\tUser-Agent \"UCS CONTAINER,${CICD} BUILD - ${VERSION} - ${UUID} - ${UUID}\";\n\t\t};\n};" > /etc/apt/apt.conf.d/55user_agent

FROM scratch

COPY --from=BUILD / /

ARG DATE
ARG role=master
ARG ROLE=primary directory node
ARG NAME=primary-directory-node
ARG VERSION
LABEL maintainer="Univention GmbH <packages@univention.de>" \
  org.label-schema.build-date=${DATE} \
  org.label-schema.name="Univention Corporate Server (UCS) Container Mode" \
  org.label-schema.description="Self deploying container for running Univention Corporate Server (UCS) with role ${ROLE}." \
  org.label-schema.url="https://www.univention.com/products/ucs/" \
  org.label-schema.vcs-ref=${VERSION} \
  org.label-schema.vcs-url="https://github.com/univention/ucs-appliance-container" \
  org.label-schema.vendor="Univention GmbH" \
  org.label-schema.version="1.0.0-dev" \
  org.label-schema.schema-version="1.0" \
  org.label-schema.docker.cmd="docker run --detach --cap-add SYS_ADMIN --volume /sys/fs/cgroup:/sys/fs/cgroup:ro --cap-add SYS_MODULE --volume /lib/modules:/lib/modules:ro --cap-add SYS_TIME --tmpfs /run/lock --tmpfs /run --tmpfs /tmp:exec --restart unless-stopped --hostname ${NAME}.ucs.example --name ${NAME}.ucs.example univention/univention-corporate-server-${role}:latest" \
  org.label-schema.docker.cmd.devel="docker run --env DEBUG=TRUE --detach --cap-add SYS_ADMIN --volume /sys/fs/cgroup:/sys/fs/cgroup:ro --cap-add SYS_MODULE --volume /lib/modules:/lib/modules:ro --cap-add SYS_TIME --tmpfs /run/lock --tmpfs /run --tmpfs /tmp:exec --restart unless-stopped --hostname ${NAME}.ucs.example --name ${NAME}.ucs.example univention/univention-corporate-server-${role}:latest"

ENV DEBIAN_FRONTEND noninteractive

# enable join/99-zZ-UPGRADE-LATEST-Zz-99 and skipp the default join/00-aA-APT-SOURCES-LIST-Aa-00
ENV LATEST SKIPP

# set the pre installed role=${role} as default environment key=value pair
ENV role ${role}

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
