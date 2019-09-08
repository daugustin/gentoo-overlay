# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit gnome2-utils meson vala

MY_PV="0.14.2-1-master"

DESCRIPTION="All your games in one place"
HOMEPAGE="https://tkashkin.tk/projects/gamehub"
SRC_URI="https://github.com/tkashkin/GameHub/archive/${MY_PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND="x11-libs/gtk+:3"
RDEPEND="${DEPEND}"
BDEPEND="$(vala_depend)"

S="${WORKDIR}/GameHub-${MY_PV}"

pkg_preinst(){
	gnome2_schemas_savelist
}

src_prepare() {
	vala_src_prepare

	default
}

pkg_postinst(){
	gnome2_schemas_update
	xdg_icon_cache_update
}

pkg_postrm(){
	gnome2_schemas_update
	xdg_icon_cache_update
}
