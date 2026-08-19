# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="MCP server for ComfyUI, a thin wrapper over comfy-cli"
HOMEPAGE="
	https://github.com/Comfy-Org/comfy-mcp
	https://pypi.org/project/comfy-mcp/
"

# Dual-licensed: AGPL-3.0-or-later OR a commercial license from
# licensing@comfy.org; we distribute under the AGPL side.
LICENSE="AGPL-3+"
SLOT="0"
KEYWORDS="~amd64"

# comfy-cli is deliberately NOT a pip dependency upstream: the server
# shells out to the `comfy` binary (PATH or COMFY_BIN) and asserts its
# envelope schema major at runtime instead of pinning a dist. On Gentoo
# that binary is dev-python/comfy-cli, dep'd without PYTHON_USEDEP since
# it is a subprocess contract, not an import.
RDEPEND="
	>=dev-python/anyio-4.9[${PYTHON_USEDEP}]
	>=dev-python/mcp-2[${PYTHON_USEDEP}]
	<dev-python/mcp-3[${PYTHON_USEDEP}]
	>=dev-python/pydantic-2[${PYTHON_USEDEP}]
	dev-python/comfy-cli
"

# Plain pytest runs only the unit suite: pyproject addopts deselect the
# e2e (live ComfyUI) and cli_contract (real comfy binary) markers.
EPYTEST_PLUGINS=()
distutils_enable_tests pytest

pkg_postinst() {
	elog "Register the server with your MCP client, e.g. for Claude Code:"
	elog "  claude mcp add comfy -- comfy-mcp"
	elog ""
	elog "It drives the comfy-cli binary; point COMFY_BIN at a different"
	elog "comfy executable if the one on PATH is not the right one."
}
