# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg-utils

DESCRIPTION="Claude AI Desktop Application (unofficial repackage of official binary)"
HOMEPAGE="https://claude.ai https://github.com/patrickjaja/claude-desktop-bin"

ELECTRON_VER=41.5.0
MY_PV=$(ver_cut 1-3)
MY_PR=$(ver_cut 5)
MY_PN=claude-desktop-bin

SRC_URI="
		https://github.com/patrickjaja/claude-desktop-bin/releases/download/v${MY_PV}-${MY_PR}/claude-desktop-${MY_PV}-linux.tar.gz -> claude-desktop-${MY_PV}-${MY_PR}-linux.tar.gz
		https://github.com/electron/electron/releases/download/v${ELECTRON_VER}/electron-v${ELECTRON_VER}-linux-x64.zip
"

LICENSE="Anthropic-TOS"
SLOT="0"
KEYWORDS="~amd64"

IUSE="claude-code claude-cowork gnome wayland X"

RESTRICT="bindist mirror strip"
QA_PREBUILT="usr/lib/${PN}/*"

BDEPEND="app-arch/unzip"
RDEPEND="
  !app-misc/claude-code-aaddrick
  claude-code? ( dev-util/claude-code )
  wayland? (
    gnome? ( gnome-extra/gnome-screenshot )
    x11-misc/ydotool
  )
  X? (
    media-gfx/scrot
    x11-misc/wmctrl
    x11-misc/xdotool
  )
  media-gfx/imagemagick
  net-libs/nodejs
  net-misc/socat
"

S="${WORKDIR}"

src_unpack() {
	unpack claude-desktop-${MY_PV}-${MY_PR}-linux.tar.gz

	mkdir -p "${WORKDIR}/electron-runtime" || die
	pushd "${WORKDIR}/electron-runtime" >/dev/null || die
	unpack electron-v${ELECTRON_VER}-linux-x64.zip
	popd >/dev/null || die
}

src_install() {
	local destdir="/usr/lib/${MY_PN}"

	dodir "${destdir}"
	cp -a "${WORKDIR}/electron-runtime/." "${ED}${destdir}/" || die "failed to install electron runtime"

	# Electron reads /proc/self/exe for the Wayland app_id / X11 WM_CLASS,
	# so the binary name must match the .desktop StartupWMClass.
	mv "${ED}${destdir}/electron" "${ED}${destdir}/com.anthropic.claude-desktop" \
		|| die "failed to rename electron binary"

	fperms 4755 "${destdir}/chrome-sandbox"

	cp -a "${S}/app/." "${ED}${destdir}/resources/" || die "failed to install app files"

	dobin "${S}/launcher/claude-desktop"
	domenu "${FILESDIR}/com.anthropic.claude-desktop.desktop"
	newicon -s 256 "${S}/icons/claude-desktop.png" claude-desktop.png
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update

	elog "If using ydotool on Wayland, ensure the ydotoold daemon is running."
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
