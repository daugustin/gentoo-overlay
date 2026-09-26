# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LUA_COMPAT=( lua5-4 )

inherit cmake desktop flag-o-matic lua-single xdg

MY_PN="PrusaSlicer"
MY_PV="$(ver_rs 3 -)"
# Pinned in deps/+prusa_fdm_mixer/prusa_fdm_mixer.cmake
MIXER_COMMIT="09d372aeccb4f7b9a0efbe59d99d70dba196814a"
# Pinned in deps/+Tracy/Tracy.cmake, only the headers are used
TRACY_PV="0.13.1"
# Pinned in deps/+json/json.cmake, needs a fix not in any release yet
JSON_PV="3.12.0"
WX_GTK_VER="3.3-gtk3"

DESCRIPTION="A mesh slicer to generate G-code for fused-filament-fabrication (3D printers)"
HOMEPAGE="https://www.prusa3d.com/prusaslicer/"
SRC_URI="
	https://github.com/prusa3d/PrusaSlicer/archive/refs/tags/version_${MY_PV}.tar.gz -> ${P}.tar.gz
	https://github.com/prusa3d/prusa-fdm-mixer/archive/${MIXER_COMMIT}.tar.gz
		-> prusa-fdm-mixer-${MIXER_COMMIT}.tar.gz
	https://github.com/wolfpld/tracy/archive/refs/tags/v${TRACY_PV}.tar.gz -> tracy-${TRACY_PV}.tar.gz
	https://github.com/nlohmann/json/releases/download/v${JSON_PV}/json.tar.xz
		-> nlohmann-json-${JSON_PV}.tar.xz
"
S="${WORKDIR}/${MY_PN}-version_${MY_PV}"

LICENSE="AGPL-3 Boost-1.0 BSD GPL-2 LGPL-3 MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+webkit"
REQUIRED_USE="${LUA_REQUIRED_USE}"
# The tests need trompeloeil (catch2/trompeloeil.hpp), which is not packaged
RESTRICT="test"

RDEPEND="
	${LUA_DEPS}
	app-arch/libdeflate
	dev-cpp/libassert:=
	dev-cpp/rapidyaml:=
	dev-cpp/tbb:=
	dev-libs/boost:=[nls]
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/gmp:=
	dev-libs/libfmt:=
	dev-libs/mpfr:=
	dev-libs/openssl:=
	dev-libs/pugixml
	dev-libs/spdlog:=
	>=media-gfx/libbgcode-0.0.20260521
	media-gfx/openvdb:=
	media-libs/fontconfig
	media-libs/glew:0=
	media-libs/libjpeg-turbo:=
	media-libs/libpng:0=
	media-libs/nanosvg
	media-libs/qhull:=
	net-misc/curl[adns]
	sci-libs/libigl
	sci-libs/nlopt
	>=sci-libs/opencascade-7.8.0:=
	sci-mathematics/cgal:=
	sys-apps/dbus
	virtual/opengl
	virtual/zlib:=
	x11-libs/gtk+:3
	x11-libs/wxGTK:${WX_GTK_VER}=[X,opengl,webkit?]
	webkit? ( net-libs/webkit-gtk:4.1 )
"
DEPEND="${RDEPEND}
	dev-cpp/cli11
	=dev-cpp/eigen-3*:=
	dev-cpp/expected
	dev-cpp/magic_enum
	dev-cpp/range-v3
	dev-libs/cereal
	dev-libs/yoga
	media-libs/qhull[static-libs]
	$(lua_gen_cond_dep '
		dev-cpp/sol2[${LUA_USEDEP}]
	')
"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	"${FILESDIR}/${PN}-2.8.1-opencascade-7.8.0.patch"
	"${FILESDIR}/${P}-boost-1.87.patch"
	"${FILESDIR}/${P}-cgal-6.0.patch"
	"${FILESDIR}/${P}-nlohmann-json-optional.patch"
	"${FILESDIR}/${P}-system-deps.patch"
	"${FILESDIR}/${P}-wx-3.3.2.patch"
)

src_prepare() {
	# Built as part of bundled_deps, see the system-deps patch
	mkdir bundled_deps/prusa_fdm_mixer || die
	mv "${WORKDIR}/prusa-fdm-mixer-${MIXER_COMMIT}/cpp" \
		bundled_deps/prusa_fdm_mixer/prusa_fdm_mixer || die
	mv "${WORKDIR}/json" bundled_deps/nlohmann_json || die

	sed -i -e 's/PrusaSlicer-${SLIC3R_VERSION}+UNKNOWN/PrusaSlicer-${SLIC3R_VERSION}+Gentoo/g' \
		version.inc || die

	cmake_src_prepare
}

src_configure() {
	# Keep the eclass build type (Release would add -O3 and force LTO), but
	# upstream ships NDEBUG builds: without it debug-only code paths (e.g.
	# the preset bundle cache) and DEBUG_ASSERTs are enabled.
	append-cppflags -DNDEBUG

	local wxconf w
	wxconf="gtk3-unicode-${WX_GTK_VER%%-*}"
	for w in "${CHOST}-${wxconf}" "${wxconf}"; do
		[[ -f ${ESYSROOT}/usr/$(get_libdir)/wx/config/${w} ]] && wxconf=${w} && break
	done || die "Failed to find wxWidgets configuration ${wxconf}"

	local mycmakeargs=(
		# slic3r-app-cli is an untyped add_library() that is installed
		# with a RUNTIME destination only, it has to stay static.
		-DBUILD_SHARED_LIBS=OFF

		-DLUA_INCLUDE_DIR="$(lua_get_include_dir)"
		-DLUA_LIBRARY="$(lua_get_shared_lib)"
		-DTRACY_INCLUDE_DIR="${WORKDIR}/tracy-${TRACY_PV}/public"
		-DwxWidgets_CONFIG_EXECUTABLE="${ESYSROOT}/usr/$(get_libdir)/wx/config/${wxconf}"

		-DSLIC3R_BUILD_TESTS=OFF
		-DSLIC3R_DEBUG_PRESET_CACHE=OFF
		-DSLIC3R_ENABLE_FORMAT_STEP=ON
		-DSLIC3R_ENABLE_PROFILING=OFF
		-DSLIC3R_ENABLE_WEBKIT=$(usex webkit)
		-DSLIC3R_FHS=ON
		-DSLIC3R_GUI=ON
		-DSLIC3R_PCH=OFF
		-DSLIC3R_SENTRY_DSN=
		-DSLIC3R_STATIC=OFF
		-DSLIC3R_YAML=ryml
		-Wno-dev
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	# slic3r-app-launcher is the GUI and the CLI in one, as prusa-slicer was
	# in 2.x. The name only matters for upstream's flatpak; it also becomes
	# the WM_CLASS / Wayland app_id, which the desktop file has to match.
	mv "${ED}"/usr/bin/{slic3r-app-launcher,prusa-slicer} || die
	# Static archive of the CLI code linked into the launcher, no headers
	rm "${ED}"/usr/$(get_libdir)/libslic3r-app-cli.a || die

	# Upstream's desktop file carries the prusaslicer:// URL handler needed
	# for the Prusa Account login. Its ID com.prusa3d.PrusaSlicer is also
	# used by the Flathub package, whose export would shadow this one.
	sed -e "s|^Name=.*|Name=PrusaSlicer ${MY_PV}|" \
		-e 's|^Exec=/app/bin/slic3r-app-launcher |Exec=prusa-slicer |' \
		-e 's|^Icon=.*|Icon=prusa-slicer|' \
		"${BUILD_DIR}"/com.prusa3d.PrusaSlicer.desktop > "${T}"/prusa-slicer.desktop || die
	domenu "${T}"/prusa-slicer.desktop

	newicon -s scalable resources/icons/PrusaSlicer.svg prusa-slicer.svg
	newicon -s 128 resources/icons/PrusaSlicer_128px.png prusa-slicer.png
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "This is an alpha release. It keeps its settings in"
	elog "\${XDG_CONFIG_HOME:-~/.config}/PrusaSlicer3-dev, separate from the"
	elog "PrusaSlicer directory used by PrusaSlicer 2.x."
}
