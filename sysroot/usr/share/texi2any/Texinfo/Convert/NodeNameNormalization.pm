# NodeNameNormalization.pm: output tree as normalized node name.
#
# Copyright 2010-2024 Free Software Foundation, Inc.
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

# the rules for conversion are decribed in the Texinfo manual, for
# HTML crossrefs in the 'HTML Xref' node.

package Texinfo::Convert::NodeNameNormalization;

use 5.006;
use strict;

# stop \s from matching non-ASCII spaces, etc.  \p{...} can still be
# used to match Unicode character classes.
use if $] >= 5.014, re => '/a';

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Unicode::Normalize;
use Text::Unidecode;

# commands classes
use Texinfo::Commands;
# for nobrace_symbol_text and text_brace_no_arg_commands
use Texinfo::Common;
# use the hashes and functions
use Texinfo::Convert::Unicode;

# NOTE it is important that there is no dependency to Texinfo::Convert::Text
# to avoid a dependency loop, in particular for data definition.
# The loop would be Texinfo::Convert::Text -> Texinfo::Translations
#   -> Texinfo::Parser -> this module

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
  convert_to_identifier
  normalize_transliterate_texinfo
  transliterate_texinfo
  transliterate_protect_file_name
);

our $VERSION = '7.2';


my %normalize_node_brace_no_arg_commands
  = %Texinfo::Common::text_brace_no_arg_commands;

foreach my $command (keys(%Texinfo::Convert::Unicode::unicode_character_brace_no_arg_commands)) {
  $normalize_node_brace_no_arg_commands{$command} =
     $Texinfo::Convert::Unicode::unicode_character_brace_no_arg_commands{$command};
}

my %normalize_node_nobrace_symbol_text
  = %Texinfo::Common::nobrace_symbol_text;
$normalize_node_nobrace_symbol_text{'*'} = ' ';
$normalize_node_nobrace_symbol_text{'today'} = '';

my %accent_commands = %Texinfo::Commands::accent_commands;

my %ignored_brace_commands;
foreach my $ignored_brace_command ('anchor', 'footnote', 'shortcaption',
       'caption', 'hyphenation', 'sortas', 'seealso', 'seeentry') {
  $ignored_brace_commands{$ignored_brace_command} = 1;
}

my %ignored_text_types;
foreach my $type (
            'ignorable_spaces_after_command',
            'spaces_at_end',
            'spaces_before_paragraph',
            'space_at_end_menu_node',
            'spaces_after_close_brace') {
  $ignored_text_types{$type} = 1;
}

my %ignored_types;
foreach my $type (
            'postamble_after_end',
            'preamble_before_beginning') {
  $ignored_types{$type} = 1;
}


sub convert_to_identifier($)
{
  my $root = shift;
  my $result = _convert($root);
  $result = Unicode::Normalize::NFC($result);
  $result = _unicode_to_protected($result);
  $result = 'Top' if ($result =~ /^Top$/i);
  return $result;
}

sub normalize_transliterate_texinfo($;$)
{
  my $root = shift;
  my $no_unidecode = shift;
  my $result = _convert($root);
  $result = Unicode::Normalize::NFC($result);
  $result = _unicode_to_protected(
                _unicode_to_transliterate($result, $no_unidecode));
  return $result;
}

sub transliterate_texinfo($;$)
{
  my $root = shift;
  my $no_unidecode = shift;
  my $result = _convert($root);
  $result = Unicode::Normalize::NFC($result);
  $result = _unicode_to_transliterate($result, $no_unidecode);
  return $result;
}

sub transliterate_protect_file_name($;$)
{
  my $input_text = shift;
  my $no_unidecode = shift;
  my $result = Unicode::Normalize::NFC($input_text);
  $result = _unicode_to_file_name(
                _unicode_to_transliterate($result, $no_unidecode));
  return $result;
}

sub convert_to_normalized($)
{
  my $root = shift;
  my $result = _convert($root);
}

sub _protect_unicode_char($)
{
  my $char = shift;
  if (exists($Texinfo::Convert::Unicode::unicode_simple_character_map{$char})) {
    return '_' . lc($Texinfo::Convert::Unicode::unicode_simple_character_map{$char});
  } else {
    if (ord($char) <= hex(0xFFFF)) {
      return '_' . lc(sprintf("%04x",ord($char)));
    } else {
      return '__' . lc(sprintf("%06x",ord($char)));
    }
  }
}

sub _unicode_to_protected($)
{
  my $text = shift;
  my $result = '';
  while ($text ne '') {
    if ($text =~ s/^([A-Za-z0-9]+)//) {
      $result .= $1;
    } elsif ($text =~ s/^ +//) {
      $result .= '-';
    # with /a some special spaces are not caught without /s, maybe because they are
    # considered as newlines
    } elsif ($text =~ s/^(.)//s) {
      $result .= _protect_unicode_char($1);
    } else {
      warn "Bug: unknown character _unicode_to_protected (likely in infinite loop)\n";
      print STDERR "Text: !!$text!!\n";
      sleep 1;
    }
  }
  return $result;
}

sub _unicode_to_file_name($)
{
  my $text = shift;
  my $result = '';
  while ($text ne '') {
    if ($text =~ s/^([A-Za-z0-9_\.\-]+)//) {
      $result .= $1;
    } elsif ($text =~ s/^ +//) {
      $result .= '-';
    # /s is specified to caught special spaces considered as newlines too
    } elsif ($text =~ s/^(.)//s) {
      $result .= _protect_unicode_char($1);
    } else {
      warn "Bug: unknown character _unicode_to_file_name (likely in infinite loop)\n";
      print STDERR "Text: !!$text!!\n";
      sleep 1;
    }
  }
  return $result;
}

sub _unicode_to_transliterate($;$)
{
  my $text = shift;
  my $no_unidecode = shift;
  if (chomp($text)) {
     warn "Bug: end of line to transliterate: $text\n";
  }
  my $result = '';
  while ($text ne '') {
    if ($text =~ s/^([A-Za-z0-9 ]+)//) {
      $result .= $1;
    } elsif ($text =~ s/^(.)//s) {
      my $char = $1;
      if (exists($Texinfo::Convert::Unicode::unicode_simple_character_map{$char})) {
        $result .= $char;
      } elsif (ord($char) <= hex(0xFFFF)
               and exists($Texinfo::Convert::Unicode::transliterate_map{uc(sprintf("%04x",ord($char)))})) {
        $result .= $Texinfo::Convert::Unicode::transliterate_map{uc(sprintf("%04x",ord($char)))};
      } elsif (ord($char) <= hex(0xFFFF)
               and exists($Texinfo::Convert::Unicode::diacritics_accent_commands{uc(sprintf("%04x",ord($char)))})) {
        $result .= '';
      # in those cases, we want to avoid calling unidecode, as we are sure
      # that there is no useful transliteration of the unicode character
      # the would end up in the file name, instead we want to keep it as is
      # such that it is protected as itself.
      # This is the case, for example, for @exclamdown, it corresponds
      # with x00a1, but unidecode transliterates it to a !, which ends up
      # as _0021, we want to avoid that and keep _00a1 in the transliterated
      # file name.  These case also do not have a good transliteration with
      # iconv, although this could also depend on the locale.
      } elsif (ord($char) <= hex(0xFFFF)
               and exists($Texinfo::Convert::Unicode::no_transliterate_map{uc(sprintf("%04x",ord($char)))})) {
        $result .= $char;
      } else {
        if ($no_unidecode) {
          if (ord($char) <= hex(0xFFFF)
              and exists ($Texinfo::Convert::Unicode::transliterate_accent_map{uc(sprintf("%04x",ord($char)))})) {
            $result .= $Texinfo::Convert::Unicode::transliterate_accent_map{uc(sprintf("%04x",ord($char)))};
          } else {
            $result .= $char;
          }
        } else {
          $result .= unidecode($char);
        }
      }
      #print STDERR " ($no_unidecode) $text -> CHAR: ".ord($char)." ".uc(sprintf("%04x",ord($char)))."\n$result\n";
    } else {
      warn "Bug: unknown character _unicode_to_transliterate (likely in infinite loop)\n";
      print STDERR "Text: !!$text!!\n";
      sleep 1;
    }
  }
  return $result;
}


sub _convert($);

sub _convert($)
{
  my $element = shift;

  if (defined($element->{'text'})) {
    return ''
      if ($element->{'type'} and $ignored_text_types{$element->{'type'}});
    my $result = $element->{'text'};
    $result =~ s/\s+/ /g;
    return $result;
  }

  return '' if (($element->{'type'} and $ignored_types{$element->{'type'}})
          or ($element->{'cmdname'}
             and ($ignored_brace_commands{$element->{'cmdname'}}
             # here ignore the line commands
                 or ($element->{'args'} and $element->{'args'}->[0]
                     and $element->{'args'}->[0]->{'type'}
                     and ($element->{'args'}->[0]->{'type'} eq 'line_arg'
                         or $element->{'args'}->[0]->{'type'} eq 'rawline_arg')))));
  if ($element->{'cmdname'}) {
    my $cmdname = $element->{'cmdname'};
    if (defined($normalize_node_nobrace_symbol_text{$cmdname})) {
      return $normalize_node_nobrace_symbol_text{$cmdname};
    } elsif (defined($normalize_node_brace_no_arg_commands{$cmdname})) {
      $cmdname = $element->{'extra'}->{'clickstyle'}
         if ($element->{'extra'}
          and defined($element->{'extra'}->{'clickstyle'})
          and defined($normalize_node_brace_no_arg_commands{$element->{'extra'}->{'clickstyle'}}));
      my $result = $normalize_node_brace_no_arg_commands{$cmdname};
      return $result;
    # commands with braces
    } elsif ($accent_commands{$cmdname}) {
      return '' if (!$element->{'args'});
      my $accent_text = _convert($element->{'args'}->[0]);
      my $accented_char
        = Texinfo::Convert::Unicode::unicode_accent($accent_text,
                                                    $element);
      if (!defined($accented_char)) {
        # If this case was possible, the node normalization would not follow the
        # specification, but it is not possible, see unicode_accent.
        $accented_char = $accent_text;
      }
      return $accented_char;
    } elsif ($Texinfo::Commands::ref_commands{$cmdname}) {
      my @args_try_order;
      if ($cmdname eq 'inforef' or $cmdname eq 'link') {
        @args_try_order = (0, 1, 2);
      } else {
        @args_try_order = (0, 1, 2, 4, 3);
      }
      foreach my $index (@args_try_order) {
        if (defined($element->{'args'}->[$index])) {
          my $text = _convert($element->{'args'}->[$index]);
          return $text if (defined($text) and $text =~ /\S/);
        }
      }
      return '';
    # Here all the commands with args are processed, if they have
    # more than one arg the first one is used.
    } elsif ($element->{'args'} and $element->{'args'}->[0]
           and (($element->{'args'}->[0]->{'type'}
                 and ($element->{'args'}->[0]->{'type'} eq 'brace_container'
             or $element->{'args'}->[0]->{'type'} eq 'brace_arg'))
                or $cmdname eq 'math')) {
      return _convert($element->{'args'}->[0]);
    }
  }
  my $result = '';
  if ($element->{'contents'}) {
    foreach my $content (@{$element->{'contents'}}) {
      $result .= _convert($content);
    }
  }
  return $result;
}

1;

__END__

=head1 NAME

Texinfo::Convert::NodeNameNormalization - Normalize and transliterate Texinfo trees

=head1 SYNOPSIS

  use Texinfo::Convert::NodeNameNormalization qw(convert_to_identifier
                                        normalize_transliterate_texinfo);

  my $normalized = convert_to_identifier($node_element->{'args'}->[0]);

  my $file_name
    = normalize_transliterate_texinfo($section_element->{'args'}->[0]);

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

C<Texinfo::Convert::NodeNameNormalization> allows to normalize node names
with C<convert_to_normalized> and C<convert_to_identifier>.
C<convert_to_identifier> follows the specification described in the Texinfo
manual I<HTML Xref> node.  This is useful whenever one want a unique identifier
for Texinfo content, which is only composed of letter, digits, C<-> and C<_>,
for example for C<@node>, C<@float> and C<@anchor> names normalization.
C<convert_to_normalized> leaves out the step of protecting characters.

It is also possible to transliterate non-ASCII letters, instead of mangling
them, with C<normalize_transliterate_texinfo>, losing the uniqueness feature of
normalized node names.

Another method, C<transliterate_protect_file_name> transliterates non-ASCII
letters and protect characters that should not appear on file names.

=head1 METHODS

=over

=item $partially_normalized = convert_to_normalized($tree)
X<C<convert_to_normalized>>

The Texinfo I<$tree> is returned as a string, with @-commands and spaces
normalized as described in the Texinfo manual I<HTML Xref> node.  ASCII
7-bit characters other than spaces and non-ASCII characters are left as
is in the resulting string.

=item $normalized = convert_to_identifier($tree)
X<C<convert_to_identifier>>

The Texinfo I<$tree> is returned as a string, normalized as described in the
Texinfo manual I<HTML Xref> node.

The result will be poor for Texinfo trees which are not @-command arguments
(on an @-command line or in braces), for instance if the tree contains
C<@node> or block commands.

=item $transliterated = normalize_transliterate_texinfo($tree, $no_unidecode)
X<C<normalize_transliterate_texinfo>>

The Texinfo I<$tree> is returned as a string, with non-ASCII letters
transliterated as ASCII, but otherwise similar with C<convert_to_identifier>
output.  If the optional I<$no_unidecode> argument is set, C<Text::Unidecode>
is not used for characters whose transliteration is not built-in.

=item $transliterated = transliterate_texinfo($tree, $no_unidecode)
X<C<transliterate_texinfo>>

The Texinfo I<$tree> is returned as a string, with non-ASCII letters
transliterated as ASCII.  If the optional I<$no_unidecode> argument is set,
C<Text::Unidecode> is not used for characters whose transliteration is not
built-in.

=item $file_name = transliterate_protect_file_name($string, $no_unidecode)
X<C<transliterate_protect_file_name>>

The string I<$string> is returned with non-ASCII letters transliterated as
ASCII, and ASCII characters not safe in file names protected as in
node normalization.  If the optional I<$no_unidecode> argument is set,
C<Text::Unidecode> is not used for characters whose transliteration is not
built-in.

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
