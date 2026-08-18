# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Command-line utility that creates projects from project templates"
HOMEPAGE="
	https://github.com/cookiecutter/cookiecutter
	https://pypi.org/project/cookiecutter/
"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=dev-python/binaryornot-0.4.4[${PYTHON_USEDEP}]
	>=dev-python/jinja2-2.7[${PYTHON_USEDEP}]
	<dev-python/jinja2-4[${PYTHON_USEDEP}]
	>=dev-python/click-7.0[${PYTHON_USEDEP}]
	<dev-python/click-9.0[${PYTHON_USEDEP}]
	>=dev-python/pyyaml-5.3.1[${PYTHON_USEDEP}]
	>=dev-python/python-slugify-4.0.0[${PYTHON_USEDEP}]
	>=dev-python/requests-2.23.0[${PYTHON_USEDEP}]
	dev-python/arrow[${PYTHON_USEDEP}]
	dev-python/rich[${PYTHON_USEDEP}]
"

# Tests clone template repos from the network.
distutils_enable_tests pytest

src_prepare() {
	distutils-r1_src_prepare

	# the sdist ships neither a [build-system] table nor a setup.py,
	# leaving the eclass unable to determine the build backend
	cat >> pyproject.toml <<-EOF || die
		[build-system]
		requires = ["setuptools"]
		build-backend = "setuptools.build_meta"
	EOF
}
