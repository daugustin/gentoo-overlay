# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop optfeature xdg-utils

DESCRIPTION="Claude AI Desktop with extra Linux features (unofficial repackage)"
HOMEPAGE="https://claude.ai https://github.com/patrickjaja/claude-desktop-extra"

MY_PV=$(ver_cut 1-3)
MY_PR=$(ver_cut 5)
MY_PN=claude-desktop

# Upstream renamed the project from claude-desktop-bin to claude-desktop-extra
# in v1.24012.9-8 (repository, packages and the ~/.config/Claude config file).
# The old GitHub repository is not a redirect -- it was recreated as a
# transitional mirror -- so releases are fetched from the new repository.
#
# Upstream repackages Anthropic's official Linux .deb: since v1.20186.1-2 the
# tarball ships the official usr/lib/claude-desktop tree verbatim (bundled
# Electron runtime included, patched app.asar at its stock resources/
# location, entrypoint already renamed to "claude"), so no separate Electron
# download is needed. Patch releases reuse the tarball filename, so rename
# the distfile to keep it unique per release tag. The first release of a
# version is tagged without the patch-level suffix (upstream package release
# 1), so a bare ${PV} maps to that tag and _pN to the v${MY_PV}-N re-releases.
#
# Anthropic renumbered the app itself with 2.110.0 (build of 2026-09-15),
# succeeding 1.52386.6: the old scheme's middle field was a build counter, so
# the smaller 110 is a rename rather than a downgrade. Portage orders every
# 2.x above every 1.x, so the bump needs no revision gymnastics. 2.2553.1 is
# ordered above 2.110.0 the same way, field by field (2553 > 110).
#
# Packaged from the bare v2.2553.1 tag rather than the later v2.2553.1-2: that
# re-release only added a colour theme, README text and a Nix hash, none of
# which reach the Linux tarball, which is byte-identical between the two tags.
# Its launcher/claude-desktop is likewise byte-identical to 2.110.0-2's.
MY_TAG="v${MY_PV}${MY_PR:+-${MY_PR}}"
SRC_URI="https://github.com/patrickjaja/claude-desktop-extra/releases/download/${MY_TAG}/${MY_PN}-${MY_PV}-linux.tar.gz -> ${MY_PN}-${MY_PV}-${MY_PR:-1}-linux.tar.gz"

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
# The tty-detach added in v1.24012.9-14 needs ps (sys-process/procps) and
# setsid (sys-apps/util-linux); both are @system, and the launcher only warns
# when setsid is missing, so neither is listed here.
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

	# chrome-sandbox must be SUID root for Chromium's setuid sandbox. This
	# only started mattering outside X11 in v1.49585.0-5: the launcher used
	# to append --no-sandbox to every Wayland and XWayland launch, so those
	# sessions ran remote claude.ai content unsandboxed no matter what mode
	# the binary carried. The switch is now withheld everywhere except the
	# AppImage (a FUSE mount cannot carry a SUID bit), which we do not ship,
	# and the CLAUDE_DISABLE_SANDBOX=1 escape hatch.
	fperms 4755 "${destdir}/chrome-sandbox"

	dobin "${S}/launcher/claude-desktop"
	domenu "${FILESDIR}/com.anthropic.Claude.desktop"

	# Since v1.30096.1 the tarball carries the official .deb's whole hicolor
	# icon tree (16 to 256) instead of a single 256x256 PNG; install every
	# size upstream ships.
	local icon size
	[[ -f ${S}/icons/hicolor/256x256/apps/${MY_PN}.png ]] \
		|| die "icon tree layout changed"
	for icon in "${S}"/icons/hicolor/*/apps/${MY_PN}.png; do
		size=${icon#*/icons/hicolor/}
		doicon -s "${size%%x*}" "${icon}"
	done

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

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "Upstream renamed the project from claude-desktop-bin to"
		elog "claude-desktop-extra. Installed paths and the app identity are"
		elog "unchanged, so shortcuts and portal grants stay valid. On first"
		elog "launch the app migrates the user config"
		elog "~/.config/Claude/claude-desktop-bin.jsonc (themes, feature-flag"
		elog "overrides) to claude-desktop-extra.jsonc, keeping the old file as a"
		elog "backup -- nothing to do by hand."
	fi

	elog "Computer Use is served by bundled first-party bridges on X11,"
	elog "wlroots compositors (Sway/Hyprland/Niri), GNOME Wayland and KDE"
	elog "Plasma Wayland -- no external tools are needed for those sessions."
	if use wayland; then
		elog "ydotool is only used on exotic Wayland compositors without a"
		elog "bundled bridge; there, ensure the ydotoold daemon is running."
	fi

	# The in-app Hardware Buddy (Nibblet) BLE scan works on Linux since
	# v1.22209.3-4, which armed the BLE transport at the feature-store
	# level and enabled Chromium's Web Bluetooth Blink feature in the
	# launcher; it needs a running bluetoothd (upstream Suggests).
	optfeature "Hardware Buddy (Nibblet) Bluetooth pairing" net-wireless/bluez

	# v1.32352.1 added flag-gated Remote Control and remote SSH session
	# backends. Their default transport spawns the system "ssh" off PATH
	# (and reads its config via "ssh -G"); the app also bundles the ssh2
	# JS library, which a kill-switch flag can force instead, so OpenSSH
	# stays optional rather than an RDEPEND.
	optfeature "Remote Control / remote SSH sessions via the OpenSSH client" \
		net-misc/openssh

	# v1.46388.2 gained a Linux sandbox for the Code tab's Claude Code
	# runs. It is auto-detected off PATH (the admin-only managed setting
	# "bwrapPath" overrides the lookup) and only engages once an
	# admin-managed egress allowlist or allowedWorkspaceFolders is
	# configured -- without bwrap those sessions fall back to prompting
	# for shell reads instead of confining them, so this is optional.
	# Since v2.2553.1 a local session that needs the sandbox and cannot
	# find one fails with an explicit sandbox_required_unavailable rather
	# than a generic crash, so the missing package is at least legible.
	optfeature "sandboxed Claude Code runs under a managed policy" \
		sys-apps/bubblewrap

	# The detectedProjects scan reads the editor state DBs (VS Code's
	# state.vscdb and friends) by spawning the hardcoded absolute path
	# /usr/bin/sqlite3 -- not a PATH lookup, so the CLI has to sit exactly
	# there, which is where dev-db/sqlite installs it unconditionally (the
	# "tools" USE flag only adds the extra sqlite3-* helpers). Without it
	# every scan pass fails with ENOENT into logs/main.log; the feature
	# itself just degrades to no detected projects, hence optional.
	optfeature "project detection from editor state databases" dev-db/sqlite

	# Chromium derives its os_crypt backend from XDG_CURRENT_DESKTOP and
	# falls back to basic_text on every desktop it does not map to a keyring
	# (Hyprland, Sway, niri, COSMIC, and XFCE/LXQt by policy): safeStorage
	# then reports encryption unavailable, the OAuth token is not persisted
	# and each start lands on /login. v1.49585.0-5 made the launcher probe
	# org.freedesktop.secrets on the session bus and pass
	# --password-store=gnome-libsecret when something answers, which fixes
	# those desktops -- but only if a provider is actually running, and the
	# branch that used to be silent now says so in launcher.log. v1.49585.0
	# also added a remembered-SSH-password store that refuses to save
	# without a real keyring backend. KDE needs no extra package here: its
	# kwallet is what Chromium already maps to.
	optfeature "persistent sign-in and stored SSH passwords via a keyring" \
		gnome-base/gnome-keyring kde-frameworks/kwallet \
		"app-admin/keepassxc[keyring]"
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
