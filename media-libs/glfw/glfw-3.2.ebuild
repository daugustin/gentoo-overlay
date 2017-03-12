# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=5
inherit cmake-utils

DESCRIPTION="The Portable OpenGL FrameWork"
HOMEPAGE="http://www.glfw.org/"
SRC_URI="https://github.com/${PN}/${PN}/releases/download/${PV}/${P}.zip"

LICENSE="ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~hppa ~x86"
IUSE="egl examples vulkan"

RDEPEND="amd64? ( vulkan? ( media-libs/vulkan-loader ) )
	x11-libs/libXrandr
	x11-libs/libX11
	x11-libs/libXi
	x11-libs/libXxf86vm
	x11-libs/libXinerama
	x11-libs/libXcursor
	virtual/opengl"
DEPEND=${RDEPEND}

src_configure() {
	local mycmakeargs="
		$(cmake-utils_use egl GLFW_USE_EGL)
		$(cmake-utils_use examples GLFW_BUILD_EXAMPLES)
		-DBUILD_SHARED_LIBS=1
	"
	cmake-utils_src_configure
}
