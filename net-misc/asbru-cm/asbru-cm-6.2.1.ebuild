# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit bash-completion-r1 desktop

DESCRIPTION="Asbru CM is a user interface that helps organizing remote terminal sessions"
HOMEPAGE="https://www.asbru-cm.net/"
SRC_URI="https://github.com/${PN}/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND="dev-libs/ossp-uuid[perl]
    dev-perl/Crypt-CBC
    dev-perl/Expect
    dev-perl/Glib-Object-Introspection
    >=dev-perl/Gtk3-0.37.0
    dev-perl/Gtk3-SimpleList
    dev-perl/Net-ARP
    dev-perl/Socket6
    dev-perl/YAML
    x11-libs/vte:2.91"
RDEPEND="${DEPEND}"
BDEPEND=""

src_install() {
    rm -r build.sh dist mkdocs.yml scripts

	doman "res/${PN}.1"
	rm "res/${PN}.1"

	insinto /usr/share/applications
	doins "res/${PN}.desktop"
	rm "res/${PN}.desktop"

	newicon -s scalable res/asbru-logo.svg "${PN}".svg
	newicon -s 24 res/asbru-logo-24.png "${PN}".png
	newicon -s 256 res/asbru-logo-256.png "${PN}".png
	newicon -s 64 res/asbru-logo-64.png "${PN}".png

	newbashcomp res/asbru_bash_completion "${PN}"
	rm res/asbru_bash_completion

	insinto /opt/asbru
	doins -r *

	fperms +x /opt/asbru/utils/*

	dosym "/opt/asbru/${PN}" "${EPREFIX}/usr/bin/${PN}"
}
