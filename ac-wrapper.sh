#!/bin/bash
# Copyright 1999-2004 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-devel/autoconf-wrapper/files/ac-wrapper-1.sh,v 1.2 2004/12/05 09:06:57 vapier Exp $

# Based on the ac-wrapper.pl script provided by MandrakeSoft
# Rewritten in bash by Gregorio Guidi
#
# Executes the correct autoconf version.
#
# - defaults to latest version (2.5x)
# - runs autoconf 2.13 only if:
#   - envvar WANT_AUTOCONF is set to `2.1'
#     -or-
#   - `configure' is already present and was generated by autoconf 2.13

if [ "${0##*/}" = "ac-wrapper.sh" ] ; then
	echo "Don't call this script directly" >&2
	exit 1
fi

if [ "${WANT_AUTOCONF}" = "2.1" -a "${0##*/}" = "autom4te" ] ; then
	echo "ac-wrapper: Autoconf 2.13 doesn't contain autom4te." >&2
	echo "            Either unset WANT_AUTOCONF or don't execute anything" >&2
	echo "            that would use autom4te." >&2
	exit 1
fi

binary_new="${0}-2.59"
binary_old="${0}-2.13"
binary="${binary_new}"

#
# autodetect routine
#
if [ "${WANT_AUTOCONF}" != "2.5" ] ; then 
	if [ "${WANT_AUTOCONF}" = "2.1" ] ; then
		if [ ! -f "configure.ac" ] ; then
			binary="${binary_old}"
		else
			echo "ac-wrapper: Since configure.ac is present, aclocal always use" >&2
			echo "            autoconf 2.59, which conflicts with your choice and" >&2
			echo "            causes error. You have two options:" >&2
			echo "            1. Try execute command again after removing configure.ac" >&2
			echo "            2. Don't set WANT_AUTOCONF" >&2
			exit 1
		fi
	else
		if [ -r "configure" ] ; then
			confversion=$(awk \
				'{
				if (match($0,
				          "^# Generated (by (GNU )?Autoconf|automatically using autoconf version) ([0-9].[0-9])",
				          res))
					{ print res[3]; exit }
				}' configure)
		fi
		if [ "${confversion}" = "2.1" -a ! -f "configure.ac" ] ; then
			binary="${binary_old}"
		fi
	fi
fi

if [ "${WANT_ACWRAPPER_DEBUG}" ] ; then
	if [ -n "${WANT_AUTOCONF}" ] ; then
		echo "ac-wrapper: DEBUG: WANT_AUTOCONF is set to ${WANT_AUTOCONF}" >&2
	fi
	echo "ac-wrapper: DEBUG: will execute <$binary>" >&2
fi

#
# for further consistency
#
if [ "$binary" = "$binary_new" ] ; then
	export WANT_AUTOCONF="2.5"
elif [ "$binary" = "$binary_old" ] ; then
	export WANT_AUTOCONF="2.1"
fi

if [ ! -x "$binary" ] ; then
	# this shouldn't happen
	echo "ac-wrapper: $binary is missing or not executable." >&2
	echo "            Please try emerging the correct version of autoconf." >&2
	exit 1
fi

exec "$binary" "$@"

echo "ac-wrapper: was unable to exec $binary !?" >&2
exit 1
