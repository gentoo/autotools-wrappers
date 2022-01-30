#!/bin/sh
# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Based on the ac-wrapper.pl script provided by MandrakeSoft
# Rewritten in bash by Gregorio Guidi
#
# Executes the correct autoconf version.
#
# - defaults to newest version available (hopefully autoconf-2.60)
# - runs autoconf 2.13 if:
#   - envvar WANT_AUTOCONF is set to `2.1'
#     -or-
#   - `ac{local,include}.m4' or `configure.{in,ac}' have AC_PREREQ(2.1) (not higher)
#     -or-
#   - `configure' is already present and was generated by autoconf 2.13

(set -o posix) 2>/dev/null && set -o posix

_stderr() { printf 'ac-wrapper: %s: %b\n' "${argv0}" "$*" 1>&2; }
warn() { _stderr "warning: $*"; }
err() { _stderr "error: $*"; exit 1; }
unset IFS
which() {
	local p
	IFS=: # we don't use IFS anywhere, so don't bother saving/restoring
	for p in ${PATH} ; do
		p="${p}/$1"
		[ -e "${p}" ] && echo "${p}" && return 0
	done
	unset IFS
	return 1
}

#
# Sanitize argv[0] since it isn't always a full path #385201
#
argv0=${0##*/}
case $0 in
	${argv0})
		# find it in PATH
		if ! full_argv0=$(which "${argv0}") ; then
			err "could not locate ${argv0}; file a bug"
		fi
		;;
	*)
		# re-use full/relative paths
		full_argv0=$0
		;;
esac

if [ "${WANT_AUTOCONF}" = "2.1" ] && [ "${argv0}" = "autom4te" ] ; then
	err "Autoconf 2.13 doesn't contain autom4te.\n" \
	    "   Either unset WANT_AUTOCONF or don't execute anything\n" \
	    "   that would use autom4te."
fi

if ! seq 0 0 2>/dev/null 1>&2 ; then #338518
	seq() {
		local f l i
		case $# in
			1) f=1 i=1 l=$1;;
			2) f=$1 i=1 l=$2;;
			3) f=$1 i=$2 l=$3;;
		esac
		while :; do
			[ $l -lt $f -a $i -gt 0 ] && break
			[ $f -lt $l -a $i -lt 0 ] && break
			echo $f
			: $(( f += i ))
		done
		return 0
	}
fi

#
# Set up bindings between actual version and WANT_AUTOCONF;
# Start at last known unstable/stable versions to speed up lookup process.
#
KNOWN_AUTOCONF="2.71 2.70 2.69"
vers="${KNOWN_AUTOCONF} 9999 $(printf '2.%s ' `seq 99 -1 59`) 2.13"

#
# Helper to scan for a usable program based on version.
#
binary=
all_vers=
find_binary() {
	local v
	all_vers="${all_vers} $*" # For error messages.
	for v ; do
		if [ "${v}" = "2.1" ] ; then
			v="2.13"
		fi
		if [ -x "${full_argv0}-${v}" ] ; then
			binary="${full_argv0}-${v}"
			binary_ver=${v}
			return 0
		fi
	done
	return 1
}

#
# Check the WANT_AUTOCONF setting.  We accept a whitespace delimited
# list of autoconf versions.
#
find_latest() {
	find_binary ${vers}
}
for wx in ${WANT_AUTOCONF:-latest} ; do
	if [ "${wx}" = "latest" ] || [ "${wx}" = "2.5" ] ; then
		find_latest && break
	else
		find_binary ${wx} && break
	fi
done

if [ -z "${binary}" ] && [ -n "${WANT_AUTOCONF}" ] ; then
	warn "could not locate installed version for WANT_AUTOCONF='${WANT_AUTOCONF}'; ignoring"
	unset WANT_AUTOCONF
	find_latest
fi

if [ -z "${binary}" ] ; then
	err "Unable to locate any usuable version of autoconf.\n" \
	    "\tI tried these versions:${all_vers}\n" \
	    "\tWith a base name of '${full_argv0}'."
fi

#
# autodetect helpers
#
acprereq_version() {
	sed -n -E \
		-e '/^\s*(#|dnl)/d' \
		-e '/AC_PREREQ/s:.*AC_PREREQ\s*\(\[?\s*([0-9.]+)\s*\]?\):\1:p' \
		"$@" |
	LC_ALL=C sort -n -t . |
	tail -1
}

generated_version() {
	local re='^# Generated (by (GNU )?Autoconf|automatically using autoconf version) ([0-9.]+).*'
	sed -n -E "/${re}/{s:${re}:\3:;p;q}" "$@"
}

recorded_aclocal_version() {
	local re='.*m4_warning.*this file was generated for autoconf ([0-9].+)\..*'
	sed -n -E "/${re}/{s:${re}:\1:;p;q}" "$@"
}

#
# autodetect routine
#
if [ -z "${WANT_AUTOCONF}" ] ; then
	auto_vers=
	if [ -r "configure" ] ; then
		auto_vers="${auto_vers} $(generated_version configure)"
	fi
	if [ -r "aclocal.m4" ] ; then
		auto_vers="${auto_vers} $(recorded_aclocal_version aclocal.m4)"
	fi
	# We don't need to set $binary here as it has already been setup for us
	# earlier to the latest available version.
	if [ -n "${auto_vers}" ] ; then
		if ! find_binary ${auto_vers} ; then
			warn "auto-detected versions not found (${auto_vers}); falling back to latest available"
		fi
	fi
fi

if [ "${WANT_AUTOCONF}" = "2.1" -o "${WANT_AUTOCONF}" = "2.13" ] && [ -f "configure.ac" ] ; then
	err \
		"Since configure.ac is present, aclocal will always use autoconf 2.59+\n" \
		"\twhich conflicts with your choice and causes errors. You have two options:\n" \
		"\t1. Try executing the command again after removing configure.ac\n" \
		"\t2. Don't set WANT_AUTOCONF (currently set to '${WANT_AUTOCONF}')"
fi

if [ "${WANT_AUTOCONF:-2.1}" = "2.1" ] && [ -n "${WANT_AUTOMAKE}" ] ; then
	# Automake-1.7 and better require autoconf-2.5x so if WANT_AUTOMAKE
	# is set to an older version, let's do some sanity checks.
	case "${WANT_AUTOMAKE}" in
	1.[456])
		acfiles=$(ls aclocal.m4 acinclude.m4 configure.in configure.ac 2>/dev/null)
		[ -n "${acfiles}" ] && confversion=$(acprereq_version ${acfiles})

		[ -z "${confversion}" ] && [ -r "configure" ] \
			&& confversion=$(generated_version configure)

		if [ "${confversion}" = "2.1" ] && [ ! -f "configure.ac" ] ; then
			binary="${full_argv0}-2.13"
		fi
	esac
fi

if [ -n "${WANT_ACWRAPPER_DEBUG}" ] ; then
	if [ -n "${WANT_AUTOCONF}" ] ; then
		warn "DEBUG: WANT_AUTOCONF is set to ${WANT_AUTOCONF}"
	fi
	warn "DEBUG: will execute <${binary}>"
fi

#
# for further consistency
#
export WANT_AUTOCONF="${binary_ver}"

#
# Now try to run the binary
#
if [ ! -x "${binary}" ] ; then
	# this shouldn't happen
	err "${binary} is missing or not executable.\n" \
	    "\tPlease try installing the correct version of autoconf."
fi

exec "${binary}" "$@"
# The shell will error out if `exec` failed.
