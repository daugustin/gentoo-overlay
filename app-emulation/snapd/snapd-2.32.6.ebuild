# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit autotools golang-base multilib systemd

DESCRIPTION="Daemon and tooling that enable snap packages"
HOMEPAGE="https://snapcraft.io"
SRC_URI="https://github.com/snapcore/snapd/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND="sys-fs/squashfs-tools:*
	sys-fs/xfsprogs
	sys-libs/libcap"
DEPEND="dev-go/govendor
	${RDEPEND}"

src_prepare(){
	./mkversion.sh "${PV}"

	cd "${S}/cmd"
	eautoreconf

	default
}

src_configure(){
	cd "${S}/cmd"
	econf \
		--disable-apparmor \
		--enable-nvidia-biarch
}

src_compile(){
	export GOPATH="${WORKDIR}/.gopath"

	mkdir -p "${WORKDIR}/.gopath/src/github.com/snapcore/snapd" || die
	mv "${S}"/* "${WORKDIR}/.gopath/src/github.com/snapcore/snapd" || die

	cd "${WORKDIR}/.gopath/src/github.com/snapcore/snapd"

	einfo "Running govendor sync..."
	govendor sync || die

	for shared_build in snap snapctl snapd snap-seccomp; do
		go build -v -work -o "${WORKDIR}/${shared_build}" -x ${EGO_BUILD_FLAGS} "github.com/snapcore/snapd/cmd/${shared_build}" || die
	done

	for static_build in snap-update-ns; do
		go build -v -work -o "${WORKDIR}/${static_build}" -ldflags '-extldflags "-static"' -x ${EGO_BUILD_FLAGS} "github.com/snapcore/snapd/cmd/${static_build}" || die
	done

	emake -C cmd

	emake -C data/systemd
	rm data/systemd/*.in
}

src_install(){
	cd "${WORKDIR}"

	dobin snap snapctl

	dodir "/usr/$(get_libdir)/${PN}"
	exeinto "/usr/$(get_libdir)/${PN}"
	doexe snapd snap-seccomp snap-update-ns
	doexe "${WORKDIR}/.gopath/src/github.com/snapcore/snapd/cmd/snap-confine/snap-confine"
	fperms 4755 "/usr/$(get_libdir)/${PN}/snap-confine"

	cd "${WORKDIR}/.gopath/src/github.com/snapcore/snapd/data/systemd"
	systemd_dounit snapd*

	keepdir /var/lib/snapd
}