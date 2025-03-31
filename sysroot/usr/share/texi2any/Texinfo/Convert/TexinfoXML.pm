# TexinfoXML.pm: output tree as Texinfo XML.
#
# Copyright 2011-2024 Free Software Foundation, Inc.
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

package Texinfo::Convert::TexinfoXML;

use 5.006;
use strict;

use Carp qw(cluck);

use Texinfo::Convert::TexinfoMarkup;

# for xml formatting methods
use Texinfo::Convert::Converter;

our @ISA = qw(Texinfo::Convert::TexinfoMarkup Texinfo::Convert::Converter);

our $VERSION = '7.2';


# TexinfoXML specific
my %defaults = (
  # Customization option variables
  'FORMAT_MENU'          => 'menu',
  'EXTENSION'            => 'xml',
  'OUTPUT_ENCODING_NAME' => 'utf-8',
  'SPLIT'                => '',
  'documentlanguage'     => 'en',
);

sub converter_defaults($$)
{
  return \%defaults;
}


# Following are XML specific formatting functions.

sub txi_markup_protect_text($$)
{
  my $self = shift;
  my $string = shift;
  return $self->_protect_text($string);
}

my %special_xml_attributes = (
  'documentlanguage' => {'lang' => 'xml:lang'},
  # for preformatted type
  'pre' => {'space' => 'xml:space'},
  'verbatim' => {'space' => 'xml:space'},
);

# Both attributes and CData are defined in term of chars:
# Char is defined as: https://www.w3.org/TR/REC-xml/#charsets
# Char	   ::=   	#x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
# A corresponding character class regexp could be
# [^\x09\x0A\x0D\x20-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]
# or
# [\x00-\x08 \x0B \x0C \x0E-\x19]

# Attributes are defined as https://www.w3.org/TR/REC-xml/#NT-AttValue
# 	AttValue	   ::=   	'"' ([^<&"] | Reference)* '"'
#			|  "'" ([^<&'] | Reference)* "'"
# Reference as https://www.w3.org/TR/REC-xml/#NT-Reference
# Reference	   ::=   	EntityRef | CharRef
# CharRef is defined as https://www.w3.org/TR/REC-xml/#NT-CharRef
# CharRef	   ::=   	'&#' [0-9]+ ';'
#			| '&#x' [0-9a-fA-F]+ ';'
# With the additional constraint that
#   Characters referred to using character references MUST match the production for Char.
# Which means that numerical entities used in attributes should correspond to
# characters in the range of acceptable characters.  For example form feed is not
# in that range, such that both \f and &#12; are invalid.
sub _xml_attributes($$)
{
  my $self = shift;
  my $attributes = shift;
  my $format_element = shift;
  if (ref($attributes) ne 'ARRAY') {
    cluck "attributes not an array($attributes).";
  }
  my $result = '';
  foreach my $attribute_spec (@$attributes) {
    if (ref($attribute_spec) ne 'ARRAY') {
       cluck "attribute_spec not an array($attribute_spec).";
    }
    # _protect_text cannot be used because of formfeed and verticaltab,
    # as they become elements, which are not allowed in attribute.
    #my $text = $self->_protect_text($attribute_spec->[1]);
    my $text = $self->xml_protect_text($attribute_spec->[1]);
    # Form feed/vertical tab U+000B are not allowed at all in XML attributes,
    # even protected (and even in xml 1.1 in contrast to what is said on
    # internet).  Cf above the full explanation for XML 1.0.
    if ($attribute_spec->[0] ne 'spaces'
        and $attribute_spec->[0] ne 'trailingspaces'
        and $attribute_spec->[0] ne 'spacesaftercmd') {
      $text =~ s/\f/&attrformfeed;/g;
      $text =~ s/\N{U+000B}/&attrverticaltab;/g;
      # &attrformfeed; and similar resolves to \f and similar so \ are doubled.
      $text =~ s/\\/\\\\/g;
    } else {
      $text =~ s/\n/\\n/g;
      # protect formfeed in space attributes.  It is necessary for XML 1.0
      # (and most likely XML 1.1).
      $text =~ s/\f/\\f/g;
      # \v does not match U+000B vertical tab, but matches diverse vertical
      # spaces in  perl.  We nevertheless use \v here to represent ^K as
      # is customarily done in other contexts.
      $text =~ s/\N{U+000B}/\\v/g;
    }
    my $attribute_name = $attribute_spec->[0];
    if ($special_xml_attributes{$format_element}
        and $special_xml_attributes{$format_element}->{$attribute_spec->[0]}) {
      $attribute_name
        = $special_xml_attributes{$format_element}->{$attribute_spec->[0]};
    }
    $result .= " $attribute_name=\"".$text."\"";
  }
  return $result;
}

sub txi_markup_element($$$)
{
  my $self = shift;
  my $format_element = shift;
  my $attributes = shift;
  my $result= '<'.$format_element;
  $result .= $self->_xml_attributes($attributes, $format_element)
        if ($attributes);
  $result .= '/>';
  return $result;
}

sub txi_markup_open_element($$$)
{
  my $self = shift;
  my $format_element = shift;
  my $attributes = shift;
  my $result= '<'."$format_element";
  $result .= $self->_xml_attributes($attributes, $format_element)
      if ($attributes);
  $result .= '>';
  return $result;
}

sub txi_markup_close_element($$)
{
  my $self = shift;
  my $format_element = shift;
  my $result= "</$format_element>";
  return $result;
}

my %no_arg_commands_formatting
   = %Texinfo::Convert::TexinfoMarkup::no_arg_commands_formatting;

sub txi_markup_atom($$)
{
  my $self = shift;
  my $atom = shift;
  if ($no_arg_commands_formatting{$atom} ne '') {
    return '&'.$no_arg_commands_formatting{$atom}.';';
  } else {
    return '';
  }
}

sub txi_markup_comment($$)
{
  my $self = shift;
  my $string = shift;

  return $self->xml_comment($string);
}

# form feed is not accepted in xml, replace it.
# The CData symbol is defined in terms of Char: https://www.w3.org/TR/REC-xml/#sec-cdata-sect
# CData	   ::=   	(Char* - (Char* ']]>' Char*))
sub _protect_text($$)
{
  my $self = shift;
  my $text = shift;
  my $result = $self->xml_protect_text($text);
  $result =~ s/\f/&formfeed;/g;
  # \v matches many vertical spaces and not vertical tab U+000B
  $result =~ s/\N{U+000B}/&verticaltab;/g;
  return $result;
}

sub txi_markup_convert_text($$)
{
  my $self = shift;
  my $element = shift;
  my $result = $self->_protect_text($element->{'text'});
  if (! defined($element->{'type'}) or $element->{'type'} ne 'raw') {
    if (!$self->in_monospace()) {
      $result =~ s/``/&textldquo;/g;
      $result =~ s/\'\'/&textrdquo;/g;
      $result =~ s/---/&textmdash;/g;
      $result =~ s/--/&textndash;/g;
      $result =~ s/'/&textrsquo;/g;
      $result =~ s/`/&textlsquo;/g;
    }
  }
  return $result;
}

sub txi_markup_header($)
{
  my $self = shift;

  my $encoding = '';
  if ($self->get_conf('OUTPUT_ENCODING_NAME')
      and $self->get_conf('OUTPUT_ENCODING_NAME') ne 'utf-8') {
    $encoding = " encoding=\"".$self->get_conf('OUTPUT_ENCODING_NAME')."\" ";
  }
  my $texinfo_dtd_version = $self->get_conf('TEXINFO_DTD_VERSION');
  if (!defined($texinfo_dtd_version)) {
    $texinfo_dtd_version = '1.00';
  }

  # In the TexinfoML name, the X of XML is replaced by Texinfo.
  my $header =  "<?xml version=\"1.0\"${encoding}?>".'
<!DOCTYPE texinfo PUBLIC "-//GNU//DTD TexinfoML V'.$texinfo_dtd_version.'//EN" "http://www.gnu.org/software/texinfo/dtd/'.$texinfo_dtd_version.'/texinfo.dtd">
';
  return $header;
}

1;

__END__
# Automatically generated from maintain/template.pod

=head1 NAME

Texinfo::Convert::TexinfoXML - Convert Texinfo tree to TexinfoXML

=head1 SYNOPSIS

  my $converter
    = Texinfo::Convert::TexinfoXML->converter({'NUMBER_SECTIONS' => 0});

  $converter->output($document);
  $converter->convert($document);
  $converter->convert_tree($tree);

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

Texinfo::Convert::TexinfoXML converts a Texinfo tree to TexinfoXML.

=head1 METHODS

=over

=item $converter = Texinfo::Convert::TexinfoXML->converter($options)

Initialize converter from Texinfo to TexinfoXML.

The I<$options> hash reference holds Texinfo customization options for the
converter.  These options should be Texinfo customization options
that can be passed to the converter.  Most of the customization options are
described in the Texinfo manual or in the customization API manual.  Those
customization options, when appropriate, override the document content.

See L<Texinfo::Convert::Converter> for more information.

=item $converter->output($document)

Convert a Texinfo parsed document I<$document> and output the result in files as
described in the Texinfo manual.

=item $result = $converter->convert($document)

Convert a Texinfo parsed document I<$document> and return the resulting output.

=item $result = $converter->convert_tree($tree)

Convert a Texinfo tree portion I<$tree> and return the resulting
output.  This function does not try to output a full document but only
portions.  For a full document use C<convert>.

In general, this function should be called after the converter has been
associated to a document by a call to C<output> or C<convert>.

=back

=head1 AUTHOR

Patrice Dumas, E<lt>pertusus@free.frE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2010- Free Software Foundation, Inc.  See the source file for
all copyright years.

This library is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or (at
your option) any later version.

=cut
