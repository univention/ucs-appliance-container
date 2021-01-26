#!/bin/bash
#
# Univention Container Mode - utils
#
# Copyright YYYY-YYYY Univention GmbH
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
		local timeout=1800

		local counter=1
		local repeat=3
		local sleep=120

		local UniventionAddAppCommand="univention-add-app --all"

		debug "${UniventionAddAppCommand} ${@}"
		while ! timeout ${timeout} ${UniventionAddAppCommand} ${@}; do
			[[ ${counter} > ${repeat} ]] && echo "%s" "\nTIMEOUT(${UniventionAddAppCommand} ${@})" && return 1
			counter=$((${counter} + 1))
			sleep ${sleep}
		done
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

		local UniventionSystemInstallCommand="$(ucr get update/commands/install) --autoremove --verbose-versions"

		UniventionInstallLock ${UniventionSystemInstallCommand} ${@}

		debug "${UniventionSystemInstallCommand} ${@}"
		while ! timeout ${timeout} ${UniventionSystemInstallCommand} ${@} | egrep --invert-match "^[WE]:"; do
			[[ ${counter} > ${repeat} ]] && echo "%s" "\nTIMEOUT(${UniventionSystemInstallCommand} ${@})" && return 1
			counter=$((${counter} + 1))
			sleep ${sleep}
		done
	}
}
#
function UniventionDistUpdate() { # UniventionDistUpdate: void
	local timeout=1800

	local counter=1
	local repeat=6
	local sleep=30

	local UniventionSystemDistUpdateCommand=$(ucr get update/commands/update)

	UniventionInstallLock ${UniventionSystemDistUpdateCommand}

	debug "${UniventionSystemDistUpdateCommand}"
	while ! timeout ${timeout} ${UniventionSystemDistUpdateCommand} | egrep --invert-match "^[WE]:"; do
		[[ ${counter} > ${repeat} ]] && echo "%s" "\nTIMEOUT(${UniventionSystemDistUpdateCommand})" && return 1
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

	local UniventionSystemDistUpgradeCommand=$(ucr get update/commands/distupgrade)

	UniventionInstallLock ${UniventionSystemDistUpgradeCommand}

	debug "${UniventionSystemDistUpgradeCommand}"
	while ! timeout ${timeout} ${UniventionSystemDistUpgradeCommand} 2>&1; do
		[[ ${counter} > ${repeat} ]] && echo "%s" "\nTIMEOUT(${UniventionSystemDistUpgradeCommand})" && return 1
		counter=$((${counter} + 1))
		sleep ${sleep}
	done
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
