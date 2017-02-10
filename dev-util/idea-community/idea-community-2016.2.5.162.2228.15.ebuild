# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5
inherit eutils linux-info versionator

SLOT="0"
PV_STRING="$(get_version_component_range 4-6)"
MY_PV="$(get_version_component_range 1-3)"
MY_PN="idea"

if [[ "${PN}" = "idea-ultimate" ]]
then
	MY_EDITION="IU"
	MY_EDITION_FULL="(Ultimate Edition)"
else
	MY_EDITION="IC"
	MY_EDITION_FULL="(Community Edition)"
fi

# distinguish settings for official stable releases and EAP-version releases
if [[ "$(get_version_component_range 7)x" = "prex" ]]
then
	# upstream EAP
	KEYWORDS=""
	SRC_URI="https://download.jetbrains.com/idea/${MY_PN}${MY_EDITION}-${PV_STRING}.tar.gz"
else
	# upstream stable
	KEYWORDS="~amd64 ~x86"
	SRC_URI="https://download.jetbrains.com/idea/${MY_PN}${MY_EDITION}-${MY_PV}.tar.gz -> ${MY_PN}${MY_EDITION}-${PV_STRING}.tar.gz"
fi

DESCRIPTION="A complete toolset for web, mobile and enterprise development"
HOMEPAGE="https://www.jetbrains.com/idea"

LICENSE="IDEA"
IUSE="+custom-jdk"

#https://intellij-support.jetbrains.com/hc/en-us/articles/206544879-Selecting-the-JDK-version-the-IDE-will-run-under
DEPEND="!dev-util/${PN}:14
	!dev-util/${PN}:15"
RDEPEND="${DEPEND}
	>=virtual/jdk-1.8:*"
S="${WORKDIR}/${MY_PN}-${MY_EDITION}-${PV_STRING}"

QA_PREBUILT="opt/${PN}-${MY_PV}/*"

CONFIG_CHECK="~INOTIFY_USER"

src_prepare() {
	if ! use amd64; then
		rm -r lib/libpty/linux/x86_64 || die
		rm -f bin/fsnotifier64 bin/libbreakgen64.so bin/idea64.vmoptions || die
		if [[ "${MY_EDITION}" == "IU" ]]
		then
			rm -r plugins/tfsIntegration/lib/native/linux/x86_64 || die
		fi
	fi
	if ! use x86; then
		rm -r lib/libpty/linux/x86 || die
		rm -f bin/fsnotifier bin/libbreakgen.so bin/idea.vmoptions || die
		if [[ "${MY_EDITION}" == "IU" ]]
		then
			rm -r plugins/tfsIntegration/lib/native/linux/x86 || die
		fi
	fi
	rm -f bin/fsnotifier-arm || die
	rm -r lib/libpty/{win,macosx} || die
	rm Install-Linux-tar.txt || die
	if [[ "${MY_EDITION}" == "IU" ]]
	then
		rm -r plugins/tfsIntegration/lib/native/{aix,freebsd,hpux,macosx,solaris,win32} || die
		rm -r plugins/tfsIntegration/lib/native/linux/{arm,ppc} || die
	fi

	if ! use custom-jdk; then
		if [[ -d jre ]]; then
			rm -r jre || die
		fi
	fi
}

src_install() {
	local dir="/opt/${PN}-${MY_PV}"

	insinto "${dir}"
	doins -r *
	fperms 755 "${dir}/bin/${MY_PN}.sh" "${dir}/bin/inspect.sh"

	if use amd64; then
		fperms 755 "${dir}/bin/fsnotifier64"
	fi
	if use x86; then
		fperms 755 "${dir}/bin/fsnotifier"
	fi

	if use custom-jdk; then
		for jrefile in java jjs keytool orbd pack200 policytool rmid rmiregistry servertool tnameserv unpack200; do
			fperms 755 "${dir}/jre/jre/bin/${jrefile}"
		done
	fi

	newicon "bin/idea.png" "${PN}.png"
	make_wrapper "${PN}" "${dir}/bin/${MY_PN}.sh"

	#https://confluence.jetbrains.com/display/IDEADEV/Inotify+Watches+Limit
	mkdir -p "${D}/etc/sysctl.d/"
	echo "fs.inotify.max_user_watches = 524288" > "${D}/etc/sysctl.d/30-${PN}-inotify-watches.conf"

	make_desktop_entry ${PN} "IntelliJ IDEA ${MY_EDITION_FULL}" "${PN}" "Development;IDE"
}

pkg_postinst() {
	sysctl fs.inotify.max_user_watches=524288 >/dev/null
}