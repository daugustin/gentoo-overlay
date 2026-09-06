# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-mod-r1 systemd udev

DESCRIPTION="Tiered VRAM/RAM/NVMe memory pool for CUDA workloads"
HOMEPAGE="https://gitlab.com/IsolatedOctopi/greenboost"
SRC_URI="https://gitlab.com/IsolatedOctopi/${PN}/-/archive/v${PV}/${PN}-v${PV}.tar.bz2"
S="${WORKDIR}/${PN}-v${PV}"

# LICENSE grants MIT for every file in the tree; the linked kernel module is
# additionally dual MIT/GPL-2 (MODULE_LICENSE is "GPL v2").  The opening line
# of THIRD_PARTY_NOTICES.md still claims plain GPL-2 and is stale.
LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="abi_x86_32 bpf"

RDEPEND="
	app-arch/zstd:=
	virtual/udev
	x11-drivers/nvidia-drivers
	bpf? ( dev-libs/libbpf:= )
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	bpf? (
		dev-util/bpftool
		llvm-core/clang
	)
"

src_prepare() {
	default

	# Upstream builds the module against exactly one kernel and can afford
	# -Werror; we build against whatever the user is running, where a new
	# compiler or kernel turns any new warning into a FTBFS.
	sed -i -e '/ccflags-y += -Werror/d' Kbuild || die

	# ExecStart/ConditionPathExists point at the make-install prefix.  The
	# condition means an unpatched unit never even tries to start.
	sed -i -e "s|/usr/local/bin/|${EPREFIX}/usr/bin/|g" \
		greenboost-netd.service || die
}

src_compile() {
	local modlist=( greenboost=:::all )
	local modargs=(
		# KV_OUT_DIR, not KERNEL_DIR: the eclass may repoint the build tree
		# (extmod-build) and users may build the kernel out of source.
		KDIR="${KV_OUT_DIR}"

		# NVTX is header-only from CUDA 12 on, but the Makefile still adds
		# -lnvToolsExt, which no longer ships -> the shim fails to link.
		USE_NVTX=0

		# Both probe the build host otherwise.
		BPF=$(usex bpf 1 0)
		HAS_32BIT_HEADERS=$(usex abi_x86_32 1 0)

		# greenboost_audit.c bakes this in as SHIM_PATH and dlopen()s it at
		# runtime; the default is the /usr/local tree "make install" uses.
		SHIM_INSTALL_PATH="${EPREFIX}/usr/$(get_libdir)/libgreenboost_cuda.so"
	)

	linux-mod-r1_src_compile
}

src_install() {
	linux-mod-r1_src_install

	dolib.so libgreenboost_cuda.so libgreenboost_audit.so \
		libgreenboost_netd_capture.so
	# Only built when CUDA headers were found.
	if [[ -f libgreenboost_vmm_override.so ]]; then
		dolib.so libgreenboost_vmm_override.so
	fi
	if use abi_x86_32 && [[ -f libgreenboost_audit32.so ]]; then
		insinto /usr/lib32
		newins libgreenboost_audit32.so libgreenboost_audit.so
	fi

	dobin greenboost-netd
	if use bpf; then
		dobin greenboost-ebpf-trace
	fi

	# greenboost-netd.service lists this in ReadWritePaths=, and a missing
	# path there fails the unit's mount namespace outright.
	keepdir /etc/greenboost

	# greenboost-boot-guard.service is deliberately not installed: it exists to
	# rebuild the module via DKMS after a kernel upgrade, which portage already
	# handles, and its ExecStart script is not part of this install anyway.
	systemd_dounit greenboost-netd.service

	# Every parameter defaults to auto-detect (0 / -1).  The tuned line that
	# tatsh-overlay shipped is kept as an example but stays commented out: it
	# describes one specific machine (24 GB card, 82 GB NVMe pool where
	# upstream's default is 0/disabled), and its pcores_only= is not a module
	# parameter at all, so the kernel refuses to load the module with it set.
	cat > "${T}"/greenboost.conf <<-EOF || die
		# GreenBoost module parameters - all default to auto-detect (0 / -1).
		# Uncomment and adjust for your own hardware; the example below is a
		# 24 GB card with an 82 GB NVMe tier (nvme_pool_gb is 0/off upstream).
		#options greenboost physical_vram_gb=23 virtual_vram_gb=40 safety_reserve_gb=9 nvme_pool_gb=82
		# CPU pinning, if wanted: pcores_max_cpu=15 golden_cpu_min=0 golden_cpu_max=3
	EOF
	insinto /etc/modprobe.d
	doins "${T}"/greenboost.conf

	cat > "${T}"/greenboost.sh <<-EOF || die
		export GREENBOOST_SHIM="${EPREFIX}/usr/$(get_libdir)/libgreenboost_cuda.so"
	EOF
	insinto /etc/profile.d
	doins "${T}"/greenboost.sh

	cat > "${T}"/greenboost-run <<-EOF || die
		#!/usr/bin/env bash
		exec env LD_PRELOAD="${EPREFIX}/usr/$(get_libdir)/libgreenboost_cuda.so" "\$@"
	EOF
	newbin "${T}"/greenboost-run greenboost-run

	cat > "${T}"/99-greenboost.rules <<-'EOF' || die
		# GreenBoost kernel module - let the video group reach /dev/greenboost
		KERNEL=="greenboost", GROUP="video", MODE="0660"
	EOF
	udev_dorules "${T}"/99-greenboost.rules

	dodoc CHANGELOG.md DOCUMENTATION.md GREENBOOST_COMMANDS.md README.md
}

pkg_postinst() {
	linux-mod-r1_pkg_postinst
	udev_reload

	elog "Module parameters are all left at auto-detect.  Tune them in"
	elog "  ${EROOT}/etc/modprobe.d/greenboost.conf"
	elog "before enabling the NVMe tier (nvme_pool_gb), which is off by default."
	elog
	elog "Preload the CUDA shim into a process with:"
	elog "  greenboost-run <command>"
	elog "or, for a service, add to its unit:"
	elog "  Environment=\"LD_PRELOAD=${EPREFIX}/usr/$(get_libdir)/libgreenboost_cuda.so\""
	elog
	elog "Upstream also tunes the host for the NVMe tier.  None of it is"
	elog "installed - nothing here touches your VM or I/O settings.  If you want"
	elog "it, ${EROOT}/etc/sysctl.d/99-greenboost.conf:"
	elog "  vm.swappiness = 5"
	elog "  vm.dirty_ratio = 20"
	elog "  vm.dirty_background_ratio = 5"
	elog "and ${EROOT}/etc/udev/rules.d/99-nvme-greenboost.rules, which applies"
	elog "to every NVMe namespace on the box, not just the one holding the tier:"
	elog "  ACTION==\"add|change\", KERNEL==\"nvme[0-9]n[0-9]\", ATTR{queue/scheduler}=\"none\""
	elog "  ACTION==\"add|change\", KERNEL==\"nvme[0-9]n[0-9]\", ATTR{queue/read_ahead_kb}=\"4096\""
	elog "  ACTION==\"add|change\", KERNEL==\"nvme[0-9]n[0-9]\", ATTR{queue/nr_requests}=\"2048\""
}

pkg_postrm() {
	udev_reload
}
