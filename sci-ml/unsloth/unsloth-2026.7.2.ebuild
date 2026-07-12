# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Fast LLM fine-tuning and RL with the Unsloth Studio web UI and CLI"
HOMEPAGE="
	https://unsloth.ai/
	https://github.com/unslothai/unsloth/
	https://pypi.org/project/unsloth/
"

# Apache-2.0 for the library/CLI, AGPL-3 for the Studio web UI (studio/).
LICENSE="Apache-2.0 AGPL-3+"
SLOT="0"
KEYWORDS="~amd64"

# The bundled test suite needs the heavy ML stack that is deliberately not
# packaged here (torch, transformers, trl, ...) plus network access to
# Hugging Face, so it cannot run in the sandbox.
RESTRICT="test"

# This package is deliberately thin: the `unsloth` CLI, the Studio backend
# sources and the pre-built web frontend. The PyPI sdist ships the frontend
# already built (studio/frontend/dist), so no npm/node at build time. The
# heavy ML stack (PyTorch, triton, bitsandbytes, transformers, ... with very
# tight upstream pins that the ::gentoo sci-ml versions cannot satisfy) is
# NOT packaged; upstream's installer provisions it into a per-user venv under
# ~/.unsloth instead -- see pkg_postinst. dev-python/uv and net-misc/curl are
# what that installer expects from the system (it would otherwise download
# its own uv binary).
RDEPEND="
	dev-python/nest-asyncio[${PYTHON_USEDEP}]
	dev-python/pydantic[${PYTHON_USEDEP}]
	dev-python/pyyaml[${PYTHON_USEDEP}]
	dev-python/rich[${PYTHON_USEDEP}]
	dev-python/typer[${PYTHON_USEDEP}]
	dev-python/uv
	net-misc/curl
"

python_install_all() {
	distutils-r1_python_install_all

	# Upstream's first-time installer: creates ~/.unsloth/studio/unsloth_studio
	# with a GPU-matched PyTorch stack plus node and llama.cpp prebuilts, then
	# runs the in-package studio/setup.sh. Invoked via the unsloth-setup
	# wrapper (bash /usr/share/unsloth/install.sh), so no +x needed here.
	insinto /usr/share/${PN}
	doins install.sh
	newbin "${FILESDIR}"/unsloth-setup unsloth-setup
}

pkg_postinst() {
	elog "This package installs the 'unsloth' CLI and the Unsloth Studio web UI"
	elog "(backend + pre-built frontend). The heavy ML stack (PyTorch, triton,"
	elog "bitsandbytes, pinned transformers/trl, llama.cpp) is NOT part of this"
	elog "package -- upstream provisions it into a per-user environment."
	elog
	elog "First-time setup (as your regular user, NOT root):"
	elog "  unsloth-setup"
	elog "This downloads several GB into ~/.unsloth (GPU-matched PyTorch,"
	elog "llama.cpp and node prebuilts) and may take a while."
	elog
	elog "Then start the web UI with:"
	elog "  unsloth studio"
	elog "It binds http://127.0.0.1:8888 by default (-p/--port, -H/--host)."
	elog
	elog "After upgrading this package, re-run 'unsloth-setup' to bring the"
	elog "~/.unsloth environment in sync. Uninstalling the package does not"
	elog "remove ~/.unsloth; delete it manually if no longer wanted."
}
