# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop optfeature xdg

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
# 2.x above every 1.x, so the bump needs no revision gymnastics. 2.2553.x,
# 2.7032.0, 2.9939.4 and 2.26454.0 are ordered above it the same way, field
# by field.
#
# 2.7032.0 is a large release: Electron 44.2.0 -> 44.4.3 and a Linux
# portability pass that takes upstream's patch set from 48 to 50. What
# reaches this ebuild is mostly a relaxation: busctl, secret-tool,
# kwallet-query and sqlite3 used to be spawned from a hardcoded /usr/bin
# path and now fall back to a PATH lookup when that file is absent
# (fix_host_tool_paths_linux, fix_detected_projects_linux), so none of them
# has to sit at a fixed location any more -- on Gentoo they already did.
# The launcher grew a --diagnose host-capability report, a RHEL qemu-kvm shim
# (inert here: it only appends a dir that this package does not install) and
# an XDG_SESSION_TYPE fix for TTY-started compositors.
#
# 2.9939.4 added a reader for ${XDG_CONFIG_HOME:-~/.config}/
# claude-desktop-flags.conf to the launcher (see pkg_postinst).
#
# 2.26454.0 (skipping 2.19675.1, whose changes it carries) stays on Electron
# 44.4.3 with the same four top-level members. Anthropic's native module
# (claude-native-binding.node) now links libpipewire-0.3.so.0 and the app's
# file containment does not start without it, hence the new pipewire
# RDEPEND; its glibc floor stays at 2.34. Recent Projects now reads the
# editors' state in-process, so the sqlite3 CLI is no longer spawned and
# its optfeature is gone. The tree gained resources/linux-mime/ (shared MIME
# types for .mcpb/.dxt extensions and .skill files, installed below) and
# 32 more UI locale JSONs; the rest of the 3884 -> 3925 entry count change
# is ion-dist chunks. The launcher changes only touch AppImage integration
# and the --diagnose report; the sed anchor below still matches once.
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
# here) for KDE Wayland below Plasma 6.6. Since v2.7032.0 a bridge is only
# selected after it answers a `--version` run, so a bridge that cannot start
# falls through to the next tier instead of failing the capture. Since
# v2.19675.1 the official build carries its own Computer Use for a subset of
# accounts and desktops; upstream's bridges stay enabled and take precedence.
# xdg-open backs every link and "Open in ..." target, and is also the
# fallback opener in resources/claude-browser-shim.js, the $BROWSER shim
# v2.7032.0 added for links opened from a Code session.
# socat is the faster --toggle socket client and, since v2.26454.0, also
# half of the Claude Code shell sandbox (with bubblewrap, see pkg_postinst).
# No dev-util/claude-code dependency: the app downloads and checksum-verifies
# its own Claude Code CLI matching the version it requires; a system claude
# binary is only used via the opt-in CLAUDE_CODE_LOCAL_BINARY=/path/to/claude.
# The tty-detach added in v1.24012.9-14 needs ps (sys-process/procps) and
# setsid (sys-apps/util-linux); both are @system, and the launcher only warns
# when setsid is missing, so neither is listed here. Two more tools from
# v2.7032.0's --diagnose capability table are left out for the same kind of
# reason: python3 (it drives --install-gnome-hotkey, --1p/--3p and the jsonc
# feature-flag overrides) is @system via dev-lang/python, and systemd-inhibit
# -- the logind idle inhibitor "Keep computer awake" needs on desktops with no
# GNOME or freedesktop power service, i.e. sway, Hyprland, niri, i3 -- ships
# only with sys-apps/systemd, elogind's equivalent going by another name, so
# there is nothing portable to depend on.
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
	media-video/pipewire
	net-libs/nodejs
	net-misc/socat
	x11-misc/xdg-utils
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
	# cp -a preserves the executable bits that doins would strip, which
	# resources/claude-browser-shim.js also relies on: it is a sh/JS
	# polyglot that tools exec directly as $BROWSER.
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

	# Since v2.26454.0 .mcpb/.dxt extensions and .skill files open in the
	# app: the official packages register the shared MIME types shipped
	# under resources/linux-mime/ and list them in the desktop entry, whose
	# -r1 copy adds them to MimeType=.
	local mime="${S}/${MY_PN}/resources/linux-mime/com.anthropic.Claude.xml"
	[[ -f ${mime} ]] || die "linux-mime layout changed"
	insinto /usr/share/mime/packages
	doins "${mime}"
	newmenu "${FILESDIR}/com.anthropic.Claude-r1.desktop" \
		com.anthropic.Claude.desktop

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
	#
	# Not installed: the GNOME Shell search provider v2.7032.0 registers in
	# upstream's .deb, .rpm, pacman and Nix packages. Its two registration
	# files (the gnome-shell search-providers .ini and the D-Bus .service)
	# are emitted by those packaging scripts and are not in the tarball this
	# ebuild builds from -- the app tree itself is identical between the two
	# -- so there is nothing here for gjs to run and "claude-desktop
	# --diagnose" reports gjs as missing on a GNOME session.
}

pkg_postinst() {
	xdg_pkg_postinst

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

	# Most of the optional packages below only matter for one feature each,
	# and which ones a given session actually needs depends on its desktop.
	# v2.7032.0's --diagnose answers that per host instead of by guesswork.
	elog "\"claude-desktop --diagnose\" reports each host tool the app execs"
	elog "(found, or found only via the PATH fallback), whether every Computer"
	elog "Use bridge runs here, and a closing list of problems found."

	# v2.7032.0-3 taught the launcher to read persistent Electron flags, so
	# menu and autostart launches can carry them too. The file's flags rank
	# between the launcher's own choices and the real command line, and a
	# --password-store= there also skips the keyring probe described at the
	# keyring optfeature below. Announce it once, to whoever has not seen it.
	local v show_flags=1
	for v in ${REPLACING_VERSIONS}; do
		ver_test "${v}" -ge 2.9939.4 && show_flags=
	done
	if [[ -n ${show_flags} ]]; then
		elog "Persistent Electron/Chromium flags for every launch (menu and"
		elog "autostart included) go in ~/.config/claude-desktop-flags.conf,"
		elog "honoring \$XDG_CONFIG_HOME: one or more flags per line, # comments."
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
	# than a generic crash, and since v2.26454.0 upstream lists bubblewrap
	# with socat (an RDEPEND here already) as what such a policy needs.
	optfeature "sandboxed Claude Code runs under a managed policy" \
		sys-apps/bubblewrap

	# v2.7032.0 made the Chrome import's keyring helpers resolvable off
	# PATH as well: secret-tool (app-crypt/libsecret builds it
	# unconditionally) on libsecret desktops, kwallet-query
	# (kde-frameworks/kwallet-runtime) on KDE. Without them the import
	# still runs but silently skips every keyring-encrypted cookie.
	optfeature "Chrome cookie import from an unlocked keyring" \
		app-crypt/libsecret kde-frameworks/kwallet-runtime

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
