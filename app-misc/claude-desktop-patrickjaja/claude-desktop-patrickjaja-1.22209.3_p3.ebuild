# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop optfeature xdg-utils

DESCRIPTION="Claude AI Desktop Application (unofficial repackage of official binary)"
HOMEPAGE="https://claude.ai https://github.com/patrickjaja/claude-desktop-bin"

MY_PV=$(ver_cut 1-3)
MY_PR=$(ver_cut 5)
MY_PN=claude-desktop

# Upstream repackages Anthropic's official Linux .deb: since v1.20186.1-2 the
# tarball ships the official usr/lib/claude-desktop tree verbatim (bundled
# Electron runtime included, patched app.asar at its stock resources/
# location, entrypoint already renamed to "claude"), so no separate Electron
# download is needed. Patch releases reuse the tarball filename, so rename
# the distfile to keep it unique per release tag.
SRC_URI="https://github.com/patrickjaja/claude-desktop-bin/releases/download/v${MY_PV}-${MY_PR}/${MY_PN}-${MY_PV}-linux.tar.gz -> ${MY_PN}-${MY_PV}-${MY_PR}-linux.tar.gz"

S="${WORKDIR}"

LICENSE="Anthropic-TOS"
SLOT="0"
KEYWORDS="~amd64"

IUSE="cowork wayland"

RESTRICT="bindist mirror strip"
QA_PREBUILT="usr/lib/${MY_PN}/*"

# Since v1.18286.0-3 upstream bundles static first-party Computer Use bridges
# (x11-bridge, wlroots-bridge, gnome-portal-bridge, kwin-portal-bridge) --
# under resources/ as of v1.20186.1-2 -- replacing the former third-party
# tool cascades:
#  - X11/XWayland: x11-bridge replaces xdotool, scrot, wmctrl and imagemagick's
#    import (no third-party fallback remains, so the X flag deps are gone)
#  - Sway/Hyprland/Niri: wlroots-bridge replaces ydotool and grim
#  - GNOME Wayland: gnome-portal-bridge (needs PipeWire >= 1.0.5, which GNOME
#    setups already run) replaces ydotool and the gnome-screenshot cascade
# Residual soft deps: ydotool for exotic Wayland compositors only, and
# imagemagick's convert alongside spectacle (shipped with KDE, not depended on
# here) for KDE Wayland below Plasma 6.6.
# No dev-util/claude-code dependency: the app downloads and checksum-verifies
# its own Claude Code CLI matching the version it requires; a system claude
# binary is only used via the opt-in CLAUDE_CODE_LOCAL_BINARY=/path/to/claude.
RDEPEND="
	!app-misc/claude-desktop-aaddrick
	!app-misc/claude-desktop-official
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

	# Install the application tree verbatim: it matches the official .deb's
	# usr/lib/claude-desktop byte-identical except for the patched
	# resources/app.asar, the CU bridge binaries added to resources/, and
	# the Electron entrypoint shipped pre-renamed to "claude" -- which is
	# where the launcher resolves it (APP_ID="claude"). Electron auto-loads
	# the exe-adjacent resources/app.asar, so nothing is passed on the
	# command line. Since v1.21459.0 upstream dropped its desktopName pin,
	# so the window WM_CLASS / Wayland app_id is the official build's
	# "com.anthropic.Claude" -- the installed .desktop file is named after
	# it and sets it as StartupWMClass (reverse-DNS id, required for
	# xdg-desktop-portal to resolve the app for persistent portal grants).
	# cp -a preserves the executable bits that doins would strip.
	dodir "${destdir}"
	cp -a "${S}/${MY_PN}/." "${ED}${destdir}/" || die "failed to install app tree"

	# chrome-sandbox must be SUID root for Chromium's setuid sandbox.
	fperms 4755 "${destdir}/chrome-sandbox"

	dobin "${S}/launcher/claude-desktop"
	domenu "${FILESDIR}/com.anthropic.Claude.desktop"
	newicon -s 256 "${S}/icons/claude-desktop.png" claude-desktop.png

	dodoc "${S}/copyright"

	# Note: with USE=cowork the tarball bundles a virtiofsd under
	# resources/, but the app only uses it on Ubuntu 22.x (os-release
	# gate) -- on every other distro a system virtiofsd is required, hence
	# the RDEPEND. The OVMF firmware is found via the CLAUDE_OVMF_CODE_PATH
	# default seeded into the launcher above.
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update

	# Upstream aligned the app identity to the official build's
	# com.anthropic.Claude in v1.21459.0 (we skipped that line, so the
	# change lands with this version).
	local ver
	for ver in ${REPLACING_VERSIONS}; do
		if ver_test "${ver}" -lt 1.21459.0; then
			elog "The app identity changed from 'claude-desktop' to the official"
			elog "'com.anthropic.Claude' (.desktop file, WM_CLASS/Wayland app_id):"
			elog "  - re-pin any taskbar/dock shortcut once"
			elog "  - update custom WM rules matching 'claude-desktop'"
			elog "  - KDE screen-share/Computer Use consent is asked once more,"
			elog "    then persists (portal grants are keyed to the app id)"
			break
		fi
	done

	elog "Computer Use is served by bundled first-party bridges on X11,"
	elog "wlroots compositors (Sway/Hyprland/Niri), GNOME Wayland and KDE"
	elog "Plasma Wayland -- no external tools are needed for those sessions."
	if use wayland; then
		elog "ydotool is only used on exotic Wayland compositors without a"
		elog "bundled bridge; there, ensure the ydotoold daemon is running."
	fi

	# Since v1.22209.3-2 the in-app Hardware Buddy (Nibblet) BLE scan works
	# on Linux; Web Bluetooth needs a running bluetoothd (upstream Suggests).
	optfeature "Hardware Buddy (Nibblet) Bluetooth pairing" net-wireless/bluez
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
