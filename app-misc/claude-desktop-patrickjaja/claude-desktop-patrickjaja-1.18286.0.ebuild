# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg-utils

DESCRIPTION="Claude AI Desktop Application (unofficial repackage of official binary)"
HOMEPAGE="https://claude.ai https://github.com/patrickjaja/claude-desktop-bin"

MY_PN=claude-desktop

# Upstream now repackages Anthropic's official Linux .deb: the tarball bundles
# the official Electron runtime under electron/ and the patched app under app/,
# so no separate Electron download is needed anymore.
SRC_URI="https://github.com/patrickjaja/claude-desktop-bin/releases/download/v${PV}/${MY_PN}-${PV}-linux.tar.gz"

S="${WORKDIR}"

LICENSE="Anthropic-TOS"
SLOT="0"
KEYWORDS="~amd64"

IUSE="claude-code cowork gnome wayland X"

RESTRICT="bindist mirror strip"
QA_PREBUILT="usr/lib/${MY_PN}/*"

RDEPEND="
	!app-misc/claude-desktop-aaddrick
	!app-misc/claude-desktop-official
	claude-code? ( dev-util/claude-code )
	cowork? (
		app-emulation/qemu[qemu_softmmu_targets_x86_64]
		app-emulation/virtiofsd
	)
	wayland? (
		gnome? ( media-gfx/gnome-screenshot )
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

src_install() {
	local destdir="/usr/lib/${MY_PN}"

	# Install the bundled Electron runtime shipped in the tarball's electron/
	# tree (the official .deb's usr/lib/claude-desktop MINUS resources/): the
	# Electron binary, chrome-sandbox, the .so files, paks, chromium locales,
	# snapshots, etc. cp -a preserves the executable bits that doins would
	# strip.
	dodir "${destdir}"
	cp -a "${S}/electron/." "${ED}${destdir}/" || die "failed to install electron runtime"

	# The launcher sets APP_ID="claude" (systemd scope / cgroup portal
	# identity / generated .desktop filename) and resolves the Electron binary
	# at .../claude, so the binary shipped as "claude-desktop" in the .deb is
	# renamed to match. The window WM_CLASS / Wayland app_id is instead
	# "claude-desktop", derived from the app's desktopName in app.asar and not
	# from the binary basename -- the installed .desktop's StartupWMClass
	# matches that.
	mv "${ED}${destdir}/claude-desktop" "${ED}${destdir}/claude" \
		|| die "failed to rename electron binary"

	# chrome-sandbox must be SUID root for Chromium's setuid sandbox.
	fperms 4755 "${destdir}/chrome-sandbox"

	# Install the patched application tree into Electron's resources/ dir. The
	# electron/ tree ships no resources/ subdir (only resources.pak), so create
	# it first; the launcher resolves app.asar at .../resources/app.asar.
	dodir "${destdir}/resources"
	cp -a "${S}/app/." "${ED}${destdir}/resources/" || die "failed to install app files"

	dobin "${S}/launcher/claude-desktop"
	domenu "${FILESDIR}/claude.desktop"
	newicon -s 256 "${S}/icons/claude-desktop.png" claude-desktop.png

	dodoc "${S}/copyright"

	if use cowork; then
		# Cowork's bundled VM launcher only probes the Debian OVMF locations
		# (/usr/share/OVMF/OVMF_CODE{,_4M}.fd) and derives the matching
		# variable-store template by replacing OVMF_CODE with OVMF_VARS in that
		# path. Gentoo ships the raw firmware via sys-firmware/edk2-bin (pulled
		# in by qemu) under /usr/share/edk2/OvmfX64/, so bridge the two with
		# compat symlinks at the path Cowork expects.
		dosym ../edk2/OvmfX64/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE.fd
		dosym ../edk2/OvmfX64/OVMF_VARS.fd /usr/share/OVMF/OVMF_VARS.fd
	fi
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
