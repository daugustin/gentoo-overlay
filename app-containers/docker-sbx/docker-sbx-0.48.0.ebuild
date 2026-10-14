# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit optfeature

DESCRIPTION="Docker Sandboxes - run AI coding agents in isolated microVM sandboxes"
HOMEPAGE="
	https://docs.docker.com/ai/sandboxes/
	https://github.com/docker/sbx-releases
"
BASE_URI="https://github.com/docker/sbx-releases/releases/download/v${PV}/DockerSandboxes-linux"
SRC_URI="
	amd64? ( ${BASE_URI}-amd64.tar.gz -> ${P}-amd64.tar.gz )
	arm64? ( ${BASE_URI}-arm64.tar.gz -> ${P}-arm64.tar.gz )
"
S="${WORKDIR}/${PN}"

# sbx itself is proprietary; the bundled kernel, mkfs tools, shim and
# libsailor are open source (see THIRD-PARTY-NOTICES)
LICENSE="Docker-Sandboxes
	Apache-2.0 BSD GPL-2 GPL-2+ ISC MIT MPL-2.0 Unicode-3.0 Unlicense ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="apparmor"
RESTRICT="bindist mirror strip"

QA_PREBUILT="opt/${PN}/*"

src_install() {
	local dest=/opt/${PN}

	# sbx locates its helpers via <dir of executable>/../libexec
	exeinto ${dest}/bin
	doexe sbx
	dosym -r ${dest}/bin/sbx /usr/bin/sbx

	exeinto ${dest}/libexec
	doexe containerd-shim-nerdbox-v1 mkfs.erofs mkfs.ext4
	# GPU trampoline shim is only shipped in the amd64 tarball
	[[ -f containerd-shim-nerdbox-gpu-v1 ]] && doexe containerd-shim-nerdbox-gpu-v1

	# kernel/rootfs names differ per arch (nerdbox-kernel-x86_64 vs -arm64_4k)
	insinto ${dest}/libexec
	doins nerdbox-kernel-* nerdbox-rootfs-*.erofs

	exeinto ${dest}/libexec/lib
	doexe libsailor.so

	if use apparmor; then
		# upstream profile confines /usr/libexec; point it at our shim
		sed -i "s|/usr/libexec/containerd-shim-nerdbox-v1|${EPREFIX}${dest}/libexec/containerd-shim-nerdbox-v1|" \
			apparmor-profile || die
		insinto /etc/apparmor.d
		newins apparmor-profile docker-sbx-nerdbox-shim
	fi

	dodoc THIRD-PARTY-NOTICES
}

pkg_postinst() {
	elog "Docker Sandboxes runs each sandbox in a KVM microVM. Your user needs"
	elog "read/write access to /dev/kvm (usually: membership in the 'kvm' group)."
	elog "Run 'sbx login' to sign in with your Docker account."

	if [[ -f ${EROOT}/opt/${PN}/libexec/containerd-shim-nerdbox-gpu-v1 ]]; then
		elog
		elog "GPU passthrough needs the GPU shim to be setuid root. Enable it with:"
		elog "  sudo ${EROOT}/opt/${PN}/libexec/containerd-shim-nerdbox-gpu-v1 install"
		elog "This has to be repeated after every upgrade of ${PN}."
	fi

	if use apparmor; then
		elog
		elog "Load the AppArmor profile for the nerdbox shim with:"
		elog "  apparmor_parser -r -W /etc/apparmor.d/docker-sbx-nerdbox-shim"
	fi

	optfeature "credential storage via the Secret Service API" \
		gnome-base/gnome-keyring app-admin/keepassxc kde-frameworks/kwallet
	optfeature "image paste on Wayland (sbx settings set clipboard.imagePaste true)" \
		gui-apps/wl-clipboard
}
