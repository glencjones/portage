# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{5,6,7} )
inherit distutils-r1

DESCRIPTION="X2Go graphical client applet"
HOMEPAGE="http://www.x2go.org"
SRC_URI="http://code.x2go.org/releases/source/${PN}/${P}.tar.gz"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND="dev-python/pycups[${PYTHON_USEDEP}]
	dev-python/setproctitle[${PYTHON_USEDEP}]
	dev-python/wxpython[${PYTHON_USEDEP}]
	>=net-misc/python-x2go-0.6.1.1[${PYTHON_USEDEP}]
	x11-libs/libnotify"
DEPEND="${DEPEND}
	dev-python/python-distutils-extra[${PYTHON_USEDEP}]"

python_install() {
	distutils-r1_python_install
	python_doscript ${PN}
}

python_install_all() {
	distutils-r1_python_install_all
	doman man/man1/*
	find "${ED}" -name '*.pth' -delete || die
}
