#!/usr/bin/perl
#
#
# Guillaume Cottenceau (gc@mandrakesoft.com)
#
# Copyright 2001 MandrakeSoft
#
# This software may be freely redistributed under the terms of the GNU
# public license.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#
# Executes the correct autoconf version.
#
# - defaults to automake-1.4
# - runs automake-1.6x if it exists and...
#   - envvar WANT_AUTOMAKE_1_6 is set to `1'
#     -or-
#   - configure.ac is present
#     -or-
#   - `configure.in' contains AC_PREREQ and the value's 3 first letters
#     are stringwise greater than '2.1'
#

#use MDK::Common;

sub cat_ { local *F; open F, $_[0] or return; my @l = <F>; wantarray ? @l : join '', @l }

my $binary     = "$0-1.4";
my $binary_new = "$0-1.6x";

if (!$ENV{WANT_AUTOMAKE_1_4}) {
    if (-x $binary_new                  # user may have only 2.13
	&& ($ENV{WANT_AUTOMAKE_1_6}
	    || -r 'configure.ac'
	    || (cat_('configure.in') =~ /^\s*AC_PREREQ\(\[?([^\)]{3})[^\)]*\)/m ? $1 : '') gt '2.1' 
	    || (cat_('aclocal.m4') =~ /^\s*AC_PREREQ\(\[?([^\)]{3})[^\)]*\)/m ? $1 : '') gt '2.1')) {
	$ENV{WANT_AUTOMAKE_1_6} = 1;    # to prevent further "cats" and to enhance consistency (possible cwd etc)
	$binary 		= $binary_new;
    } else {
	$ENV{WANT_AUTOMAKE_1_4} = 1;    # for further consistency
    }
}

$ENV{WANT_AMWRAPPER_DEBUG} and print STDERR "am-wrapper: will execute <$binary>\n";

exec $binary, @ARGV;

die "am-wrapper: ouch, couldn't call binary ($binary).\n";
