# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit shell-completion toolchain-funcs

DESCRIPTION="CLI volume control for PulseAudio"
HOMEPAGE="https://github.com/falconindy/ponymix"
SRC_URI="https://github.com/falconindy/ponymix/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="libnotify"

RDEPEND="
	media-libs/libpulse
	libnotify? ( x11-libs/libnotify )
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_prepare() {
	default

	sed -i "s:pkg-config:$(tc-getPKG_CONFIG):g" Makefile || die "sed failed"
}

src_compile() {
	local makeargs=( CXX="$(tc-getCXX)" )

	# The Makefile probes for libnotify with pkg-config and silently links
	# against it when found, so pin the result to USE instead.
	if use libnotify; then
		local notify_cflags notify_libs
		notify_cflags=$($(tc-getPKG_CONFIG) --cflags libnotify) || die
		notify_libs=$($(tc-getPKG_CONFIG) --libs libnotify) || die

		makeargs+=(
			libnotify_CXXFLAGS="-DHAVE_NOTIFY ${notify_cflags}"
			libnotify_LIBS="${notify_libs}"
		)
	else
		makeargs+=( libnotify_CXXFLAGS= libnotify_LIBS= )
	fi

	emake "${makeargs[@]}"
}

src_install() {
	dobin "${PN}"
	doman "${PN}.1"

	newbashcomp bash-completion "${PN}"
	newzshcomp zsh-completion "_${PN}"
}
