# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit meson multilib-minimal

MY_IMGUI_COMMIT="96a2c4619b0c8009f684556683b2e1b6408bb0dc"
MY_PN="MangoHud"

DESCRIPTION="A Vulkan and OpenGL overlay for monitoring FPS, temperatures, CPU/GPU load and more"
HOMEPAGE="https://github.com/flightlessmango/MangoHud"
SRC_URI="https://github.com/flightlessmango/MangoHud/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/flightlessmango/imgui/archive/${MY_IMGUI_COMMIT}.tar.gz -> ${PN}-imgui-${PV}.tar.gz"

#./bin
#./bin/mangohud.x86
#./bin/mangohud
#./share
#./share/doc
#./share/doc/mangohud
#./share/doc/mangohud/MangoHud.conf.example
#./share/vulkan
#./share/vulkan/implicit_layer.d
#./share/vulkan/implicit_layer.d/MangoHud.x86_64.json
#./share/vulkan/implicit_layer.d/MangoHud.x86.json
#./lib
#./lib/mangohud
#./lib/mangohud/lib32
#./lib/mangohud/lib32/libMangoHud.so
#./lib/mangohud/lib64
#./lib/mangohud/lib64/libMangoHud.so

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="doc"

DEPEND="dev-util/vulkan-headers
	dev-util/glslang"
RDEPEND="${DEPEND}"
BDEPEND=""

S="${WORKDIR}/${MY_PN}-${PV}"

src_prepare() {
	rmdir "${S}/modules/ImGui/src" || die
	mv "${WORKDIR}/imgui-${MY_IMGUI_COMMIT}" "${S}/modules/ImGui/src" || die

	# Because we install into /usr/lib we dont need this
	sed -i '/^LD_LIBRARY_PATH/d' "${S}/bin/mangohud.in" || die

	default
}

multilib_src_configure() {
	local emesonargs=(
		-Dappend_libdir_mangohud=false
		-Duse_system_vulkan=enabled
		$(meson_use doc include_doc)
	)

	meson_src_configure
}

multilib_src_compile() {
	meson_src_compile
}

multilib_src_install() {
	meson_src_install
}

multilib_src_install_all() {
	# Because we install into /usr/lib we can always use mangohud
	test -e "${D}/usr/bin/mangohud.x86" && rm -f "${D}/usr/bin/mangohud.x86"

	use doc && mv "${D}/usr/share/doc/${PN}" "${D}/usr/share/doc/${PF}"

	default
}
