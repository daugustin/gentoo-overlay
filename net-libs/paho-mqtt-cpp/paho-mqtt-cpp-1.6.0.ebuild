# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Eclipse Paho MQTT C++ client library"
HOMEPAGE="https://eclipse.dev/paho/ https://github.com/eclipse-paho/paho.mqtt.cpp"
SRC_URI="https://github.com/eclipse-paho/paho.mqtt.cpp/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/paho.mqtt.cpp-${PV}"

# Dual licensed, EDL-1.0 is the 3-clause BSD license
LICENSE="|| ( EPL-2.0 BSD )"
# The soname stays at 1 although the ABI changes between minor versions
SLOT="0/${PV}"
KEYWORDS="~amd64"
IUSE="+ssl"
# Several client tests need an MQTT broker on localhost
RESTRICT="test"

RDEPEND="
	>=net-libs/paho-mqtt-c-1.3.14:=[ssl=]
	ssl? ( dev-libs/openssl:= )
"
DEPEND="${RDEPEND}"

src_configure() {
	local mycmakeargs=(
		-DPAHO_BUILD_DOCUMENTATION=OFF
		-DPAHO_BUILD_EXAMPLES=OFF
		-DPAHO_BUILD_SAMPLES=OFF
		-DPAHO_BUILD_SHARED=ON
		-DPAHO_BUILD_STATIC=OFF
		-DPAHO_BUILD_TESTS=OFF
		-DPAHO_WITH_MQTT_C=OFF
		-DPAHO_WITH_SSL=$(usex ssl)
	)
	cmake_src_configure
}
