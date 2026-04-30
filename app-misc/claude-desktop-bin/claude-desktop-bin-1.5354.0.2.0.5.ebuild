# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg-utils

DESCRIPTION="Claude AI Desktop Application"
HOMEPAGE="https://claude.ai https://github.com/aaddrick/claude-desktop-debian"
SRC_URI="
	amd64? ( https://github.com/aaddrick/claude-desktop-debian/releases/download/v$(ver_cut 4-6)%2Bclaude$(ver_cut 1-3)/claude-desktop_$(ver_cut 1-3)-$(ver_cut 4-6)_amd64.deb )
	arm64? ( https://github.com/aaddrick/claude-desktop-debian/releases/download/v$(ver_cut 4-6)%2Bclaude$(ver_cut 1-3)/claude-desktop_$(ver_cut 1-3)-$(ver_cut 4-6)_arm64.deb )
"

LICENSE="Anthropic-TOS"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RESTRICT="bindist mirror strip"
QA_PREBUILT="usr/lib/claude-desktop/*"

BDEPEND="app-arch/zstd"

S="${WORKDIR}"

src_install() {
	insinto /usr/lib/claude-desktop
	doins -r usr/lib/claude-desktop/.

	fperms +x /usr/lib/claude-desktop/launcher-common.sh
	fperms +x /usr/lib/claude-desktop/node_modules/electron/dist/electron
	fperms 4755 /usr/lib/claude-desktop/node_modules/electron/dist/chrome-sandbox
	fperms +x /usr/lib/claude-desktop/node_modules/electron/dist/chrome_crashpad_handler

	dobin usr/bin/claude-desktop

	domenu usr/share/applications/claude-desktop.desktop

	local size
	for size in 16 24 32 48 64 128 256 512; do
		local icon="usr/share/icons/hicolor/${size}x${size}/apps/claude-desktop.png"
		if [[ -f ${icon} ]]; then
			doicon -s "${size}" "${icon}"
		fi
	done
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update

	elog "Claude Desktop has been installed."
	elog "Run 'claude-desktop --doctor' to check system dependencies."
	elog ""
	elog "For native Wayland support (disables global hotkeys), set:"
	elog "  CLAUDE_USE_WAYLAND=1"
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
