# IXINSXML.pm: output IXIN with Texinfo tree content converted to SXML.
#
# Copyright 2013-2024 Free Software Foundation, Inc.
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
#
#
# This modules combines the Texinfo::Convert::IXIN module which
# outputs the IXIN format and the Texinfo::Convert::TexinfoSXML
# Texinfo tree converter, which converts Texinfo, and is called
# from Texinfo::Convert::IXIN, to obtain a functional IXIN format
# conversion implementation that can be called as a Texinfo converter.
# See comments at the beginning of IXIN.pm for more information.

package Texinfo::Convert::IXINSXML;

use 5.006;
use strict;

use Texinfo::Convert::TexinfoSXML;
use Texinfo::Convert::IXIN;

use Carp qw(cluck);

our @ISA = qw(Texinfo::Convert::TexinfoSXML Texinfo::Convert::IXIN);

our $VERSION = '7.2';


my %defaults = (
  # Customization option variables
  'FORMAT_MENU'          => 'menu',
  'EXTENSION'            => 'ixin',
  'OUTPUT_ENCODING_NAME' => 'utf-8',
  'SPLIT'                => '',
  'documentlanguage'     => 'en',
  'USE_NODES'            => 1,
);

sub converter_defaults($$)
{
  return \%defaults;
}

sub converter_initialize($) {
  my $self = shift;

  # need to call parent module converter_initialize, to initialize
  # the converter state.  This method is actually implemented in
  # the Texinfo::Convert::TexinfoSXML parent class.
  $self->SUPER::converter_initialize(@_);
}

sub output($$)
{
  my $self = shift;
  my $document = shift;

  return $self->output_ixin($document);
}

1;
