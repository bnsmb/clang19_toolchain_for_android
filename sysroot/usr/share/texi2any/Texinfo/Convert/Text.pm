# Text.pm: output tree as simple text.
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

package Texinfo::Convert::Text;

use 5.006;
use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use File::Basename;

#use Data::Dumper;
use Carp qw(cluck carp confess);

use Encode qw(decode);

use Texinfo::Convert::ConvertXS;
use Texinfo::XSLoader;

use Texinfo::Commands;
use Texinfo::Common;
use Texinfo::Convert::Unicode;
# for debugging
use Texinfo::Convert::Texinfo;
# misc functions and data
use Texinfo::Convert::Utils;

use Texinfo::Translations;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
  convert_to_text
  text_accents
);

our $VERSION = '7.2';

my $XS_convert = Texinfo::XSLoader::XS_convert_enabled();

our $module_loaded = 0;
sub import {
  if (!$module_loaded) {
    if ($XS_convert) {
      # We do not simply override, we must check at runtime
      # that the document tree was stored by the XS parser.
      Texinfo::XSLoader::override(
        "Texinfo::Convert::Text::_convert_tree_with_XS",
        "Texinfo::Convert::ConvertXS::text_convert_tree");
      Texinfo::XSLoader::override(
       "Texinfo::Convert::Text::destroy",
       "Texinfo::Convert::ConvertXS::destroy");
    }
    $module_loaded = 1;
  }
  # The usual import method
  goto &Exporter::import;
}


# this is in fact not needed for 'footnote', 'shortcaption', 'caption'
# as they have no brace_container, see below.
my %ignored_brace_commands;
foreach my $ignored_brace_command (#'xref','ref','pxref','inforef',
   'anchor', 'sortas', 'seealso', 'seeentry',
   'footnote', 'shortcaption', 'caption', 'hyphenation', 'errormsg') {
  $ignored_brace_commands{$ignored_brace_command} = 1;
}

my %ignored_block_commands;
foreach my $ignored_command ('titlepage', 'copying', 'documentdescription',
  'ignore', 'macro', 'rmacro', 'linemacro', 'nodedescriptionblock') {
  $ignored_block_commands{$ignored_command} = 1;
}

my %ignored_format_raw_commands;
foreach my $ignored_command ('html', 'tex', 'xml', 'docbook', 'latex') {
  $ignored_format_raw_commands{$ignored_command} = 1;
}

# used in C commands table generation
our %sort_brace_no_arg_commands = (
  'copyright' => 'C',
  'registeredsymbol' => 'R',
  'today' => 't',
);

foreach my $accent_letter ('o','O','l','L') {
  $sort_brace_no_arg_commands{$accent_letter} = $accent_letter;
}

my %accent_commands = %Texinfo::Commands::accent_commands;
my %nobrace_symbol_text = %Texinfo::Common::nobrace_symbol_text;
my %formatted_line_commands = %Texinfo::Commands::formatted_line_commands;
my %def_commands = %Texinfo::Commands::def_commands;
# 'page' is a formatted_line_commands and therefore is replaced by an empty
# line.

my %converted_formattable_line_commands;
foreach my $command ('verbatiminclude', 'sp') {
  $converted_formattable_line_commands{$command} = 1;
}

foreach my $command (keys(%def_commands)) {
  if ($Texinfo::Commands::line_commands{$command}) {
    $converted_formattable_line_commands{$command} = 1;
  }
}

my %ignored_types;
foreach my $type ('postamble_after_end',
            'preamble_before_beginning') {
  $ignored_types{$type} = 1;
}

my %ignored_text_types;
foreach my $type ('ignorable_spaces_after_command',
            'spaces_at_end',
            'spaces_before_paragraph',
            'spaces_after_close_brace') {
  $ignored_text_types{$type} = 1;
}

my @text_indicator_converter_options
      = ('ASCII_GLYPH', 'NUMBER_SECTIONS', 'TEST');

sub _initialize_options_encoding($$)
{
  my $self = shift;
  my $options = shift;

  if ($self->get_conf('ENABLE_ENCODING')
       and defined($self->get_conf('OUTPUT_ENCODING_NAME'))) {
    $options->{'enabled_encoding'} = $self->get_conf('OUTPUT_ENCODING_NAME');
  }
}

# NOTE not documented.  In general, it is not useful to call that
# function, as it the function is already called in Texinfo::Convert::Converter
# to setup options that can be reused.
#
# $SELF is an object implementing get_conf, in general a converter.
# Setup options as used by Texinfo::Convert::Text::convert_to_text
# based on the converter information.
# This is relevant for file names, for instance.
# $OPTIONS_IN can be used to pass additional options, for now 'sort_string'.
sub copy_options_for_convert_text($;$)
{
  my $self = shift;
  my $options_in = shift;
  my %options;

  _initialize_options_encoding($self, \%options);

  foreach my $option (@text_indicator_converter_options) {
    my $conf = $self->get_conf($option);
    if ($conf) {
      $options{$option} = 1;
    } elsif (defined($conf)) {
      $options{$option} = 0;
    }
  }
  my $expanded_formats = $self->get_conf('EXPANDED_FORMATS');
  if ($expanded_formats) {
    $options{'expanded_formats'} = {};
    foreach my $expanded_format(@$expanded_formats) {
      $options{'expanded_formats'}->{$expanded_format} = 1;
    }
  }
  # for expand_verbatiminclude
  $options{'INCLUDE_DIRECTORIES'} = $self->get_conf('INCLUDE_DIRECTORIES');

  $options{'converter'} = $self;

  if ($options_in) {
    foreach my $option (keys(%$options_in)) {
      $options{$option} = $options_in->{$option};
    }
  }
  return \%options;
}

sub set_options_code($)
{
  my $options = shift;
  $options->{'_code_state'}++;
}

sub reset_options_code($)
{
  my $options = shift;
  $options->{'_code_state'}--;
}

# $SELF is an object implementing get_conf, in general a converter.
# set enabled_encoding unless the encoding is ascii, even if
# ENABLE_ENCODING is not set.
sub set_options_encoding_if_not_ascii($$)
{
  my $self = shift;
  my $options = shift;
  my $output_encoding_name = $self->get_conf('OUTPUT_ENCODING_NAME');
  if (defined($output_encoding_name) and $output_encoding_name ne 'us-ascii') {
    if (defined($options->{'_saved_enabled_encoding'})) {
       print STDERR "BUG: if_not_ascii _saved_enabled_encoding set: "
                            .$options->{'_saved_enabled_encoding'}." / ".
                     $output_encoding_name ."\n";
      #cluck();
    }
    $options->{'_saved_enabled_encoding'} = $options->{'enabled_encoding'};
    $options->{'enabled_encoding'} = $output_encoding_name;
  }
}

sub set_options_encoding($$)
{
  my $options = shift;
  my $encoding = shift;
  if (defined($options->{'_saved_enabled_encoding'})) {
     print STDERR "BUG: _saved_enabled_encoding set: "
                          .$options->{'_saved_enabled_encoding'}." / ".
                            $encoding."\n";
  }
  $options->{'_saved_enabled_encoding'} = $options->{'enabled_encoding'};
  $options->{'enabled_encoding'} = $encoding;
}

sub reset_options_encoding($)
{
  my $options = shift;
  if (defined($options->{'_saved_enabled_encoding'})) {
    $options->{'enabled_encoding'} = $options->{'_saved_enabled_encoding'};
    delete $options->{'_saved_enabled_encoding'};
  }
}


sub _ascii_accent($$)
{
  my $text = shift;
  my $command = shift;
  my $accent = $command->{'cmdname'};
  return $text if ($accent eq 'dotless');
  return $text . "''" if ($accent eq 'H');
  return $text . '.' if ($accent eq 'dotaccent');
  return $text . '*' if ($accent eq 'ringaccent');
  return $text . '[' if ($accent eq 'tieaccent');
  return $text . '(' if ($accent eq 'u');
  return $text . '_' if ($accent eq 'ubaraccent');
  return '.' . $text  if ($accent eq 'udotaccent');
  return $text . '<' if ($accent eq 'v');
  return $text . ';' if ($accent eq 'ogonek');
  return $text . $accent;
}

# format a stack of accents as ascii
sub _ascii_accents($$;$)
{
  my $result = shift;
  my $stack = shift;
  my $set_case = shift;

  if ($set_case and $result =~ /^\w+$/) {
    if ($set_case > 0) {
      $result = uc($result);
    } else {
      $result = lc($result);
    }
  }
  foreach my $accent_command (reverse(@$stack)) {
    $result = _ascii_accent($result, $accent_command);
  }
  return $result;
}

# Same as _ascii_accent, but with a converter as first argument to be consistent
# with calling conventions of fallback accent formatting functions given
# to Convert::Converter::convert_accents()
# or Convert::Unicode::encoded_accents()
sub ascii_accent_fallback($$$)
{
  my $converter = shift;
  my $text = shift;
  my $command = shift;

  return _ascii_accent($text, $command);
}

# format an accent command and nested accents within as Text.
sub text_accents($;$$)
{
  my $accent = shift;
  my $encoding = shift;
  my $set_case = shift;

  my ($contents_element, $stack)
      = Texinfo::Convert::Utils::find_innermost_accent_contents($accent);
  my $options = {};
  $options->{'enabled_encoding'} = $encoding if (defined($encoding));
  $options->{'set_case'} = $set_case if (defined($set_case));
  my $text = '';
  if (defined($contents_element)) {
    $text = convert_to_text($contents_element, $options);
  }

  my $result = Texinfo::Convert::Unicode::encoded_accents(undef, $text,
                     $stack, $encoding, \&ascii_accent_fallback, $set_case);
  if (defined($result)) {
    return $result;
  } else {
    return _ascii_accents($text, $stack, $set_case);
  }
}

sub _convert($$);

# TODO document?  Used in other converters.
sub brace_no_arg_command($;$)
{
  my $element = shift;
  my $options = shift;
  my $encoding;
  $encoding = $options->{'enabled_encoding'}
    if ($options and defined($options->{'enabled_encoding'}));

  my $command_name = $element->{'cmdname'};
  $command_name = $element->{'extra'}->{'clickstyle'}
     if ($element->{'extra'}
      and defined($element->{'extra'}->{'clickstyle'})
      and defined($Texinfo::Common::text_brace_no_arg_commands{
                                  $element->{'extra'}->{'clickstyle'}}));
  my $result;
  if (defined($encoding) and
      (!($options and $options->{'ASCII_GLYPH'})
       or !exists($Texinfo::Convert::Unicode::extra_unicode_map{$command_name}))) {
    $result
      = Texinfo::Convert::Unicode::brace_no_arg_command($command_name,
                                                        $encoding);
  }
  if (!defined($result) and $options and $options->{'converter'}) {
    my $tree
     = Texinfo::Convert::Utils::translated_command_tree($options->{'converter'},
                                                        $command_name);
    if ($tree) {
      $result = _convert($options, $tree);
    }
  }
  if (!defined($result)) {
    if ($options and $options->{'sort_string'}
        and $sort_brace_no_arg_commands{$command_name}) {
      $result = $sort_brace_no_arg_commands{$command_name};
    } else {
      $result = $Texinfo::Common::text_brace_no_arg_commands{$command_name};
    }
  }
  if ($options and $Texinfo::Commands::letter_no_arg_commands{$command_name}) {
    if ($options->{'set_case'}) {
      if ($options->{'set_case'} > 0) {
        $result = uc($result);
      # NOTE does not seems to be decreased/set to negative anywhere, but
      # should work ok if it is.
      } else {
        $result = lc($result);
      }
    }
  }
  return $result;
}

my %underline_symbol = (
  0 => '*',
  1 => '*',
  2 => '=',
  3 => '-',
  4 => '.'
);

# Return the text of an underlined heading, possibly indented.
sub _text_heading($$$;$$)
{
  my $current = shift;
  my $text = shift;
  my $converter = shift;
  my $numbered = shift;
  my $indent_length = shift;

  # end of lines spaces are ignored in conversion.  However in
  # rare cases, invalid nestings leave an end of line, so we chomp.
  chomp($text);
  $text = Texinfo::Convert::Utils::add_heading_number($converter, $current,
                                                      $text, $numbered);
  # What about non-ascii spaces?
  return '' if ($text !~ /\S/);
  my $result = $text ."\n";
  if (defined($indent_length)) {
    if ($indent_length < 0) {
      $indent_length = 0;
    }
    $result .= (' ' x $indent_length);
  } else {
    $indent_length = 0;
  }
  my $section_level;
  if (!defined($current->{'extra'})
      or !defined($current->{'extra'}->{'section_level'})) {
    $section_level = Texinfo::Common::section_level($current);
  } else {
    $section_level = $current->{'extra'}->{'section_level'};
  }
  # $text is indented if indent_length is set, so $indent_length need to
  # be subtracted to have the width of the heading only.
  $result .= ($underline_symbol{$section_level}
     x (Texinfo::Convert::Unicode::string_width($text) - $indent_length))."\n";
  return $result;
}

sub _convert_def_line($$)
{
  my $options = shift;
  my $element = shift;

  my $result = '';

  #print STDERR "DEF: $element->{'extra'}->{'def_command'}\n";
  my ($category_element, $class_element,
      $type_element, $name_element, $arguments)
       = Texinfo::Convert::Utils::definition_arguments_content($element);

  my $parsed_definition_category
    = Texinfo::Convert::Utils::definition_category_tree(
                                        $options->{'converter'}, $element);
  if (defined($parsed_definition_category)) {
    my $converted_element = {'contents' =>
                    [$parsed_definition_category, {'text' => ': '}]};
    my $contents = $converted_element->{'contents'};
    if ($type_element) {
      push @$contents, ($type_element, {'text' => ' '});
    }
    if ($name_element) {
      push @$contents, $name_element;
    }

    if ($arguments) {
      push @$contents, ({'text' => ' '}, $arguments);
    }
    push @$contents, {'text' => "\n"};
    $options->{'_code_state'}++;
    $result = _convert($options, $converted_element);
    $options->{'_code_state'}--;
  }
  return $result;
}

# Will never be called, used for the override.
sub _convert_tree_with_XS($$)
{
}

sub _convert($$)
{
  my $options = shift;
  my $element = shift;

  #print STDERR "E: c: ".(defined($options->{'_code_state'})
  #                         ? $options->{'_code_state'} : 'UNDEF')
  #   ." r: ".(defined($options->{'_raw_state'})
  #                         ? $options->{'_raw_state'} : 'UNDEF')
  #   .", ".Texinfo::Common::debug_print_element($element, 1)."\n";

  if (!defined($element)) {
    confess("Texinfo::Convert::Text::_convert: element undef");
  }

  if (defined($element->{'text'})) {
    if ($element->{'type'} and $ignored_text_types{$element->{'type'}}) {
      return '';
    }
    my $result = $element->{'text'};
    if ((! defined($element->{'type'})
         or $element->{'type'} ne 'raw')
        and !$options->{'_raw_state'}) {
      if ($options->{'set_case'}) {
        if ($options->{'set_case'} > 0) {
          $result = uc($result);
        } else {
          $result = lc($result);
        }
      }
      if (!$options->{'_code_state'}) {
        $result =~ s/``/"/g;
        $result =~ s/\'\'/"/g;
        $result =~ s/---/\x{1F}/g;
        $result =~ s/--/-/g;
        $result =~ s/\x{1F}/--/g;
      }
    }
    return $result;
  }

  my $cmdname;
  my $data_cmdname;
  if (defined($element->{'cmdname'})) {
    $cmdname = $element->{'cmdname'};
    if ($cmdname eq 'item' and $element->{'parent'}->{'type'}
        and $element->{'parent'}->{'type'} eq 'table_term') {
      $data_cmdname = 'item_LINE';
    } else {
      $data_cmdname = $cmdname;
    }
  }

  return '' if (!($element->{'type'} and $element->{'type'} eq 'def_line')
     and (($element->{'type'} and $ignored_types{$element->{'type'}})
          or ($cmdname
             and ($ignored_brace_commands{$cmdname}
                 or $ignored_block_commands{$cmdname}
                 or ($ignored_format_raw_commands{$cmdname}
                     and !(defined($options->{'expanded_formats'})
                           and $options->{'expanded_formats'}->{$cmdname}))
                 or ($Texinfo::Commands::brace_commands{$cmdname}
                     and $Texinfo::Commands::brace_commands{
                                             $cmdname} eq 'inline'
                     and $cmdname ne 'inlinefmtifelse'
                     and (($Texinfo::Commands::inline_format_commands{$cmdname}
                           and (!$element->{'extra'}
                                or !$element->{'extra'}->{'format'}
                                or !$options->{'expanded_formats'}
                                or !$options->{'expanded_formats'}
                                           ->{$element->{'extra'}->{'format'}}))
                         or (!$Texinfo::Commands::inline_format_commands{
                                                                       $cmdname}
                             and (!$element->{'extra'}
                                  or !defined($element->{'extra'}
                                                         ->{'expand_index'})))))
             # here ignore most of the line commands
                 or ($element->{'args'}
                     and $element->{'args'}->[0]->{'type'}
                     and ($element->{'args'}->[0]->{'type'} eq 'line_arg'
                         or $element->{'args'}->[0]->{'type'} eq 'rawline_arg')
                     and !$formatted_line_commands{$data_cmdname}
                     and !$converted_formattable_line_commands{$cmdname})))));

  my $result = '';
  if (defined($cmdname)) {
    if (defined($nobrace_symbol_text{$cmdname})) {
      return $nobrace_symbol_text{$cmdname};
    } elsif ($cmdname eq 'today') {
      if ($options->{'sort_string'}
          and $sort_brace_no_arg_commands{$cmdname}) {
        return $sort_brace_no_arg_commands{$cmdname};
      } elsif ($options->{'converter'}) {
        return _convert($options,
                        Texinfo::Convert::Utils::expand_today(
                                         $options->{'converter'}));
      } elsif ($options->{'TEST'}) {
        return 'a sunny day';
      } else {
        my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)
          = localtime(time);
        $year += ($year < 70) ? 2000 : 1900;
        return "$Texinfo::Convert::Utils::month_name[$mon] $mday, $year";
      }
    } elsif (defined($Texinfo::Common::text_brace_no_arg_commands{$cmdname})) {
      return brace_no_arg_command($element, $options);
    # commands with braces
    } elsif ($accent_commands{$cmdname}) {
      my $result = text_accents($element, $options->{'enabled_encoding'},
                                $options->{'set_case'});
      return $result;
    } elsif ($cmdname eq 'image') {
      if ($element->{'args'}) {
        $options->{'_code_state'}++;
        my $text = _convert($options, $element->{'args'}->[0]);
        $options->{'_code_state'}--;
        return $text;
      } else {
        return '';
      }
    } elsif ($cmdname eq 'email') {
      if ($element->{'args'}) {
        my $text;
        $text = _convert($options, $element->{'args'}->[1])
           if (defined($element->{'args'}->[1]));
        return $text if (defined($text) and ($text ne ''));
        $options->{'_code_state'}++;
        my $mail = _convert($options, $element->{'args'}->[0]);
        $options->{'_code_state'}--;
        return $mail;
      } else {
        return '';
      }
    } elsif ($cmdname eq 'uref' or $cmdname eq 'url') {
      if ($element->{'args'}) {
        my $replacement;
        $replacement = _convert($options, $element->{'args'}->[2])
          if (defined($element->{'args'}->[2]));
        return $replacement if (defined($replacement) and $replacement ne '');
        my $text;
        $text = _convert($options, $element->{'args'}->[1])
          if (defined($element->{'args'}->[1]));
        $options->{'_code_state'}++;
        my $url = _convert($options, $element->{'args'}->[0]);
        $options->{'_code_state'}--;
        if (defined($text) and $text ne '') {
          return "$url ($text)";
        } else {
          return $url;
        }
      } else {
        return '';
      }
    # if there is only one argument, it is processed below with the other
    # brace commands
    } elsif ($Texinfo::Commands::explained_commands{$cmdname}
             and $element->{'args'} and scalar(@{$element->{'args'}}) >= 2) {
      my $explanation = _convert($options, $element->{'args'}->[1]);
      if ($explanation ne '') {
        return _convert($options, $element->{'args'}->[0]) ." ($explanation)";
      } else {
        return _convert($options, $element->{'args'}->[0]);
      }
    } elsif ($Texinfo::Commands::brace_commands{$cmdname}
             and $Texinfo::Commands::brace_commands{$cmdname} eq 'inline') {
      if ($cmdname eq 'inlineraw') {
        $options->{'_raw_state'}++;
      }
      my $arg_index = 1;
      if ($cmdname eq 'inlinefmtifelse'
          and (!$element->{'extra'}
               or !$element->{'extra'}->{'format'}
               or !$options->{'expanded_formats'}
               or !$options->{'expanded_formats'}
                                   ->{$element->{'extra'}->{'format'}})) {
        $arg_index = 2;
      }
      my $result = '';
      if (scalar(@{$element->{'args'}}) > $arg_index) {
        $result = _convert($options, $element->{'args'}->[$arg_index]);
      }
      if ($cmdname eq 'inlineraw') {
        $options->{'_raw_state'}--;
      }
      return $result;
    } elsif ($element->{'args'}
           and (($element->{'args'}->[0]->{'type'}
                and ($element->{'args'}->[0]->{'type'} eq 'brace_container'
                     or $element->{'args'}->[0]->{'type'} eq 'brace_arg'))
                or ($Texinfo::Commands::math_commands{$cmdname}
                    and $Texinfo::Commands::brace_commands{$cmdname}))) {
      my $result;
      my $in_code;
      $options->{'set_case'}++ if ($cmdname eq 'sc');
      if ($Texinfo::Commands::brace_code_commands{$cmdname}
          or $Texinfo::Commands::math_commands{$cmdname}) {
        $in_code = 1;
      }
      $options->{'_code_state'}++ if ($in_code);
      $result = _convert($options, $element->{'args'}->[0]);
      $options->{'_code_state'}-- if ($in_code);
      $options->{'set_case'}-- if ($cmdname eq 'sc');
      return $result;
    # block commands
    } elsif ($cmdname eq 'quotation'
             or $cmdname eq 'smallquotation'
             or $cmdname eq 'float'
             or $cmdname eq 'cartouche') {
      if ($element->{'args'}) {
        foreach my $arg (@{$element->{'args'}}) {
          my $converted_arg = _convert($options, $arg);
          if ($converted_arg =~ /\S/) {
            $result .= $converted_arg.", ";
          }
        }
        $result =~ s/, $//;
        chomp ($result);
        $result .= "\n" if ($result =~ /\S/);
      }
    } elsif ($formatted_line_commands{$data_cmdname}
             and $element->{'args'}) {
      if ($cmdname ne 'node') {
        if ($cmdname eq 'page') {
          $result = '';
        } else {
          $result = _convert($options, $element->{'args'}->[0]);
        }
        if ($Texinfo::Commands::sectioning_heading_commands{$cmdname}) {
          $result = _text_heading($element, $result, $options->{'converter'},
                                 $options->{'NUMBER_SECTIONS'});
        } else {
        # we always want an end of line even if is was eaten by a command
          chomp($result);
          $result .= "\n";
        }
      }
    } elsif ($converted_formattable_line_commands{$cmdname}
             and $element->{'args'}) {
      if ($def_commands{$cmdname}) {
        $result = _convert_def_line($options, $element);
      } elsif ($cmdname eq 'sp') {
        if ($element->{'extra'} and $element->{'extra'}->{'misc_args'}
            and $element->{'extra'}->{'misc_args'}->[0]) {
          # this useless copy avoids perl changing the type to integer!
          my $sp_nr = $element->{'extra'}->{'misc_args'}->[0];
          $result = "\n" x $sp_nr;
        }
      } elsif ($cmdname eq 'verbatiminclude') {
        my $verbatim_include_verbatim;
        if ($options->{'converter'}) {
          # NOTE we use $options->{'converter'} both for error registration
          # and for other uses of customization information, to get the same
          # output as for the main $options->{'converter'}.
          $verbatim_include_verbatim
            = Texinfo::Convert::Utils::expand_verbatiminclude(
                                          $options->{'converter'}, $element);
        } else {
          $verbatim_include_verbatim
            = Texinfo::Convert::Utils::expand_verbatiminclude($options, $element);
        }
        if (defined($verbatim_include_verbatim)) {
          $result .= _convert($options, $verbatim_include_verbatim);
        }
      }
    } elsif ($cmdname eq 'item'
            and $element->{'parent'}->{'cmdname'}
            and $element->{'parent'}->{'cmdname'} eq 'enumerate') {
      $result .= Texinfo::Common::enumerate_item_representation(
         $element->{'parent'}->{'extra'}->{'enumerate_specification'},
         $element->{'extra'}->{'item_number'}) . '. ';
    }
  }
  if ($element->{'type'}) {
    if ($element->{'type'} eq 'def_line') {
      $result = _convert_def_line($options, $element);
    } elsif ($element->{'type'} eq 'untranslated_def_line_arg') {
      my $tree;
      my $category_text = $element->{'contents'}->[0]->{'text'};
      my $translation_context;
      if ($element->{'extra'}
          and $element->{'extra'}->{'translation_context'}) {
        $translation_context = $element->{'extra'}->{'translation_context'};
      }

      if ($options and $options->{'converter'}) {
        # the tree documentlanguage corresponds to the documentlanguage
        # at the place of the tree, but the converter may want to use
        # another documentlanguage, for instance the documentlanguage at
        # the end of the preamble, so we let the converter set it.
        if ($translation_context) {
          $tree = $options->{'converter'}->pcdt($translation_context,
                                                $category_text);
        } else {
          $tree = $options->{'converter'}->cdt($category_text);
        }
      } else {
        # if there is no converter, we use the documentlanguage available
        # in the tree.
        $tree = Texinfo::Translations::gdt($category_text,
                             $element->{'extra'}->{'documentlanguage'},
                             undef, undef, $translation_context);
      }
      $result = _convert($options, $tree);
      return $result;
    }
  }
  if ($element->{'contents'}) {
    my $in_code;
    my $in_raw;
    if (($cmdname
         and ($Texinfo::Commands::preformatted_code_commands{$cmdname}
              or $Texinfo::Commands::math_commands{$cmdname}
              or (defined($Texinfo::Commands::block_commands{$cmdname})
                  and $Texinfo::Commands::block_commands{$cmdname} eq 'raw')))
         or ($element->{'type'} and $element->{'type'} eq 'menu_entry_node')) {
      $in_code = 1;
    } elsif ($cmdname
             and $Texinfo::Commands::block_commands{$cmdname}
             and $Texinfo::Commands::block_commands{$cmdname} eq 'format_raw') {
      $in_raw = 1;
    }
    if (ref($element->{'contents'}) ne 'ARRAY') {
      cluck "contents not an array($element->{'contents'}).";
    }
    $options->{'_code_state'}++ if ($in_code);
    $options->{'_raw_state'}++ if ($in_raw);
    foreach my $content (@{$element->{'contents'}}) {
      $result .= _convert($options, $content);
    }
    $options->{'_raw_state'}-- if ($in_raw);
    $options->{'_code_state'}-- if ($in_code);
  }
  if ($element->{'type'} and $element->{'type'} eq 'menu_entry'
      and (!$element->{'parent'}->{'type'}
           or ($element->{'parent'}->{'type'} ne 'preformatted'
               and $element->{'parent'}->{'type'} ne 'rawpreformatted'))) {
    chomp($result);
    $result .= "\n";
  }
  #print STDERR "  RR ($element) -> $result\n";
  return $result;
}

# the main entry point
sub convert_to_text($;$)
{
  my $root = shift;
  my $options = shift;

  if (ref($root) ne 'HASH') {
    confess "root not a hash";
  }

  #print STDERR "CONVERT\n";
  if (!defined($options)) {
    $options = {};
  } elsif (!ref($options)) {
    confess("convert_to_text options not a ref\n");
  }
  # this is needed for expand_verbatiminclude which uses
  # $configurations_information->get_conf() and thus requires a blessed
  # reference.
  bless $options, "Texinfo::Convert::Text";

  # Interface with XS converter.
  if ($XS_convert and defined($root->{'tree_document_descriptor'})
      and $Texinfo::Convert::ConvertXS::XS_package) {
    return _convert_tree_with_XS($options, $root);
  }

  return _convert($options, $root);
}


# Implement the converters API, but as simply as possible
# initialization
sub converter($;$)
{
  my $class = shift;
  my $conf = shift;

  my $converter = {};
  bless $converter, $class;

  if ($conf) {
    %{$converter} = %{$conf};
    #print STDERR "CTe ".join("|", sort(keys(%{$conf})))."\n";
  }

  my $expanded_formats = $converter->{'EXPANDED_FORMATS'};
  if ($expanded_formats) {
    $converter->{'expanded_formats'} = {};
    foreach my $expanded_format(@$expanded_formats) {
      $converter->{'expanded_formats'}->{$expanded_format} = 1;
    }
  }

  return $converter;
}

# This function is not called (except in a test testing the function),
# it is implemented to be in line with Texinfo::Convert::Converter
# documentation on functions defined for a converter.
# We assume that $SELF is defined and a Texinfo::Convert::Text converter
# that will supply the options.
sub convert_tree($$)
{
  my $self = shift;
  my $element = shift;

  return _convert($self, $element);
}

# This function is not called (except in a test testing the function),
# it is implemented to be in line with Texinfo::Convert::Converter
# documentation on functions defined for a converter.
# We assume that $SELF is defined and a Texinfo::Convert::Text converter.
sub convert($$)
{
  my $self = shift;
  my $document = shift;

  Texinfo::Common::set_output_encoding($self, $document);
  # Cf comment in output() on using $self for options.
  _initialize_options_encoding($self, $self);

  my $root = $document->tree();

  my $result;
  # Interface with XS converter.
  if ($XS_convert and defined($root->{'tree_document_descriptor'})
      and $Texinfo::Convert::ConvertXS::XS_package) {
    $result = _convert_tree_with_XS($self, $root);
  } else {
    $result = _convert($self, $root);
  }

  return $result;
}

# determine outfile and output to that file
my $STDIN_DOCU_NAME = 'stdin';
sub output($$)
{
  my $self = shift;
  my $document = shift;

  my $document_info;
  if ($document) {
    $document_info = $document->global_information();
  }

  Texinfo::Common::set_output_encoding($self, $document);
  # sets OUTPUT_PERL_ENCODING needed for output_files_open_out below
  Texinfo::Common::set_output_perl_encoding($self);

  # Text options and converter are of different nature.
  # It could have been possible to set up the options by calling
  # copy_options_for_convert_text on $self.
  # However, since the option keys are very similar between the converter
  # and text options and expanded_formats is already set in the converter,
  # we use the converter object as text options and we call
  # _initialize_options_encoding for the only option that is set up
  # based on other customization options.
  # Also, we need a blessed reference as get_conf can be called on the options,
  # using the converter brings that too.
  _initialize_options_encoding($self, $self);

  my $root = $document->tree();

  #print STDERR "OUTPUT\n";
  my $input_basename;
  if ($document_info and defined($document_info->{'input_file_name'})) {
    my $input_file_name_bytes = $document_info->{'input_file_name'};
    my $encoding = $self->{'COMMAND_LINE_ENCODING'};
    my $input_file_name;
    if (defined($encoding)) {
      $input_file_name = decode($encoding, $input_file_name_bytes);
    } else {
      $input_file_name = $input_file_name_bytes;
    }
    my ($directories, $suffix);
    ($input_basename, $directories, $suffix) = fileparse($input_file_name);
  } else {
    # This could happen if called on a piece of texinfo
    $input_basename = '';
  }
  $input_basename = $STDIN_DOCU_NAME if ($input_basename eq '-');
  $input_basename =~ s/\.te?x(i|info)?$//;

  my $setfilename;
  if ($document_info and defined($document_info->{'setfilename'})) {
    $setfilename = $document_info->{'setfilename'};
  }
  my $outfile;
  if (!defined($self->{'OUTFILE'})) {
    if (defined($setfilename)) {
      $outfile = $setfilename;
      $outfile =~ s/\.[^\.]*$//;
    } elsif ($input_basename ne '') {
      $outfile = $input_basename;
    }
    if (defined($outfile)) {
      $outfile .= '.txt';
    }
    if (defined($self->{'SUBDIR'})) {
      my $destination_directory = File::Spec->canonpath($self->{'SUBDIR'});
      my ($encoded_destination_directory, $destination_directory_encoding)
        = Texinfo::Convert::Utils::encoded_output_file_name($self,
                                                     $destination_directory);
      if (! -d $encoded_destination_directory) {
        if (!mkdir($encoded_destination_directory, oct(755))) {
          warn sprintf(__(
             "could not create directory `%s': %s"),
             $destination_directory, $!)."\n";
          return undef;
        }
      }
      $outfile = join('/', ($destination_directory, $outfile));
    }
  } else {
    $outfile = $self->{'OUTFILE'};
    my ($output_basename, $output_directories, $output_suffix)
      = fileparse($outfile);
    if (defined($output_directories) and $output_directories ne './'
        and $output_directories ne '.' and $output_directories ne '') {
      my ($encoded_output_directories, $output_directories_encoding)
        = Texinfo::Convert::Utils::encoded_output_file_name($self,
                                                       $output_directories);
      if (! -d $encoded_output_directories) {
        if (!mkdir($encoded_output_directories, oct(755))) {
          warn sprintf(__(
             "could not create directory `%s': %s"),
             $output_directories, $!)."\n";
        }
      }
    }
  }
  my $fh;
  $self->{'output_files'} = Texinfo::Convert::Utils::output_files_initialize();
  my ($encoded_outfile, $outfile_encoding);
  if (defined($outfile)) {
    ($encoded_outfile, $outfile_encoding)
      = Texinfo::Convert::Utils::encoded_output_file_name($self, $outfile);
    my $error_message;
    # the third return information, set if the file has already been used
    # in this files_information is not checked as this cannot happen.
    ($fh, $error_message) = Texinfo::Convert::Utils::output_files_open_out(
                             $self->{'output_files'}, $self,
                             $encoded_outfile);
    if (!$fh) {
      warn sprintf(__("could not open %s for writing: %s"),
                   $outfile, $error_message)."\n";
      return undef;
    }
  }

  # We use $self as text options, see the comment above.

  my $result;
  # Interface with XS converter.
  if ($XS_convert and defined($root->{'tree_document_descriptor'})
      and $Texinfo::Convert::ConvertXS::XS_package) {
    $result = _convert_tree_with_XS($self, $root);
  } else {
    $result = _convert($self, $root);
  }

  if ($fh) {
    print $fh $result;
    Texinfo::Convert::Utils::output_files_register_closed(
                  $self->{'output_files'}, $encoded_outfile);
    return undef if (!close($fh));
    $result = '';
  }
  return $result;
}

# Nothing to do in perl.  XS function frees memory
sub destroy($)
{
}

sub get_conf($$)
{
  my $self = shift;
  my $key = shift;

  return $self->{$key};
}

# used in Texinfo::Common::set_output_encoding
sub set_conf($$$)
{
  my $self = shift;
  my $conf = shift;
  my $value = shift;

  $self->{$conf} = $value;

  return 1;
}

sub converter_line_error()
{
}

sub converter_document_warn()
{
}

sub get_converter_errors($)
{
  return undef;
}

sub converter_defaults()
{
  return undef;
}

sub output_files_information($)
{
  my $self = shift;
  return $self->{'output_files'};
}

1;

__END__

=head1 NAME

Texinfo::Convert::Text - Convert Texinfo tree to simple text

=head1 SYNOPSIS

  use Texinfo::Convert::Text qw(convert_to_text text_accents);

  my $result = convert_to_text($tree);

  my $accents_text = text_accents($accents, 'utf-8');

  # using text conversion options set in $converter derived from
  # Texinfo::Convert::Converter
  my $text_options = $converter->{'convert_text_options'};

  set_options_code($text_options);
  my $result_with_converter = convert_to_text($tree, $text_options);
  reset_options_code($text_options);

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

C<Texinfo::Convert::Text> is a simple backend that converts a Texinfo tree
to simple text.  It is used in converters, especially for file names.
The conversion is very simple, and, in the default case, cannot handle
error handling nor some output strings translation.

Converters derived from L<Texinfo::Convert::Converter> should have conversion
text options preset associated to the C<convert_text_options> key.

The main function is C<convert_to_text>.  The text conversion options
can be modified with the C<set_*> functions before calling C<convert_to_text>,
and reset afterwards with the corresponding C<reset_*> functions.

=head1 METHODS

=over

=item $result = convert_to_text($tree, $text_options)
X<C<convert_to_text>>

Convert a Texinfo tree to simple text.  I<$text_options> is a hash reference of
options.  The converter is very simple, and has almost no internal state
besides the options.  It cannot handle as is output strings translation or
error storing.

If the I<converter> option is set in I<$text_options>, some additional features
may be available for the conversion of some @-commands, like output strings
translation or error reporting.

The C<NUMBER_SECTIONS>, C<ASCII_GLYPH> and C<TEST> options corresponding to
customization variables may be set in I<$text_options>.  The following options
may also be set:

=over

=item enabled_encoding

If set, the value is considered to be the encoding name texinfo accented
letters should be converted to.  This option being set corresponds to the
C<--enable-encoding> option, or the C<ENABLE_ENCODING> customization
variable for Info and Plaintext and for some conversion to text in other
formats.  For file names in HTML and LaTeX, and for DocBook or Texinfo XML,
this variable should in general be set unless the output encoding is US-ASCII.

=item set_case

If positive, the text is upper-cased, if negative, the text is lower-cased.

=item sort_string

A somehow internal option to convert to text more suitable for alphabetical
sorting rather than presentation.

=item converter

If this converter object is passed to the function, some features of this
object may be used during conversion.  Mostly error reporting and strings
translation.  See also L<Texinfo::Convert::Converter>.

=item expanded_formats

A reference on a hash.  The keys should be format names (like C<html>,
C<tex>), and if the corresponding value is set, the format is expanded.

=back

=item $result_accent_text = ascii_accent_fallback($converter, $text, $accent_command)
X<C<ascii_accent_fallback>>

I<$text> is the text appearing within an accent command.  I<$accent_command>
should be a Texinfo tree element corresponding to an accent command taking
an argument.  The function returns a transliteration of the accented
character.  The I<$converter> argument is ignored, but needed for this
function to be in argument of functions that need a fallback for accents
conversion.

=item set_options_code($text_options)

=item reset_options_code($text_options)
X<C<set_options_code>>X<C<reset_options_code>>

C<set_options_code> sets I<$text_options> to be in code style.
(mostly C<-->, C<--->, C<''> and C<``> are kept as is).  C<reset_options_code>
undo the effect of C<set_options_code>.

C<reset_options_code> should always be called after C<set_options_code>.

=item set_options_encoding($text_options, $encoding)

=item set_options_encoding_if_not_ascii($customization_information, $text_options)

=item reset_options_encoding($text_options)
X<C<set_options_encoding>>X<C<set_options_encoding_if_not_ascii>>
X<C<reset_options_encoding>>

C<set_options_encoding> sets C<enabled_encoding> in I<$text_options>
to I<$encoding>.  C<set_options_encoding_if_not_ascii> sets C<enabled_encoding>
in I<$text_options> based on customization options associated to
I<$customization_information>.  In that case, C<enabled_encoding> is set unless
the output encoding is US-ASCII even if C<ENABLE_ENCODING> is not set.

C<reset_options_encoding> undo the effect of C<set_options_encoding> and
C<set_options_encoding_if_not_ascii> and should always be called after these
functions.

=item $accents_text = text_accents($accents, $encoding, $set_case)
X<C<text_accents>>

I<$accents> is an accent command that may contain other nested accent
commands.  The function will format the whole stack of nested accent
commands and the innermost text.  If I<$encoding> is set, the formatted
text is converted to this encoding as much as possible instead of being
converted as simple ASCII.  If I<$set_case> is positive, the result
is meant to be upper-cased, if it is negative, the result is to be
lower-cased.

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
