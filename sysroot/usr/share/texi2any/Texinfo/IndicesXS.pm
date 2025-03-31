# Indices.pm: load indices XS
# Copyright 2023-2024 Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License,
# or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Texinfo::IndicesXS;

use strict;
use warnings;

our $VERSION = '7.2';

use Texinfo::XSLoader;

BEGIN {
  if (Texinfo::XSLoader::XS_convert_enabled()) {
    Texinfo::XSLoader::init (
      "Texinfo::IndicesXS",
      undef,
      "IndicesXS",
      undef,
      ['texinfo', 'texinfoxs', 'texinfo-convert', 'texinfo-convertxs'],
    );
  }
}

# NB Don't add more functions down here, because this can cause an error
# with some versions of Perl, connected with any typeglob assignments done
# above.  ("Can't call mro_method_changed_in() on anonymous symbol table").
#
# See http://perl5.git.perl.org/perl.git/commitdiff/03d9f026ae253e9e69212a3cf6f1944437e9f070?hp=ac73ea1ec401df889d312b067f78b618f7ffecc3
#
# (change to Perl interpreter on 22 Oct 2011)


1;
__END__
