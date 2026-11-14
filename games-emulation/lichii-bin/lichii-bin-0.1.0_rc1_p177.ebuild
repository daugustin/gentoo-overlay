# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

BUILD="${PV##*_p}"
BASE_URI="https://github.com/zortos293/Lichii/releases/download/build-${BUILD}"

DESCRIPTION="Experimental Nintendo Switch 2 emulator (Eden fork, binary release)"
HOMEPAGE="https://github.com/zortos293/Lichii"
SRC_URI="
	amd64? (
		!pgo? ( ${BASE_URI}/lichii-linux-x86_64.tar.gz -> ${P}-amd64.tar.gz )
		pgo? ( ${BASE_URI}/lichii-linux-x86_64-pgo.tar.gz -> ${P}-amd64-pgo.tar.gz )
	)
	arm64? (
		!pgo? ( ${BASE_URI}/lichii-linux-aarch64.tar.gz -> ${P}-arm64.tar.gz )
		pgo? ( ${BASE_URI}/lichii-linux-aarch64-pgo.tar.gz -> ${P}-arm64-pgo.tar.gz )
	)
"
S="${WORKDIR}/lichii"

# Lichii itself is GPL-3+; the AppDir bundles Qt6, FFmpeg and codecs,
# GLib/Pango/Cairo and the fsr4-vk upscaler with their own licenses.
LICENSE="GPL-3+ GPL-3 GPL-2+ LGPL-2.1+ LGPL-3 Apache-2.0 BSD BSD-2 MIT ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
IUSE="pgo"

RESTRICT="strip"

RDEPEND="
	>=sys-libs/glibc-2.39
	dev-libs/fribidi
	dev-libs/gmp
	dev-libs/libgpg-error
	dev-libs/libusb:1
	dev-libs/wayland
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/freetype
	media-libs/harfbuzz
	media-libs/libglvnd[X]
	media-libs/vulkan-loader
	sys-fs/e2fsprogs
	virtual/zlib
	x11-libs/libdrm
	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	x11-libs/libxcb
"

QA_PREBUILT="opt/lichii/*"

src_prepare() {
	default

	# Use the system Vulkan loader instead of the bundled Ubuntu one
	# (not every tarball variant bundles it)
	rm -f usr/lib/libvulkan.so.1 || die
}

src_install() {
	insinto /opt/lichii
	doins -r usr/.

	fperms +x /opt/lichii/bin/lichii /opt/lichii/bin/eden-cli

	dosym -r /opt/lichii/bin/lichii /usr/bin/lichii
	# Upstream still calls the CLI eden-cli; avoid clashing with Eden
	dosym -r /opt/lichii/bin/eden-cli /usr/bin/lichii-cli

	domenu usr/share/applications/io.github.zortos293.lichii.desktop
	doicon -s 256 \
		usr/share/icons/hicolor/256x256/apps/io.github.zortos293.lichii.png
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "The command line frontend (upstream: eden-cli) is installed as"
	elog "'lichii-cli'. Games, keys and firmware are not included; only use"
	elog "files you have legally obtained."
}
