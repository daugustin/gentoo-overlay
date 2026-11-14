# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# The rpm payload is gzip/uncompressed (no PayloadIs* marker), which
# rpm.eclass reports as 'none'.
RPM_COMPRESS_TYPE="none"

inherit desktop rpm xdg

DESCRIPTION="Official open-source two-factor authentication app by Proton"
HOMEPAGE="https://proton.me/authenticator"
SRC_URI="https://proton.me/download/authenticator/linux/ProtonAuthenticator-${PV}-1.x86_64.rpm"
S="${WORKDIR}"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="-* ~amd64"

RDEPEND="
	dev-libs/glib:2
	net-libs/libsoup:3.0
	net-libs/webkit-gtk:4.1
	sys-apps/dbus
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
"

QA_PREBUILT="usr/bin/proton-authenticator"

src_install() {
	dobin usr/bin/proton-authenticator

	newmenu "usr/share/applications/Proton Authenticator.desktop" \
		proton-authenticator.desktop

	local size
	for size in 32x32 128x128 256x256@2; do
		doicon -s ${size%%x*} \
			usr/share/icons/hicolor/${size}/apps/proton-authenticator.png
	done
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "The \"secure storage\" feature keeps its key in the Secret Service"
	elog "keyring. Upstream only supports it with GNOME (gnome-keyring)."
	elog "With KDE's ksecretd/kwallet the key gets written, but the app"
	elog "reports \"Storage key could not be saved to keyring\" and leaves"
	elog "orphaned com.proton.authenticator entries in the wallet."
	elog "On KDE, use an app password lock instead."
}
