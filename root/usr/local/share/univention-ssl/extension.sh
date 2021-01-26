#!/bin/bash
#
# Univention Container Mode - extension.sh
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

## openssl host extensions for container mode environment
#
createHostExtensionsFile() {
	local fqdn=${1}
	local temp=$(mktemp)
	local ldap=$(ucr get ldap/master)

	cat <<EOF >${temp}
# generated with /usr/local/share/univention-ssl/extension.sh ( ucr get ssl/host/extensions )
#
# https://www.openssl.org/docs/manmaster/man5/x509v3_config.html
#
# use openssl x509v3 extensions
#  => subjectAltName
#  => authorityInfoAccess
#  => crlDistributionPoints
#
extensions = UniventionContainerMode

[ UniventionContainerMode ]

# ucs defaults
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always

# alternative name
subjectAltName = DNS:${fqdn%%.*}, DNS:${fqdn}

# root certificate
authorityInfoAccess = caIssuers;URI:http://${ldap:-$(hostname --long)}:80/ucs-root-ca.crt

# root certificate revocation list
crlDistributionPoints = URI:http://${ldap:-$(hostname --long)}:80/ucsCA.crl

#
# generated with /usr/local/share/univention-ssl/extension.sh ( ucr get ssl/host/extensions )
EOF

	echo ${temp}
}
#
## openssl host extensions for container mode environment
