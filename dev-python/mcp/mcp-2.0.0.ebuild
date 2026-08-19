# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# NOTE: 2.0.0 is a breaking upstream release: mcp.server.fastmcp is gone
# (replaced by mcp.server.mcpserver), the wire types moved into the
# mcp-types dist (exact ==${PV} pin upstream), and httpx was swapped for
# the pydantic fork httpx2. ::guru carries 1.28.1 for consumers that
# still need the 1.x API (e.g. dev-python/fastmcp).

EAPI=8

DISTUTILS_USE_PEP517=hatchling
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 optfeature pypi

DESCRIPTION="Model Context Protocol SDK"
HOMEPAGE="
	https://modelcontextprotocol.io/
	https://github.com/modelcontextprotocol/python-sdk
	https://pypi.org/project/mcp/
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

# - cryptography via pyjwt[crypto]
# - typer + python-dotenv are the [cli] extra, kept unconditional because
#   the mcp console script is installed unconditionally and imports them
RDEPEND="
	>=dev-python/anyio-4.10[${PYTHON_USEDEP}]
	>=dev-python/cryptography-3.4.0[${PYTHON_USEDEP}]
	>=dev-python/httpx2-2.5.0[${PYTHON_USEDEP}]
	>=dev-python/jsonschema-4.20.0[${PYTHON_USEDEP}]
	~dev-python/mcp-types-2.0.0[${PYTHON_USEDEP}]
	>=dev-python/opentelemetry-api-1.28.0[${PYTHON_USEDEP}]
	>=dev-python/pydantic-2.12.0[${PYTHON_USEDEP}]
	>=dev-python/pyjwt-2.10.1[${PYTHON_USEDEP}]
	>=dev-python/python-dotenv-1.0.0[${PYTHON_USEDEP}]
	>=dev-python/python-multipart-0.0.9[${PYTHON_USEDEP}]
	>=dev-python/sse-starlette-3.0.0[${PYTHON_USEDEP}]
	>=dev-python/starlette-0.48.0[${PYTHON_USEDEP}]
	>=dev-python/typer-0.16.0[${PYTHON_USEDEP}]
	>=dev-python/typing-extensions-4.13.0[${PYTHON_USEDEP}]
	>=dev-python/typing-inspection-0.4.1[${PYTHON_USEDEP}]
	>=dev-python/uvicorn-0.31.1[${PYTHON_USEDEP}]
"
BDEPEND="
	dev-python/uv-dynamic-versioning[${PYTHON_USEDEP}]
"

# Tests not enabled: tests/conftest.py unconditionally imports logfire,
# and the dev group also needs pytest-examples and strict-no-cover --
# none of which are packaged.

python_compile() {
	# uv-dynamic-versioning derives the version (and the templated
	# dependency metadata) from git; the sdist has no repo, so hand it
	# the release version instead.
	local -x UV_DYNAMIC_VERSIONING_BYPASS=${PV}
	distutils-r1_python_compile
}

pkg_postinst() {
	optfeature "rich console output" dev-python/rich
}
