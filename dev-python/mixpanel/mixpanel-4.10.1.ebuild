# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# 4.10.1 is the last 4.x release; comfy-cli pins mixpanel<5.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Official Mixpanel analytics library for Python"
HOMEPAGE="
	https://github.com/mixpanel/mixpanel-python
	https://pypi.org/project/mixpanel/
"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=dev-python/six-1.9.0[${PYTHON_USEDEP}]
	>=dev-python/requests-2.4.2[${PYTHON_USEDEP}]
	dev-python/urllib3[${PYTHON_USEDEP}]
"

distutils_enable_tests pytest
