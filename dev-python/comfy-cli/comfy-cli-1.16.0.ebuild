# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# NOTE: SRC_URI must be the PyPI sdist (pypi.eclass default). The git
# repo carries version "0.0.0" which is only injected at publish time,
# so a GitHub tag tarball would build with a bogus version.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="CLI tool for installing and managing ComfyUI"
HOMEPAGE="
	https://github.com/Comfy-Org/comfy-cli
	https://pypi.org/project/comfy-cli/
"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# - mixpanel is pinned <5 upstream (5.x pulls pydantic; upstream avoids
#   it for a Windows DLL issue). Package 4.10.1, the last 4.x.
# - uv and ruff are genuine runtime deps: comfy-cli shells out to both
#   binaries (uv for its DependencyCompiler, ruff to format generated
#   code). dev-python/uv and dev-util/ruff provide the executables. If
#   a future version queries their pip dist-info via importlib.metadata
#   this will need revisiting.
RDEPEND="
	>=dev-python/charset-normalizer-3[${PYTHON_USEDEP}]
	dev-python/cookiecutter[${PYTHON_USEDEP}]
	>=dev-python/gitpython-3.1.50[${PYTHON_USEDEP}]
	dev-python/httpx[${PYTHON_USEDEP}]
	<dev-python/mixpanel-5[${PYTHON_USEDEP}]
	dev-python/packaging[${PYTHON_USEDEP}]
	dev-python/pathspec[${PYTHON_USEDEP}]
	>=dev-python/posthog-6[${PYTHON_USEDEP}]
	<dev-python/posthog-8[${PYTHON_USEDEP}]
	>=dev-python/psutil-6[${PYTHON_USEDEP}]
	dev-python/pyyaml[${PYTHON_USEDEP}]
	dev-python/questionary[${PYTHON_USEDEP}]
	dev-python/requests[${PYTHON_USEDEP}]
	dev-python/rich[${PYTHON_USEDEP}]
	>=dev-python/semver-3.0.2[${PYTHON_USEDEP}]
	>=dev-python/tomlkit-0.13[${PYTHON_USEDEP}]
	<dev-python/tomlkit-0.16[${PYTHON_USEDEP}]
	>=dev-python/typer-0.12.5[${PYTHON_USEDEP}]
	>=dev-python/typing-extensions-4.7[${PYTHON_USEDEP}]
	>=dev-python/uv-0.11.15
	dev-python/websocket-client[${PYTHON_USEDEP}]
	dev-util/ruff
"

# Test suite exists (pytest) but several tests hit the network / git;
# deselect as needed once you run FEATURES=test.
distutils_enable_tests pytest

pkg_postinst() {
	elog "comfy-cli sends anonymous usage analytics (mixpanel/posthog)."
	elog "Disable with:  comfy tracking disable"
	elog ""
	elog "Point it at an existing ComfyUI checkout with:"
	elog "  comfy set-default /path/to/ComfyUI"
}
