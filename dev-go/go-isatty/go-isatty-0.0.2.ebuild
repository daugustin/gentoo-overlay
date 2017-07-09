# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit golang-build golang-vcs-snapshot

DESCRIPTION="isatty for golang"
HOMEPAGE="https://github.com/mattn/go-isatty"
SRC_URI="https://github.com/mattn/go-isatty/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

EGO_PN="github.com/mattn/go-isatty"

DEPEND="dev-go/go-sys"