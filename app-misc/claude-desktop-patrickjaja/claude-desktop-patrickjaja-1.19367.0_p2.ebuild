# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg-utils

DESCRIPTION="Claude AI Desktop Application (unofficial repackage of official binary)"
HOMEPAGE="https://claude.ai https://github.com/patrickjaja/claude-desktop-bin"

MY_PV=$(ver_cut 1-3)
MY_PR=$(ver_cut 5)
MY_PN=claude-desktop

# Upstream repackages Anthropic's official Linux .deb: the tarball bundles the
# official Electron runtime under electron/ and the patched app under app/, so
# no separate Electron download is needed.
SRC_URI="https://github.com/patrickjaja/claude-desktop-bin/releases/download/v${MY_PV}-${MY_PR}/${MY_PN}-${MY_PV}-linux.tar.gz -> ${MY_PN}-${MY_PV}-${MY_PR}-linux.tar.gz"

S="${WORKDIR}"

LICENSE="Anthropic-TOS"
SLOT="0"
KEYWORDS="~amd64"

IUSE="claude-code cowork wayland"

RESTRICT="bindist mirror strip"
QA_PREBUILT="usr/lib/${MY_PN}/*"

# Since v1.18286.0-3 upstream bundles static first-party Computer Use bridges
# (x11-bridge, wlroots-bridge, gnome-portal-bridge, kwin-portal-bridge) under
# resources/locales/, replacing the former third-party tool cascades:
#  - X11/XWayland: x11-bridge replaces xdotool, scrot, wmctrl and imagemagick's
#    import (no third-party fallback remains, so the X flag deps are gone)
#  - Sway/Hyprland/Niri: wlroots-bridge replaces ydotool and grim
#  - GNOME Wayland: gnome-portal-bridge (needs PipeWire >= 1.0.5, which GNOME
#    setups already run) replaces ydotool and the gnome-screenshot cascade
# Residual soft deps: ydotool for exotic Wayland compositors only, and
# imagemagick's convert alongside spectacle (shipped with KDE, not depended on
# here) for KDE Wayland below Plasma 6.6.
RDEPEND="
	!app-misc/claude-desktop-aaddrick
	!app-misc/claude-desktop-official
	claude-code? ( dev-util/claude-code )
	cowork? (
		app-emulation/qemu[qemu_softmmu_targets_x86_64]
		app-emulation/virtiofsd
	)
	wayland? (
		media-gfx/imagemagick
		x11-misc/ydotool
	)
	net-libs/nodejs
	net-misc/socat
"

src_prepare() {
	default

	# Both upstream's launcher diagnostics and its patched firmware probe
	# list in app.asar honor CLAUDE_OVMF_CODE_PATH as the first OVMF
	# candidate, but the built-in list only covers the Debian, Fedora and
	# Arch locations. Gentoo ships the firmware via sys-firmware/edk2-bin
	# (pulled in by qemu) under /usr/share/edk2/OvmfX64/, so seed the
	# documented override in the launcher instead of installing compat
	# symlinks under /usr/share/OVMF/. The variable-store template is
	# derived from the CODE path by replacing OVMF_CODE with OVMF_VARS,
	# which resolves within the same directory. virtiofsd needs no
	# override: Gentoo's /usr/libexec/virtiofsd is already probed.
	[[ $(grep -c '^set -euo pipefail$' launcher/claude-desktop) -eq 1 ]] \
		|| die "launcher injection anchor not found exactly once"
	sed -i '/^set -euo pipefail$/a\
\
# Gentoo: default the Cowork firmware probe to the sys-firmware/edk2-bin\
# OVMF location, which the built-in probe list does not cover.\
: "${CLAUDE_OVMF_CODE_PATH:=/usr/share/edk2/OvmfX64/OVMF_CODE.fd}"\
export CLAUDE_OVMF_CODE_PATH' launcher/claude-desktop \
		|| die "failed to patch launcher"
}

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

	# Note: with USE=cowork the tarball bundles a virtiofsd under
	# resources/locales/, but the app only uses it on Ubuntu 22.x
	# (os-release gate) -- on every other distro a system virtiofsd is
	# required, hence the RDEPEND. The OVMF firmware is found via the
	# CLAUDE_OVMF_CODE_PATH default seeded into the launcher above.
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update

	elog "Computer Use is served by bundled first-party bridges on X11,"
	elog "wlroots compositors (Sway/Hyprland/Niri), GNOME Wayland and KDE"
	elog "Plasma Wayland -- no external tools are needed for those sessions."
	if use wayland; then
		elog "ydotool is only used on exotic Wayland compositors without a"
		elog "bundled bridge; there, ensure the ydotoold daemon is running."
	fi
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
