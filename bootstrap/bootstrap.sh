#!/bin/bash
#
# Univention Container Mode - bootstrap script
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

# ToDo
# - Fix --platform for multi-platform server on import
# - switch to GitHub API
#  => curl --silent --header "Accept: application/vnd.github.v3+json" https://api.github.com/repos/univention/univention-corporate-server/tags | jq -r .[].name
#  => curl --silent --header "Accept: application/vnd.github.v3+json" https://api.github.com/repos/univention/univention-corporate-server/tags | jq -r .[0].name | tr --complement --delete '[:digit:]'
# - Fix missing usr-is-merged
#  => I: Checking component main on https://updates.software-univention.de/...
#  => E: Couldn't find these debs: usr-is-merged
# patch /usr/share/debootstrap/scripts/debian-common <<EOF
# @@ -48,7 +48,7 @@
#  	# we can install the empty 'usr-is-merged' metapackage to indicate
#  	# that the transition has been done.
#  	case "\$CODENAME" in
# -		etch*|lenny|squeeze|wheezy|jessie*|stretch|buster|bullseye)
# +		etch*|lenny|squeeze|wheezy|jessie*|stretch|buster|bullseye|ucs*)
#  			;;
#  		*)
#  			required="\$required usr-is-merged"
# EOF

## CHECK FOR ROOT USER
[[ ${LOGNAME} == root ]] || {
	echo -e "NOTE: root user is needed!\nUSE: $0 with sudo\n\tsudo /bin/bash $0 $@"
	exit 1
}

## FUNCTION(S)
function getPath() {
	echo "$(which ${1} 2>/dev/null | awk '/^\/.*'${1}'$/ {printf "%s", $0}' | head -n 1)"
}
function missing() {
	echo -e "ERROR: missing ${1} ... fix this by install!"
	which apt >/dev/null 2>&1 &&
		echo -e "INSTALL:\n\tapt install ${1}"
	which yum >/dev/null 2>&1 &&
		echo -e "INSTALL:\n\tyum install ${1}"
	exit 1
}
function keyrings() {
	find /usr/share/${1} -type f -exec cat {} \; |
		awk '/^keyring.*\.gpg$/{ print $2 }' | sort | uniq |
		awk '!/tanglu-archive-keyring.gpg/{ print "test -f " $1 " || echo \"INFO: KEYRING(" $0 ") NOT FOUD ON SYSTEM ...\" "}' |
		bash -
}

## SET DOCKER OR PODMAN PATH
docker=$(which docker podman 2>/dev/null | awk '/^\/.*(docker|podman)$/{printf "%s", $0}' | head -n 1 || /bin/true)
[[ -z ${docker} ]] && {
	echo -e "ERROR: missing docker or podman ... fix this by install!"
	echo -e "INFO:\n\thttps://docs.docker.com/engine/install/\n\thttps://podman.io/getting-started/installation.html"
	exit 1
}

## SET ARCH ( OR ARCH-TEST PATH )
arch=$(getPath arch-test)
[[ -z ${arch} ]] &&
	arch=$(uname --machine | awk '/^i(3|4|5|6)86$/{ print "i386" } /^x86_64$/{ print "amd64" }')

## SET CURL PATH
curl=$(getPath curl)
[[ -z ${curl} ]] &&
	missing curl

## SET CURL DEFAULT OPTION(S)
[[ -z ${curl} ]] ||
	curl="${curl} --fail --silent"

## SET GPG PATH
gpg=$(getPath gpg)
[[ -z ${gpg} ]] &&
	missing gpg

## SET GPG DEFAULT OPTION(S)
[[ -z ${gpg} ]] ||
	gpg="${gpg} --batch --no-default-keyring"

## SET JQ PATH
jq=$(getPath jq)
[[ -z ${jq} ]] &&
	missing jq

## SET JQ DEFAULT OPTION(S)
[[ -z ${jq} ]] ||
	jq="${jq} --raw-output"

## GET PLATFORM FROM KERNEL
PLATFORM=$(uname --kernel-name | awk '{print tolower($0)}')

## CHECK JSON CONFIG FILE
[[ -f $0.json ]] || {
	echo "JSON CONFIG FILE($0.json) MISSING ..."
	exit 1
}

## SET JSON CONFIG FILE
JSON=$0.json

## SET BASH DEFAULT VALUE(S)
ARTIFACTS=FALSE
DRY_RUN=FALSE
CACHING=FALSE
SLIMIFY=FALSE

## CHECK OPTION(S)
[[ ${#@} == 0 ]] && {
	echo "USE: /bin/bash $0 --help"
	exit 1
}

## SET OPTION(S)
while (("${#@}")); do
	case ${1} in
	--get-artifacts) {
		ARTIFACTS=TRUE
	} ;;
	--all-distributions) {
		shift
	} ;;
	--distribution) {
		shift && {
			for strap in debootstrap febootstrap; do
				[[ $(${jq} .${PLATFORM}.${strap}.dir ${JSON}) == null ]] || {
					bootstrap=$(getPath ${strap}) # SET (D|F)EBOOTSTRAP PATH
					[[ -z ${bootstrap} ]] && missing ${strap} && keyrings ${strap} || {
						for distribution in $(${jq} .${PLATFORM}.${strap}.distributions[].name ${JSON}); do
							[[ "${1}" == "${distribution}" ]] && DistName="${1}"
						done
					}
				}
			done
			[[ -z ${DistName} ]] && {
				echo -e \
					"ERROR: --distribution ${1} not found\
					\n\tTRY /bin/bash ${0} --list-distribution\
					\n\t OR /bin/bash ${0} --all-distribution"
				exit 1
			}
		}
	} ;;
	--list-distributions) {
		for strap in debootstrap febootstrap; do
			[[ $(${jq} .${PLATFORM}.${strap}.dir ${JSON}) == null ]] || {
				bootstrap=$(getPath ${strap}) # SET (D|F)EBOOTSTRAP PATH
				[[ -z ${bootstrap} ]] && missing ${strap} && keyrings ${strap} || {
					for distribution in $(${jq} .${PLATFORM}.${strap}.distributions[].name ${JSON}); do
						echo -e \
							"distribution: $(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".url.distribution ${JSON})\
								\n\t/bin/bash $0 --distribution ${distribution}"
					done
				}
			}
		done
		exit 0
	} ;;
	--all-codenames) {
		shift
	} ;;
	--codename) {
		shift && {
			for strap in debootstrap febootstrap; do
				[[ $(${jq} .${PLATFORM}.${strap}.dir ${JSON}) == null ]] || {
					bootstrap=$(getPath ${strap}) # SET (D|F)EBOOTSTRAP PATH
					[[ -z ${bootstrap} ]] && missing ${strap} && keyrings ${strap} || {
						for distribution in $(${jq} .${PLATFORM}.${strap}.distributions[].name ${JSON}); do
							for codename in $(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames[].name ${JSON}); do
								[[ "${1}" == "${codename}" ]] && CodeName="${1}"
							done
						done
					}
				}
			done
			[[ -z ${CodeName} ]] && {
				echo -e \
					"ERROR: --codename ${1} not found\
					\n\tTRY /bin/bash ${0} --list-codenames\
					\n\t OR /bin/bash ${0} --all-codenames"
				exit 1
			}
		}
	} ;;
	--list-codenames) {
		for strap in debootstrap febootstrap; do
			[[ $(${jq} .${PLATFORM}.${strap}.dir ${JSON}) == null ]] || {
				bootstrap=$(getPath ${strap}) # SET (D|F)EBOOTSTRAP PATH
				[[ -z ${bootstrap} ]] && missing ${strap} && keyrings ${strap} || {
					for distribution in $(${jq} .${PLATFORM}.${strap}.distributions[].name ${JSON}); do
						for codename in $(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames[].name ${JSON}); do
							echo -e \
								"\t/bin/bash $0 --distribution ${distribution} --codename ${codename}"
						done
					done
				}
			}
		done
		exit 0
	} ;;
	--arch) {
		shift && {
			[[ -f ${arch} ]] || {
				echo \
					${arch} | egrep --quiet "^${1}$" && arch=${1} || /bin/true
			}
			[[ -f ${arch} ]] && {
				test -x \
					${arch} &&
					${arch} | egrep --quiet "^${1}$" && arch=${1} || /bin/true
			}
		}
	} ;;
	--use-cache) {
		CACHING=TRUE
	} ;;
	--slimify) {
		SLIMIFY=TRUE
	} ;;
	--dry-run) {
		DRY_RUN=TRUE
	} ;;
	--debug) {
		DEBUG=TRUE
	} ;;
	--help | *) {
		echo "USE: /bin/bash $0 --help"
		echo ""
		echo "ARG: /bin/bash $0 --all-distributions [--arch <arch> [--use-cache [ --get-artifacts [ --dry-run [--debug]]]]]]"
		echo ""
		echo "ARG: /bin/bash $0 --distribution <distribution> [ --codename <codename> [--arch <arch> [--use-cache [ --get-artifacts [ --dry-run [--debug]]]]]]]"
		echo ""
		echo "ARG: /bin/bash $0 --list-distributions"
		echo "ARG: /bin/bash $0 --list-codenames"
		echo ""
		echo "ARG: /bin/bash $0 --get-artifacts"
		echo ""
		echo "ARG: /bin/bash $0 --use-cache"
		echo ""
		echo "ARG: /bin/bash $0 --slimify"
		echo ""
		echo "ARG: /bin/bash $0 --dry-run"
		echo "ARG: /bin/bash $0 --debug"
		exit 0
	} ;;
	esac
	shift
done

[[ ${DEBUG:-} =~ ^1|yes|true|YES|TRUE$ ]] && {
	set -o xtrace
	set -o errexit
	set -o errtrace
	set -o nounset
	set -o pipefail
}

[[ ${SLIMIFY:-} =~ ^1|yes|true|YES|TRUE$ ]] && SLIM="-slim" || SLIM=""

for strap in debootstrap febootstrap; do
	[[ $(${jq} .${PLATFORM}.${strap}.dir ${JSON}) == null ]] || {
		bootstrap=$(getPath ${strap}) # SET (D|F)EBOOTSTRAP PATH
		[[ -z ${bootstrap} ]] && missing ${strap} && keyrings ${strap} || {
			DIR=$(${jq} .${PLATFORM}.${strap}.dir ${JSON})/${PLATFORM}

			for distribution in $(${jq} .${PLATFORM}.${strap}.distributions[].name ${JSON}); do
				[[ ${#DistName} != 0 ]] && [[ "${DistName}" != "${distribution}" ]] && continue
				for codename in $(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames[].name ${JSON}); do
					[[ ${#CodeName} != 0 ]] && [[ "${CodeName}" != "${codename}" ]] && continue

					OPTION=""
					SUITE=${codename}
					TARGET=""
					MIRROR=$(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".mirror ${JSON})
					SCRIPT=""
					KEYRING=""

					for option in $(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".options[] ${JSON}); do
						OPTION="${OPTION} --${option}"
					done

					INCLUDE=""
					EXCLUDE=""

					for package in \
						$(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".packages.include[] ${JSON}) \
						$(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".packages.default[] ${JSON}); do
						INCLUDE="${INCLUDE},${package}"
					done
					for package in \
						$(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".packages.exclude[] ${JSON}); do
						EXCLUDE="${EXCLUDE},${package}"
					done

					[[ -z ${INCLUDE} ]] || INCLUDE=$(echo ${INCLUDE} | sed 's/^,/ --include /g')
					[[ -z ${EXCLUDE} ]] || EXCLUDE=$(echo ${EXCLUDE} | sed 's/^,/ --exclude /g')

					OPTION="${OPTION}${INCLUDE}${EXCLUDE}"

					VARIANT=$(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".packages.variant ${JSON} | awk '!/null/{ print " --variant " $0 }')

					OPTION="${OPTION}${VARIANT}"

					case ${distribution} in
					univention-corporate-server*) {
						[[ $(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".gpg.key.hash ${JSON}) == null ]] || {
							HASH=$(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".gpg.key.hash ${JSON})
							FILE=$(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".gpg.key.file ${JSON})
							HTTP=$(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".gpg.key.http ${JSON})

							case ${codename} in
							*) SCRIPT=/usr/share/debootstrap/scripts/stable ;;
							esac

							MAJOR=$(echo ${codename} | tr --complement --delete '[:digit:]' | awk NF=NF FS= | awk '{ print $1 }')
							MINOR=$(echo ${codename} | tr --complement --delete '[:digit:]' | awk NF=NF FS= | awk '{ print $2 }')
							PATCH=$(echo ${codename} | tr --complement --delete '[:digit:]' | awk NF=NF FS= | awk '{ print $3 }')

							VERSION=${MAJOR}.${MINOR}-${PATCH}

							KEYRING="${DIR}/${distribution}/${HASH}.gpg"
							mkdir --parents $(dirname ${KEYRING}) && {
								[[ -f ${FILE} ]] && KEYRING=${FILE}
								[[ -f ${FILE} ]] || {
									CURL="${curl} --location ${HTTP} --output ${KEYRING}"
									GPG="${CURL} || ${gpg} --keyring ${KEYRING} --recv-key ${HASH} > /dev/null 2>&1"
									[[ ${DRY_RUN-} =~ ^1|yes|true|YES|TRUE$ ]] && echo ${GPG}
									[[ ${DRY_RUN-} =~ ^1|yes|true|YES|TRUE$ ]] || echo ${GPG} | bash -
								}
							}

							OPTION="${OPTION} --keyring ${KEYRING}"
							[[ "${MAJOR}" -ge "5" ]] || MIRROR="${MIRROR}/${MAJOR}.${MINOR}/maintained/${MAJOR}.${MINOR}-${PATCH}"
						}
					} ;;
					*) {
						OPTION="${OPTION}"
					} ;;
					esac

					BootStrapOptions="${OPTION}"
					for ARCH in $(
						test -x ${arch} && ${arch} || echo ${arch}
					); do
						${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".arch[] ${JSON} | egrep --quiet ${ARCH} ||
							echo "INFO: Skipping non-supported architecture ${ARCH} ..."
						${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".arch[] ${JSON} | egrep --quiet ${ARCH} && {
							OPTION="${BootStrapOptions} --arch ${ARCH}"

							CACHED=${DIR}/${distribution}/cached
							TARGET=${DIR}/${distribution}/${ARCH}/${codename}

							ARTIFACT=${DIR}/${distribution}.tar

							[[ ${VERSION-} =~ ^$ ]] && VERSION=${codename}

							[[ ${docker} =~ podman$ ]] &&
								IMAGE=localhost/${distribution/-test/}-$(basename ${bootstrap}) || IMAGE=${distribution/-test/}-$(basename ${bootstrap})

							TAG=$(${jq} .${PLATFORM}.${strap}.distributions."\"${distribution}\"".codenames."\"${codename}\"".tag ${JSON})

							[[ ${TAG} =~ ^test$ ]] && VERSION=${VERSION}-${TAG}

							[[ ${CACHING-} =~ ^1|yes|true|YES|TRUE$ ]] && {
								${bootstrap} --help | egrep --quiet -- "--cache-dir" && {
									mkdir --parents ${CACHED} && OPTION="${OPTION} --cache-dir ${CACHED}"
								}
							}

							rm --recursive --force ${TARGET}
							mkdir --parents ${TARGET} && {
								BOOTSTRAP="${bootstrap} ${OPTION} ${SUITE} ${TARGET} ${MIRROR} ${SCRIPT}"
								[[ ${DRY_RUN-} =~ ^1|yes|true|YES|TRUE$ ]] && echo ${BOOTSTRAP}
								[[ ${DRY_RUN-} =~ ^1|yes|true|YES|TRUE$ ]] || echo ${BOOTSTRAP} | bash -
								[[ ${DRY_RUN-} =~ ^1|yes|true|YES|TRUE$ ]] && {
									echo ${docker} import --message "${BOOTSTRAP}" - ${IMAGE}:${VERSION}
								}

								[[ -d ${TARGET}/dev ]] && {
									[[ -d ${TARGET}/var/lib/apt/lists ]] &&
										rm --recursive --force \
											${TARGET}/var/lib/apt/lists/*

									[[ -d ${TARGET}/var/cache/apt ]] &&
										rm --force \
											${TARGET}/var/cache/apt/archives/*.deb \
											${TARGET}/var/cache/apt/archives/partial/*.deb \
											${TARGET}/var/cache/apt/*.bin

									[[ -d ${TARGET}/var/cache/debconf ]] &&
										rm --force \
											${TARGET}/var/cache/debconf/*old

									[[ -d ${TARGET}/var/log ]] &&
										rm --force \
											${TARGET}/var/log/*/* \
											${TARGET}/var/log/* >/dev/null 2>&1 || /bin/true

									[[ -d ${TARGET}/lib/modules ]] &&
										rm --recursive --force \
											${TARGET}/lib/modules/*

									[[ -d ${TARGET}/boot ]] &&
										rm --force \
											${TARGET}/boot/* >/dev/null 2>&1 || /bin/true

									for name in "initrd.img" "vmlinuz" "install"; do
										find ${TARGET} -maxdepth 1 -type l -name "*${name}*" -exec rm --force {} \;
									done

									[[ ${SLIMIFY-} =~ ^1|yes|true|YES|TRUE$ ]] && {
										find ${TARGET}/usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' \
											-exec rm --recursive --force {} \;

										echo -e "path-exclude /usr/share/locale/*\npath-include /usr/share/locale/en*" > \
											${TARGET}/etc/dpkg/dpkg.cfg.d/univention-container-mode
										echo -e "force-unsafe-io" > \
											${TARGET}/etc/dpkg/dpkg.cfg.d/univention-container-mode-apt-speedup

										rm --recursive --force \
											${TARGET}/usr/share/groff \
											${TARGET}/usr/share/info \
											${TARGET}/usr/share/linda \
											${TARGET}/usr/share/lintian \
											${TARGET}/usr/share/man \
											${TARGET}/var/cache/man || /bin/true
										find ${TARGET}/usr/share/doc -depth -type f ! -name copyright \
											-delete
										find ${TARGET}/usr/share/doc -depth -empty \
											-delete
										find ${TARGET} -regex '^.*\(__pycache__\|\.py[co]\)$' \
											-delete
									}

									case ${SUITE} in
									ucs5*) {
										echo -e "deb [arch=${ARCH}] ${MIRROR} ${SUITE} main\ndeb [arch=${ARCH}] ${MIRROR} ${SUITE/ucs/errata} main" > \
											${TARGET}/etc/apt/sources.list
									} ;;
									*) {
										echo -e "deb [arch=${ARCH}] ${MIRROR} ${SUITE} main" > \
											${TARGET}/etc/apt/sources.list
									} ;;
									esac

									tar --create --overwrite --directory=${TARGET} --file=${ARTIFACT} .

									${docker} import --help | egrep --quiet -- "--platform" &&
										${docker} import --message "${BOOTSTRAP}" --platform "${PLATFORM}/${ARCH}" ${ARTIFACT} ${IMAGE}:${VERSION}${SLIM} ||
										${docker} import --message "${BOOTSTRAP}" ${ARTIFACT} ${IMAGE}:${VERSION}${SLIM}

									[[ ${TAG} =~ ^latest|test$ ]] && {
										${docker} image tag ${IMAGE}:${VERSION}${SLIM} ${IMAGE}:${TAG}${SLIM}

										[[ ${docker} =~ podman$ ]] && {
											echo
											echo sudo ${docker} import --message \"${BOOTSTRAP}\" ${ARTIFACT} ${IMAGE}:${VERSION}${SLIM}
											echo
											echo sudo ${docker} image tag ${IMAGE}:${VERSION}${SLIM} ${IMAGE}:${TAG}${SLIM}
										}

									}

									[[ ${ARTIFACTS-} =~ ^1|yes|true|YES|TRUE$ ]] && {
										tar --create --overwrite --directory=${TARGET} --file=${ARTIFACT}.xz --xz .
										tar --create --overwrite --directory=${TARGET} --file=${ARTIFACT}.gz --gzip .

										echo && ls -lah ${ARTIFACT}*
									}
								}
							}
						}
					done
				done
			done
		}
	}
done
