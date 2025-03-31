# TexinfoSXML.pm: output tree as Texinfo SXML.
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
# A simple subclass of the Texinfo::Convert::TexinfoMarkup abstract
# class.  Defines format specific functions.

package Texinfo::Convert::TexinfoSXML;

use 5.006;
use strict;

use Texinfo::Convert::TexinfoMarkup;
use Carp qw(cluck);

our @ISA = qw(Texinfo::Convert::TexinfoMarkup);

our $VERSION = '7.2';


# SXML specific
my %defaults = (
  # Customization option variables
  'FORMAT_MENU'          => 'menu',
  'EXTENSION'            => 'sxml',
  'OUTPUT_ENCODING_NAME' => 'utf-8',
  'SPLIT'                => '',
  'documentlanguage'     => 'en',
);

sub converter_defaults($$)
{
  return \%defaults;
}

# TODO protect formfeeds, end of lines and other special spaces as in TexinfoXML?
sub txi_markup_protect_text($$)
{
  my $self = shift;
  my $string = shift;
  $string =~ s/\\/\\\\/g;
  $string =~ s/"/\\"/g;
  return $string;
}

sub _sxml_attributes($$)
{
  my $self = shift;
  my $attributes = shift;
  if (ref($attributes) ne 'ARRAY') {
    cluck "attributes not an array($attributes).";
  }
  my $result = '(@';
  foreach my $attribute_spec (@$attributes) {
    if (ref($attribute_spec) ne 'ARRAY') {
      cluck "attribute_spec not an array($attribute_spec).";
    }

    $result .= " ($attribute_spec->[0] \"".
          $self->txi_markup_protect_text($attribute_spec->[1])."\")";
  }
  return $result . ')';
}

sub txi_markup_element($$$)
{
  my $self = shift;
  my $element_name = shift;
  my $attributes = shift;
  my $result = '('.$element_name." ";
  $attributes = [] if (!defined($attributes));
  $result .= $self->_sxml_attributes($attributes);
  $result .= ')';
  return $result;
}

sub txi_markup_open_element($$$)
{
  my $self = shift;
  my $element_name = shift;
  my $attributes = shift;
  my $result = '('.$element_name." ";
  $attributes = [] if (!defined($attributes));
  $result .= $self->_sxml_attributes($attributes);
  $result .= " ";
  return $result;
}

sub txi_markup_close_element($$)
{
  my $self = shift;
  my $element_name = shift;
  my $result= ')';
  return $result;
}

my %no_arg_commands_formatting
  = %Texinfo::Convert::TexinfoMarkup::no_arg_commands_formatting;

# format specific
sub txi_markup_atom($$)
{
  my $self = shift;
  my $atom = shift;
  if ($no_arg_commands_formatting{$atom} ne '') {
    return '('.$no_arg_commands_formatting{$atom}.' (@))';
  } else {
    return '';
  }
}

# TODO is there a way to mark comments in SXML?
sub txi_markup_comment($$)
{
  my $self = shift;
  my $string = shift;

  return '';
}

sub txi_markup_convert_text($$)
{
  my $self = shift;
  my $element = shift;
  my $result = $self->txi_markup_protect_text($element->{'text'});
  if (! defined($element->{'type'}) or $element->{'type'} ne 'raw') {
    if (!$self->in_monospace()) {
      $result =~ s/``/" (textldquo (@)) "/g;
      $result =~ s/\'\'/" (textrdquo (@)) "/g;
      $result =~ s/---/" (textmdash (@)) "/g;
      $result =~ s/--/" (textndash (@)) "/g;
      $result =~ s/'/" (textrsquo (@)) "/g;
      $result =~ s/`/" (textlsquo (@)) "/g;
    }
  }
  return '"'.$result.'" ';
}

sub txi_markup_header($)
{
  my $self = shift;
  my $output_file = shift;
  my $output_filename = shift;

  my $header = '';
  #my $encoding = '';
  #if ($self->get_conf('OUTPUT_ENCODING_NAME')
  #    and $self->get_conf('OUTPUT_ENCODING_NAME') ne 'utf-8') {
  #  $encoding = $self->get_conf('OUTPUT_ENCODING_NAME');
  #}
  return $header;
}

1;
