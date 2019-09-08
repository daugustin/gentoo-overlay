# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit gnome2-utils meson vala

DESCRIPTION="A simple GObject game controller library"
HOMEPAGE="https://gitlab.gnome.org/aplazas/libmanette"
SRC_URI="https://gitlab.gnome.org/aplazas/libmanette/-/archive/${PV}/libmanette-${PV}.tar.gz"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

src_prepare() {
	vala_src_prepare

	default
}
