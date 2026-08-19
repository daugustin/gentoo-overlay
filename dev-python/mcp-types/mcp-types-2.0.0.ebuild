# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=hatchling
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Model Context Protocol wire types"
HOMEPAGE="
	https://modelcontextprotocol.io/
	https://github.com/modelcontextprotocol/python-sdk
	https://pypi.org/project/mcp-types/
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=dev-python/pydantic-2.12.0[${PYTHON_USEDEP}]
	>=dev-python/typing-extensions-4.13.0[${PYTHON_USEDEP}]
"
BDEPEND="
	dev-python/uv-dynamic-versioning[${PYTHON_USEDEP}]
"

# No tests: the PyPI sdist ships only the package; the test suite lives
# in the python-sdk monorepo and is exercised by dev-python/mcp upstream.

python_compile() {
	# uv-dynamic-versioning derives the version from git; the sdist has
	# no repo, so hand it the release version instead.
	local -x UV_DYNAMIC_VERSIONING_BYPASS=${PV}
	distutils-r1_python_compile
}
