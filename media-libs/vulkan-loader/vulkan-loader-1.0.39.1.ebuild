# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
PYTHON_COMPAT=( python3_{4,5} )

inherit python-any-r1 cmake-multilib

GLSLANG_REV="807a0d9e2f4e176f75d62ac3c179c81800ec2608"
SPIRVHEADERS_REV="c470b68225a04965bf87d35e143ae92f831e8110"
SPIRVTOOLS_REV="37422e9dba1a3a8cb8028b779dd546d43add6ef8"

DESCRIPTION="Vulkan Installable Client Driver (ICD) Loader"
HOMEPAGE="https://www.khronos.org/vulkan/"
SRC_URI="https://github.com/KhronosGroup/Vulkan-LoaderAndValidationLayers/archive/sdk-${PV}.tar.gz -> ${P}.tar.gz
	https://api.github.com/repos/KhronosGroup/glslang/tarball/${GLSLANG_REV} -> vulkan-glslang-${PV}.tar.gz
	https://api.github.com/repos/KhronosGroup/SPIRV-Headers/tarball/${SPIRVHEADERS_REV} -> vulkan-spirvheaders-${PV}.tar.gz
	https://api.github.com/repos/KhronosGroup/SPIRV-Tools/tarball/${SPIRVTOOLS_REV} -> vulkan-spirvtools-${PV}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
IUSE="wayland"

KEYWORDS="~amd64"

DEPEND="${PYTHON_DEPS}
	x11-libs/libX11:=
	wayland? ( dev-libs/wayland )
	!media-libs/vulkan-base"
RDEPEND="${DEPEND}"

S="${WORKDIR}/Vulkan-LoaderAndValidationLayers-sdk-${PV}"

src_unpack() {
	default

	multilib_src_unpack() {
		mkdir -p "${BUILD_DIR}/external"/{glslang,spirv-tools{,/external/spirv-headers}} || die
		cp -a "${WORKDIR}/KhronosGroup-glslang-${GLSLANG_REV:0:7}"/* "${BUILD_DIR}/external/glslang"
		cp -a "${WORKDIR}/KhronosGroup-SPIRV-Tools-${SPIRVTOOLS_REV:0:7}"/* "${BUILD_DIR}/external/spirv-tools"
		cp -a "${WORKDIR}/KhronosGroup-SPIRV-Headers-${SPIRVHEADERS_REV:0:7}"/* "${BUILD_DIR}/external/spirv-tools/external/spirv-headers"
	}

	multilib_foreach_abi multilib_src_unpack
}

multilib_src_configure() {
	cd "${BUILD_DIR}/external/glslang"
	cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release || die

	cd "${BUILD_DIR}/external/spirv-tools"
	cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release || die

	local mycmakeargs=(
		-DCMAKE_SKIP_RPATH=True
		-DBUILD_TESTS=False
		-DBUILD_LAYERS=True
		-DBUILD_DEMOS=True
		-DBUILD_VKJSON=True
		-DBUILD_LOADER=True
		-DBUILD_WSI_MIR_SUPPORT=False
		-DBUILD_WSI_WAYLAND_SUPPORT=$(usex wayland)
		-DGLSLANG_VALIDATOR="${BUILD_DIR}/external/glslang/build/install/bin/glslangValidator"
		-DGLSLANG_SPIRV_INCLUDE_DIR="${BUILD_DIR}/external/glslang"
		-DSPIRV_TOOLS_INCLUDE_DIR="${BUILD_DIR}/external/spirv-tools/include"
		-DSPIRV_TOOLS_LIB="${BUILD_DIR}/external/spirv-tools/build/source"
	)
	cmake-utils_src_configure
}

multilib_src_compile(){
	cd "${BUILD_DIR}/external/glslang/build"
	emake || die "cannot build glslang"
	emake install || die "cannot install glslang"

	cd "${BUILD_DIR}/external/spirv-tools/build"
	emake || die "cannot build SPIRV-Tools"

	cmake-utils_src_compile
}

multilib_src_install() {
	keepdir /etc/vulkan/icd.d

	cd "${BUILD_DIR}/loader"
	dolib libvulkan.so.1.*
	dosym libvulkan.so.1.* /usr/$(get_libdir)/libvulkan.so.1
	dosym libvulkan.so.1.* /usr/$(get_libdir)/libvulkan.so

	cd "${BUILD_DIR}/layers"
	dolib *.so
	sed -i -e 's#./libVk#libVk#g' *.json || die
	insinto /usr/share/vulkan/explicit_layer.d
	doins *.json

	cd "${BUILD_DIR}/demos"
	dobin vulkaninfo

	insinto /usr/include/vulkan
	doins "${S}"/include/vulkan/{*.h,*.hpp}
}
