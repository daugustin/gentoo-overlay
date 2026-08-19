# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Based on the ::guru ebuild, minus the test machinery: the suite needs
# dev-python/asgi-lifespan (not packaged outside ::guru) and the
# deprecated dev-python/httpx, and the sdist ships no tests anyway.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Server-Sent Events for Starlette and FastAPI"
HOMEPAGE="
	https://github.com/sysid/sse-starlette/
	https://pypi.org/project/sse-starlette/
"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=dev-python/anyio-4.7.0[${PYTHON_USEDEP}]
	>=dev-python/starlette-0.49.1[${PYTHON_USEDEP}]
"
