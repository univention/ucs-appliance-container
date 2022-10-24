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
			ucr get update/commands/install | egrep -- ^apt || echo -n "apt-get -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-overwrite -o DPkg::Options::=--force-overwrite-dir --trivial-only=no --assume-yes --quiet=1 install"
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
			ucr get update/commands/install | egrep -- ^apt || echo -n "apt-get -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-overwrite -o DPkg::Options::=--force-overwrite-dir --trivial-only=no --assume-yes --quiet=1 install"
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
		ucr get update/commands/update | egrep -- ^apt || echo -n "apt-get update"
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
		ucr get update/commands/distupgrade | egrep -- ^apt || echo -n "apt-get -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-overwrite -o DPkg::Options::=--force-overwrite-dir --trivial-only=no --assume-yes --quiet=1 dist-upgrade"
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

	while timeout ${timeout} ${UniventionResetRepositoryOnlineCommand}=true &&
		egrep --quiet --recursive -- "Traceback|repository.online.true" /etc/apt/sources.*; do
		[[ ${counter} > ${repeat} ]] && echo "TIMEOUT(${UniventionResetRepositoryOnlineCommand})" && return 1
		counter=$((${counter} + 1))
		sleep ${sleep} && ${UniventionResetRepositoryOnlineCommand}=false
	done

	rm --force --verbose /etc/apt/sources.*/*.old
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
