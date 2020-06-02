# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit cmake

DESCRIPTION="A Qt application for WhatsApp Web with tray icon and notifications"
HOMEPAGE="https://gitlab.com/scarpetta/qtwaw"
SRC_URI="https://gitlab.com/scarpetta/qtwaw/-/archive/v${PV}/qtwaw-v${PV}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND="dev-qt/qtwebengine:5
	kde-frameworks/kdbusaddons:5
	kde-frameworks/knotifications:5"
RDEPEND="${DEPEND}"
BDEPEND=""

S="${WORKDIR}/${PN}-v${PV}"
