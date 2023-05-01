#!/bin/bash
#
# Univention Container Mode - utils
#
# Copyright 2020-2021 Univention GmbH
#
# http://www.univention.de/
#
# All rights reserved.
#
# The source code of this program is made available
# under the terms of the GNU Affero General Public License version 3
# (GNU AGPL V3) as published by the Free Software Foundation.
#
# Binary versions of this program provided by Univention to you as
# well as other copyrighted, protected or trademarked materials like
# Logos, graphics, fonts, specific documentations and configurations,
# cryptographic keys etc. are subject to a license agreement between
# you and Univention and not subject to the GNU AGPL V3.
#
# In the case you use this program under the terms of the GNU AGPL V3,
# the program is provided in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public
# License with the Debian GNU/Linux or Univention distribution in file
# /usr/share/common-licenses/AGPL-3; if not, see
# <http://www.gnu.org/licenses/>.

export DEBUG=${DEBUG:-FALSE}

[[ ${DEBUG-} =~ ^1|yes|true|YES|TRUE$ ]] && {
	set -o xtrace
	set -o errexit
	set -o errtrace
	set -o nounset
	set -o pipefail
}

## util(s) for container mode environment
#
function debug() { # debug: IN(${@}) => OUT(debug<string>)
	if [[ ${DEBUG-} =~ ^1|yes|true|YES|TRUE$ ]]; then
		echo ${@}
	fi
}
#
function netmask() { # netmask: IN(cidr) => OUT(netmask)
	local ui32=$((0xffffffff << (32 - $1)))
	shift
	local mask n
	for n in {1..4}; do
		mask=$((ui32 & 0xff))${mask:+.}${mask:-}
		ui32=$((ui32 >> 8))
	done
	echo ${mask}
}
#
function EGrepLdapAddExcludeAttributeFilter() { # EGrepLdapAddExcludeAttributeFilter: stdin/stdout ( pipe )
	local filter="(structuralObjectClass|entryUUID|creatorsName|createTimestamp|entryCSN|modifiersName|modifyTimestamp|lockTime)"
	#
	# filter invalide ldif/ldapadd attributes
	# filter from diff ( if we don't have any function arguments )
	#  --unified  (egrep -- "^\+") | cut -c 2-
	#  --new-file (egrep --invert-match -- "^\+\+\+")
	#    ignore # (egrep --invert-match -- "^\+#")
	[[ "${#@}" -eq 0 || -z "${@}" ]] &&
		egrep -- "^\+" | egrep --invert-match -- "^\+\+\+" | egrep --invert-match -- "^\+#" | cut -c 2- |
		egrep \
			--invert-match -- ${filter} ||
		egrep ${@} \
			--invert-match -- ${filter}
}
#
function UniventionDefaultBranchGitHub() { # UniventionDefaultBranchGitHub: void
	local url="https://api.github.com/repos/univention/univention-corporate-server/tags"

	command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; import json; import urllib.request; sys.exit(0)' ||
		return ${?}

	python3 <<EOF 2>/dev/null
import sys
import json
import urllib.request

try:
  request = urllib.request.urlopen('${url}')
  content = request.info().get_content_charset('utf-8')
  release = json.loads(request.read().decode(content))[0]['name']
except:
  sys.exit(1)

print(release)
EOF
}
#
function UniventionLatestReleaseMirror() { # UniventionLatestReleaseMirror: void
	local url=$(
		ucr get repository/online/server 2>/dev/null | egrep -- ^http ||
			printf "%s" "https://updates.software-univention.de/"
	)

	command -v python3 >/dev/null 2>&1 && python3 -c 'import os; import sys; import json; import urllib.request; sys.exit(0)' ||
		return ${?}

	python3 <<EOF 2>/dev/null
import os
import sys
import json
import urllib.request

### default univention repository mirrors
#
#  production: https://updates.software-univention.de/
# development: https://updates-test.software-univention.de/
#
file='/etc/apt/mirror.url'
if os.path.isfile(file):
  mirror = open(file, 'r')
  url = mirror.read().replace('\n', '')
  mirror.close()
else:
  url = '${url}'
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
### release=(MAJOR, MINOR, PATCH)
#
release=(0,0,0)
#
### get latest release filterd by status('maintained' or 'development')
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
                    release=(MAJOR, MINOR, PATCH)
#
if not 'release-0.0-0' in (f"release-{release[0]}.{release[1]}-{release[2]}"):
  print(f"release-{release[0]}.{release[1]}-{release[2]}")
else:
  sys.exit(1)
#
EOF
}
#
function UniventionAptSourcesList() { # UniventionAptSourcesList: IN(major,minor,patch)
	local major=${1-}
	local minor=${2-}
	local patch=${3-}

	echo "${major}.${minor}-${patch}" | egrep --quiet -- "^[[:digit:]]\.[[:digit:]]\-[[:digit:]]$" || return ${?}

	local arch="amd64" suite="ucs${major}${minor}${patch}"

	[[ -f /etc/apt/mirror.url ]] && mirror=$(tr --delete '\n' </etc/apt/mirror.url) || mirror="https://updates.software-univention.de"

	for i in {0..1}; do # check and/or download new gpg keys ( don't forget the next major )
		keyring="univention-archive-key-ucs-$((${major} + ${i}))x.gpg"
		[[ $(find /{etc/apt/trusted.gpg.d,usr/share/keyrings} -type f -name ${keyring} | wc -l) -gt 0 ]] ||
			python3 -c "import urllib.request; urllib.request.urlretrieve('${mirror}/${keyring}', '/etc/apt/trusted.gpg.d/${keyring}')" >/dev/null 2>&1 || /bin/true
	done

	[[ ${major} -ge 5 ]] || mirror="${mirror}/${major}.${minor}/maintained/${major}.${minor}-${patch}"

	if [[ ${major} -ge 5 ]]; then
		echo -e "deb [arch=${arch}] ${mirror} ${suite} main\ndeb [arch=${arch}] ${mirror} ${suite/ucs/errata} main" > \
			/etc/apt/sources.list
	else
		echo -e "deb [arch=${arch}] ${mirror} ${suite} main\ndeb [arch=${arch}] ${mirror/${major}.${minor}-${patch}/component} ${major}.${minor}-${patch}-errata/all/\ndeb [arch=${arch}] ${mirror/${major}.${minor}-${patch}/component} ${major}.${minor}-${patch}-errata/${arch}/" > \
			/etc/apt/sources.list
	fi

	find /etc/apt/sources.list.d -type f -delete
}
#
function UniventionInstallCleanUp() { # UniventionInstallCleanUp: void
	for name in "dpkg-dist" "debian"; do
		find /etc \
			-type f \
			-name "*.${name}" \
			-exec rm --force --verbose {} \;
	done
}
#
function UniventionInstallLock() { # UniventionInstallLock: IN(${@})
	local counter=1
	local repeat=720
	local sleep=2.5

	local \
		TIMEOUT="Waiting for dpkg"

	[[ "${#@}" -eq 0 || -z "${@}" ]] ||
		TIMEOUT="Waiting for ${@}"

	echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

	printf "%s" "${TIMEOUT} .."
	while fuser --silent /var/lib/dpkg/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
		[[ ${counter} > ${repeat} ]] && printf "%s" "\nTIMEOUT(${TIMEOUT})" && return 1
		counter=$((${counter} + 1))
		sleep ${sleep} && printf "%c" "."
	done
	printf ".\n"
}
#
function UniventionAddApp() { # UniventionAddApp: IN(${@})
	[[ "${#@}" -eq 0 || -z "${@}" ]] && return 1
	[[ "${#@}" -eq 0 || -z "${@}" ]] || {
		local timeout=1200

		UniventionDistUpdate >/dev/null 2>&1

		if command -v univention-app; then
			univention-app update
			if [[ "$(ucr get server/role)" == "domaincontroller_master" ]]; then
				timeout ${timeout} univention-app install --noninteractive \
					${@}
			else
				timeout ${timeout} univention-app install --noninteractive \
					--username ${dcuser:-Administrator} \
					--pwdfile <(printf "%s" "${dcpass}") \
					${@}
			fi
		else
			command -v univention-add-app || return 1
			timeout ${timeout} univention-add-app --all ${@}
		fi

		UniventionInstallCleanUp
	}
}
#
function UniventionInstall() { # UniventionInstall: IN(${@})
	[[ "${#@}" -eq 0 || -z "${@}" ]] && return 1
	[[ "${#@}" -eq 0 || -z "${@}" ]] || {
		local timeout=1800

		local counter=1
		local repeat=5
		local sleep=120

		local UniventionSystemInstallCommand="$(
			ucr get update/commands/install | egrep -- ^apt || printf "%s" "apt-get -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-overwrite -o DPkg::Options::=--force-overwrite-dir --trivial-only=no --assume-yes --quiet=1 install"
		) --autoremove --verbose-versions"

		UniventionInstallLock ${UniventionSystemInstallCommand} ${@}

		debug "${UniventionSystemInstallCommand} ${@}"
		while ! timeout ${timeout} ${UniventionSystemInstallCommand} ${@} | egrep --invert-match -- "^[WE]:"; do
			[[ ${counter} > ${repeat} ]] && echo "TIMEOUT(${UniventionSystemInstallCommand} ${@})" && return 1
			counter=$((${counter} + 1))
			sleep ${sleep}
		done

		UniventionInstallCleanUp
	}
}
#
function UniventionInstallNoRecommends() { # UniventionInstallNoRecommends: IN(${@})
	[[ "${#@}" -eq 0 || -z "${@}" ]] && return 1
	[[ "${#@}" -eq 0 || -z "${@}" ]] || {
		local timeout=600

		local counter=1
		local repeat=3
		local sleep=120

		local UniventionSystemInstallCommand="$(
			ucr get update/commands/install | egrep -- ^apt || printf "%s" "apt-get -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-overwrite -o DPkg::Options::=--force-overwrite-dir --trivial-only=no --assume-yes --quiet=1 install"
		) --no-install-recommends --verbose-versions"

		UniventionDistUpdate >/dev/null 2>&1
		UniventionInstallLock ${UniventionSystemInstallCommand} ${@}

		debug "${UniventionSystemInstallCommand} ${@}"
		while ! timeout ${timeout} ${UniventionSystemInstallCommand} ${@} | egrep --invert-match -- "^[WE]:"; do
			[[ ${counter} > ${repeat} ]] && echo "TIMEOUT(${UniventionSystemInstallCommand} ${@})" && return 1
			counter=$((${counter} + 1))
			sleep ${sleep}
		done

		apt-mark auto ${@}
		UniventionInstallCleanUp
	}
}
#
function UniventionDistUpdate() { # UniventionDistUpdate: void
	local timeout=1800

	local counter=1
	local repeat=6
	local sleep=30

	local UniventionSystemDistUpdateCommand=$(
		ucr get update/commands/update | egrep -- ^apt || printf "%s" "apt-get update"
	)

	egrep --quiet --recursive -- "Traceback|repository.online.true" /etc/apt/sources.* &&
		UniventionResetRepositoryOnline

	UniventionInstallLock ${UniventionSystemDistUpdateCommand}

	debug "${UniventionSystemDistUpdateCommand}"
	while ! timeout ${timeout} ${UniventionSystemDistUpdateCommand} | egrep --invert-match -- "^[WE]:"; do
		[[ ${counter} > ${repeat} ]] && echo "TIMEOUT(${UniventionSystemDistUpdateCommand})" && return 1
		counter=$((${counter} + 1))
		sleep ${sleep}
	done
}
#
function UniventionUpdate() { # UniventionUpdate: void
	UniventionDistUpdate
}
#
function UniventionDistUpgrade() { # UniventionDistUpgrade: void
	local timeout=3600

	local counter=1
	local repeat=3
	local sleep=120

	local UniventionSystemDistUpgradeCommand=$(
		ucr get update/commands/distupgrade | egrep -- ^apt || printf "%s" "apt-get -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-overwrite -o DPkg::Options::=--force-overwrite-dir --trivial-only=no --assume-yes --quiet=1 dist-upgrade"
	)

	UniventionInstallLock ${UniventionSystemDistUpgradeCommand}

	debug "${UniventionSystemDistUpgradeCommand}"
	while ! timeout ${timeout} ${UniventionSystemDistUpgradeCommand} 2>&1; do
		[[ ${counter} > ${repeat} ]] && echo "TIMEOUT(${UniventionSystemDistUpgradeCommand})" && return 1
		counter=$((${counter} + 1))
		sleep ${sleep}
	done
}
#
function UniventionResetRepositoryOnline() { # UniventionResetRepositoryOnline: void
	local timeout=45

	local counter=1
	local repeat=99
	local sleep=15

	local UniventionResetRepositoryOnlineCommand="univention-config-registry set repository/online"

	${UniventionResetRepositoryOnlineCommand}=false

	while egrep --quiet --recursive -- "Traceback|repository.online.true" /etc/apt/sources.*; do
		[[ ${counter} > ${repeat} ]] && echo "TIMEOUT(${UniventionResetRepositoryOnlineCommand})" && return 1
		counter=$((${counter} + 1))

		sleep ${sleep} && ${UniventionResetRepositoryOnlineCommand}=false
		timeout ${timeout} ${UniventionResetRepositoryOnlineCommand}=true

		find /etc/apt/sources.list.d -type f -name *.old -delete
	done

	rm --force --verbose /etc/apt/sources.list.d/*_commit_*
}
#
function UniventionCheckJoinStatus() { # UniventionCheckJoinStatus: void

	# get dcaccount or set Administrator as default
	local dcaccount=${dcuser:-Administrator}

	# set dcpwd as fallback ( Message:  Invalid credentials ... )
	local dcpwd=/dev/shm/univention-container-mode.dcpwd.credentials

	printf "%s" "${dcpass:-}" > \
		${dcpwd}

	univention-check-join-status 2>&1 | egrep --quiet -- "^Joined successfully" || {
		if [[ "$(ucr get server/role)" == "domaincontroller_master" ]]; then
			univention-run-join-scripts
		else
			univention-run-join-scripts \
				-dcaccount ${dcaccount} \
				-dcpwd <(printf "%s" "${dcpass:-}") ||
				univention-run-join-scripts \
					-dcaccount ${dcaccount} \
					-dcpwd ${dcpwd} || /bin/true
		fi
	}

	# cleanup
	rm --force ${dcpwd}
}
#
function UniventionContainerModeDockerfileInit() { # UniventionContainerModeDockerfileInit: void
	#
	# force disabling chfn and mandb
	#  Creating new user ... PAM: System error
	ln --symbolic --force /bin/true /bin/chfn
	ln --symbolic --force /bin/true /usr/bin/chfn
	ln --symbolic --force /bin/true /usr/local/bin/chfn
	#  Processing triggers for man-db ...
	ln --symbolic --force /bin/true /bin/mandb
	ln --symbolic --force /bin/true /usr/bin/mandb
	ln --symbolic --force /bin/true /usr/local/bin/mandb
	#
	# force cleanup target wants
	rm --force --verbose \
		/etc/rc*.d/* \
		/etc/systemd/system/*.wants/* \
		/lib/systemd/system/multi-user.target.wants/* \
		/lib/systemd/system/systemd-update-utmp* \
		/lib/systemd/system/local-fs.target.wants/* \
		/lib/systemd/system/sockets.target.wants/*udev* \
		/lib/systemd/system/sockets.target.wants/*initctl* \
		/lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup*
	#
	# fix missing multi-user target wants
	systemctl enable -- \
		univention-container-mode-environment.service \
		univention-container-mode-firstboot.service \
		univention-container-mode-recreate.service \
		univention-container-mode-storage.service \
		univention-container-mode-backup.service \
		univention-container-mode-joined.service \
		univention-container-mode-fixes.service \
		univention-container-mode-init.service
}
#
function UniventionContainerModeRestartCheck() { # UniventionContainerModeRestartCheck: void
	#
	# checking if the container needs to restart and prevent boot looping by cleanup the logfile(s)
	#  this is only happen if the system has to upgrade from an old container image
	#  be sure that univention-container-mode-recreate.service will start probely
	#
	egrep --quiet -- 'systemd' /proc/1/cmdline && {
		egrep --quiet --recursive -- '^Install.*systemd' /var/log/apt && {
			[[ -f /var/backups/univention-container-mode/restore ]] &&
				touch /var/univention-join/{joined,status}
			find /var/log/apt -type f -delete && UniventionContainerModeRestart
		}
		#
		systemctl daemon-reload && systemctl reset-failed || /bin/true
	}
}
#
function UniventionContainerModeRestart() { # UniventionContainerModeRestart: IN(wait [seconds])
	local wait=${1:-1}
	# restart by kill SIGRTMIN+3(37) PID(1)
	/bin/bash -c "sleep ${wait} && kill -s 37 1" &
}
#
function UniventionContainerModeSlimifyCheck() { # UniventionContainerModeSlimifyCheck: void
	test -f /etc/dpkg/dpkg.cfg.d/univention-container-mode
	return ${?}
}
#
function UniventionContainerModeSlimify() { # UniventionContainerModeSlimify: void
	UniventionContainerModeSlimifyCheck || return 0 && {
		find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' \
			-exec rm --recursive --force {} \;
		rm --recursive --force \
			/usr/share/groff \
			/usr/share/info \
			/usr/share/linda \
			/usr/share/lintian \
			/usr/share/man \
			/var/cache/man || /bin/true
		find /usr/share/doc -depth -type f ! -name copyright \
			-delete
		find /usr/share/doc -depth -empty \
			-delete
		find / -regex '^.*\(__pycache__\|\.py[co]\)$' \
			-delete
	}
}
#
function UniventionConfigRegistryUnSet() { # UniventionConfigRegistryUnSet: IN(${ucrremoves[@]})
	[[ "${#@}" -eq 0 || -z "${@}" ]] || {
		univention-config-registry unset ${@} 2>&1 || /bin/true
	}
}
#
function UniventionConfigRegistrySet() { # UniventionConfigRegistrySet: IN(${ucrchanges[@]})
	# ToDo: fix blank spaces in key/value
	[[ "${#@}" -eq 0 || -z "${@}" ]] || {
		univention-config-registry set ${@} 2>&1 || /bin/true
	}
}
#
function UniventionConfigCommit() { # UniventionConfigCommit: IN(${ucrcommit[@]})
	[[ "${#@}" -eq 0 ]] || {
		univention-config-registry commit ${@}
	}
}
#
## util(s) for container mode environment
