# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: cargo.eclass
# @MAINTAINER:
# rust@gentoo.org
# @AUTHOR:
# Doug Goldstein <cardoe@gentoo.org>
# @SUPPORTED_EAPIS: 6 7
# @BLURB: common functions and variables for cargo builds

if [[ -z ${_CARGO_ECLASS} ]]; then
_CARGO_ECLASS=1

# we need this for 'cargo vendor' subcommand and net.offline config knob
RUST_DEPEND=">=virtual/rust-1.37.0"

case ${EAPI} in
	6) DEPEND="${RUST_DEPEND}";;
	7) BDEPEND="${RUST_DEPEND}";;
	*) die "EAPI=${EAPI:-0} is not supported" ;;
esac

inherit multiprocessing

EXPORT_FUNCTIONS src_unpack src_compile src_install src_test

IUSE="${IUSE} debug"

ECARGO_HOME="${WORKDIR}/cargo_home"
ECARGO_VENDOR="${ECARGO_HOME}/gentoo"

# @ECLASS-VARIABLE: CARGO_INSTALL_PATH
# @DESCRIPTION:
# Allows overriding the default cwd to run cargo install from
: ${CARGO_INSTALL_PATH:=.}

# @FUNCTION: cargo_crate_uris
# @DESCRIPTION:
# Generates the URIs to put in SRC_URI to help fetch dependencies.
cargo_crate_uris() {
	local crate
	for crate in "$@"; do
		local name version url pretag
		name="${crate%-*}"
		version="${crate##*-}"
		pretag="^[a-zA-Z]+"
		if [[ $version =~ $pretag ]]; then
			version="${name##*-}-${version}"
			name="${name%-*}"
		fi
		url="https://crates.io/api/v1/crates/${name}/${version}/download -> ${crate}.crate"
		echo "${url}"
	done
}

# @FUNCTION: cargo_src_unpack
# @DESCRIPTION:
# Unpacks the package and the cargo registry
cargo_src_unpack() {
	debug-print-function ${FUNCNAME} "$@"

	mkdir -p "${ECARGO_VENDOR}" || die
	mkdir -p "${S}" || die

	local archive shasum pkg
	for archive in ${A}; do
		case "${archive}" in
			*.crate)
				ebegin "Loading ${archive} into Cargo registry"
				tar -xf "${DISTDIR}"/${archive} -C "${ECARGO_VENDOR}/" || die
				# generate sha256sum of the crate itself as cargo needs this
				shasum=$(sha256sum "${DISTDIR}"/${archive} | cut -d ' ' -f 1)
				pkg=$(basename ${archive} .crate)
				cat <<- EOF > ${ECARGO_VENDOR}/${pkg}/.cargo-checksum.json
				{
					"package": "${shasum}",
					"files": {}
				}
				EOF
				# if this is our target package we need it in ${WORKDIR} too
				# to make ${S} (and handle any revisions too)
				if [[ ${P} == ${pkg}* ]]; then
					tar -xf "${DISTDIR}"/${archive} -C "${WORKDIR}" || die
				fi
				eend $?
				;;
			cargo-snapshot*)
				ebegin "Unpacking ${archive}"
				mkdir -p "${S}"/target/snapshot
				tar -xzf "${DISTDIR}"/${archive} -C "${S}"/target/snapshot --strip-components 2 || die
				# cargo's makefile needs this otherwise it will try to
				# download it
				touch "${S}"/target/snapshot/bin/cargo || die
				eend $?
				;;
			*)
				unpack ${archive}
				;;
		esac
	done

	cargo_gen_config
}

# @FUNCTION: cargo_live_src_unpack
# @DESCRIPTION:
# Runs 'cargo fetch' and vendors downloaded crates for offline use, used in live ebuilds

cargo_live_src_unpack() {
	debug-print-function ${FUNCNAME} "$@"

	[[ "${PV}" == *9999* ]] || die "${FUNCNAME} only allowed in live/9999 ebuilds"
	[[ "${EBUILD_PHASE}" == unpack ]] || die "${FUNCNAME} only allowed in src_unpack"

	mkdir -p "${S}" || die

	pushd "${S}" > /dev/null || die
	CARGO_HOME="${ECARGO_HOME}" cargo fetch || die
	CARGO_HOME="${ECARGO_HOME}" cargo vendor "${ECARGO_VENDOR}" || die
	popd > /dev/null || die

	cargo_gen_config
}

# @FUNCTION: cargo_gen_config
# @DESCRIPTION:
# Generate the $CARGO_HOME/config necessary to use our local registry and settings.
# Cargo can also be configured through environment variables in addition to the TOML syntax below.
# For each configuration key below of the form foo.bar the environment variable CARGO_FOO_BAR
# can also be used to define the value.
# Environment variables will take precedent over TOML configuration,
# and currently only integer, boolean, and string keys are supported.
# For example the build.jobs key can also be defined by CARGO_BUILD_JOBS.
# Or setting CARGO_TERM_VERBOSE=false in make.conf will make build quieter.
cargo_gen_config() {
	debug-print-function ${FUNCNAME} "$@"

	cat <<- EOF > "${ECARGO_HOME}/config"
	[source.gentoo]
	directory = "${ECARGO_VENDOR}"

	[source.crates-io]
	replace-with = "gentoo"
	local-registry = "/nonexistant"

	[net]
	offline = true

	[build]
	jobs = $(makeopts_jobs)

	[term]
	verbose = true
	EOF
	# honor NOCOLOR setting
	[[ "${NOCOLOR}" = true || "${NOCOLOR}" = yes ]] && echo "color = 'never'" >> "${ECARGO_HOME}/config"
}

# @FUNCTION: cargo_src_compile
# @DESCRIPTION:
# Build the package using cargo build
cargo_src_compile() {
	debug-print-function ${FUNCNAME} "$@"

	export CARGO_HOME="${ECARGO_HOME}"

	cargo build $(usex debug "" --release) "$@" \
		|| die "cargo build failed"
}

# @FUNCTION: cargo_src_install
# @DESCRIPTION:
# Installs the binaries generated by cargo
cargo_src_install() {
	debug-print-function ${FUNCNAME} "$@"

	cargo install --path ${CARGO_INSTALL_PATH} \
		--root="${ED}/usr" $(usex debug --debug "") "$@" \
		|| die "cargo install failed"
	rm -f "${ED}/usr/.crates.toml"

	[ -d "${S}/man" ] && doman "${S}/man" || return 0
}

# @FUNCTION: cargo_src_test
# @DESCRIPTION:
# Test the package using cargo test
cargo_src_test() {
	debug-print-function ${FUNCNAME} "$@"

	cargo test $(usex debug "" --release) "$@" \
		|| die "cargo test failed"
}

fi
