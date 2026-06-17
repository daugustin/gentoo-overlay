# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module systemd

DESCRIPTION="Native Linux backend daemon for Claude Desktop Cowork"
HOMEPAGE="https://github.com/patrickjaja/claude-cowork-service"
SRC_URI="https://github.com/patrickjaja/claude-cowork-service/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND=">=dev-lang/go-1.22"

src_compile() {
	# Upstream's Makefile defaults (CGO_ENABLED=0, -trimpath -buildmode=pie)
	# are fine; just inject the version for `-X main.version=`.
	emake VERSION="${PV}"
}

src_install() {
	dobin cowork-svc-linux

	systemd_douserunit claude-cowork.service

	newinitd claude-cowork.openrc claude-cowork
	newconfd claude-cowork.confd claude-cowork

	einstalldocs
}

pkg_postinst() {
	elog "The Claude Cowork backend is designed to run as a per-user daemon."
	elog
	elog "systemd users:"
	elog "  systemctl --user daemon-reload"
	elog "  systemctl --user enable --now claude-cowork.service"
	elog
	elog "OpenRC users:"
	elog "  Edit /etc/conf.d/claude-cowork and set COWORK_USER to your"
	elog "  desktop user, then start the service AFTER the graphical session"
	elog "  is up (e.g. from your compositor's startup hooks):"
	elog "    rc-service claude-cowork start"
}
