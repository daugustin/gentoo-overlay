# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="The most over-engineered C++ assertion library"
HOMEPAGE="https://github.com/jeremy-rifkin/libassert"
SRC_URI="https://github.com/jeremy-rifkin/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0/${PV}"
KEYWORDS="~amd64"
# The test suite fetches googletest, Catch2 and fmt with FetchContent
RESTRICT="test"

RDEPEND="dev-cpp/cpptrace:="
DEPEND="${RDEPEND}"

src_configure() {
	local mycmakeargs=(
		-DLIBASSERT_BUILD_TESTING=OFF
		-DLIBASSERT_DISABLE_CXX_20_MODULES=ON
		-DLIBASSERT_USE_EXTERNAL_CPPTRACE=ON
		-DLIBASSERT_USE_MAGIC_ENUM=OFF
	)
	cmake_src_configure
}
