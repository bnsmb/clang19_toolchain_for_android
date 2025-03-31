# PlainTexinfo.pm: convert the Texinfo tree as Texinfo
#
# Copyright 2012-2024 Free Software Foundation, Inc.
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
#
# Original author: Patrice Dumas <pertusus@free.fr>

# This calls Texinfo::Convert::Texinfo::convert_to_texinfo while
# inheriting standard functions from Texinfo::Convert::Converter.

package Texinfo::Convert::PlainTexinfo;

use 5.006;
use strict;

use Texinfo::Convert::ConvertXS;
use Texinfo::XSLoader;

use Texinfo::Convert::Texinfo;
use Texinfo::Convert::Converter;

our @ISA = qw(Texinfo::Convert::Converter);

our $VERSION = '7.2';

my $XS_convert = Texinfo::XSLoader::XS_convert_enabled();

our $module_loaded = 0;
sub import {
  if (!$module_loaded) {
    if ($XS_convert) {
      # We do not simply override, we must check at runtime
      # that the document tree was stored by the XS parser.
      Texinfo::XSLoader::override(
        "Texinfo::Convert::PlainTexinfo::_convert_tree_with_XS",
        "Texinfo::Convert::ConvertXS::plain_texinfo_convert_tree"
      );
    }
    $module_loaded = 1;
  }
  # The usual import method
  goto &Exporter::import;
}


my %defaults = (
  # Customization option variables
  'EXTENSION'            => 'texi',
  # different from the default, which is undef
  'OUTFILE'              => '-',
);

sub converter_defaults($$)
{
  return \%defaults;
}

sub _convert_tree_with_XS($)
{
}

sub convert_tree($$)
{
  my $self = shift;
  my $root = shift;

  if ($XS_convert and defined($root->{'tree_document_descriptor'})
      and $Texinfo::Convert::ConvertXS::XS_package) {
    return _convert_tree_with_XS($root);
  }

  return Texinfo::Convert::Texinfo::convert_to_texinfo($root);
}

sub output($$)
{
  my $self = shift;
  my $document = shift;

  return $self->output_tree($document);
}

sub convert($$)
{
  my $self = shift;
  my $document = shift;

  my $root = $document->tree();

  return $self->convert_tree($root);
}

1;
