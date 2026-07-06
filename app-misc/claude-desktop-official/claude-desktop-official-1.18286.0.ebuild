# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg-utils

DESCRIPTION="Claude AI Desktop Application (official Anthropic binary)"
HOMEPAGE="https://claude.ai"

MY_PN="claude-desktop"

SRC_URI="https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/${MY_PN}/${MY_PN}_${PV}_amd64.deb"

S="${WORKDIR}"

LICENSE="Anthropic-TOS"
SLOT="0"
KEYWORDS="~amd64"

IUSE="claude-code cowork"

RESTRICT="bindist mirror strip"
QA_PREBUILT="usr/lib/${MY_PN}/*"

RDEPEND="
	!app-misc/claude-desktop-aaddrick
	!app-misc/claude-desktop-patrickjaja
	claude-code? ( dev-util/claude-code )
	cowork? (
		app-emulation/qemu[qemu_softmmu_targets_x86_64]
		app-emulation/virtiofsd
	)
"

src_prepare() {
	default

	# Cowork's bundled VM launcher only probes the Debian OVMF locations
	# (/usr/share/OVMF/OVMF_CODE{_4M,}.fd) and derives the matching
	# variable-store template by replacing OVMF_CODE with OVMF_VARS in
	# that path. Gentoo ships the raw firmware via sys-firmware/edk2-bin
	# (pulled in by qemu) under /usr/share/edk2/OvmfX64/, so rewrite the
	# probe list inside app.asar to point there. The replacement is padded
	# to the original length so the asar header's file offsets stay valid
	# (in-array whitespace is valid JS; Electron's asar integrity fuse is
	# not enforced on Linux, so the stale header hash is harmless).
	local asar="usr/lib/${MY_PN}/resources/app.asar"
	local old='"/usr/share/OVMF/OVMF_CODE_4M.fd","/usr/share/OVMF/OVMF_CODE.fd"'
	local new='"/usr/share/edk2/OvmfX64/OVMF_CODE.fd"'
	local pad=$(( ${#old} - ${#new} ))
	(( pad >= 0 )) || die "OVMF replacement path longer than original probe list"
	new+="$(printf '%*s' "${pad}" '')"

	[[ $(LC_ALL=C grep -aoF -- "${old}" "${asar}" | wc -l) -eq 1 ]] \
		|| die "OVMF probe list not found exactly once in app.asar"
	LC_ALL=C sed -i "s|${old//./\\.}|${new}|" "${asar}" \
		|| die "failed to patch OVMF probe list in app.asar"
}

src_install() {
	local destdir="/usr/lib/${MY_PN}"

	# Install the self-contained Electron application tree verbatim. cp -a
	# preserves the executable bits on the bundled binaries (the Electron
	# runtime, chrome_crashpad_handler, and the Cowork helpers
	# cowork-linux-helper / virtiofsd under resources/) that doins would
	# strip.
	dodir "${destdir}"
	cp -a "usr/lib/${MY_PN}/." "${ED}${destdir}/" \
		|| die "failed to install app tree"

	# chrome-sandbox must be SUID root for Chromium's setuid sandbox.
	fperms 4755 "${destdir}/chrome-sandbox"

	# /usr/bin/claude-desktop -> ../lib/claude-desktop/claude-desktop,
	# matching the symlink shipped in the .deb.
	dosym "../lib/${MY_PN}/${MY_PN}" "/usr/bin/${MY_PN}"

	# Desktop entry and icons ship inside the .deb.
	domenu "usr/share/applications/${MY_PN}.desktop"

	local size
	for size in 16 32 48 128 256; do
		doicon -s "${size}" \
			"usr/share/icons/hicolor/${size}x${size}/apps/${MY_PN}.png"
	done

	dodoc "usr/share/doc/${MY_PN}/copyright"
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
