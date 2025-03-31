# Utils.pm: miscellaneous functions usable in simple converters
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
#
# This module contains the methods that can be used in converters
# even if they do not inherit Texinfo::Convert::Converter.  In practice
# it means that the converter argument will not be defined and
# there will be no error reporting nor string translation in that case.
# Some methods still require a converter, it means that they are used
# conditionally in some converters that do not inherit
# Texinfo::Convert::Converter but can have gotten a converter object
# (case of Texinfo::Convert::Text).


package Texinfo::Convert::Utils;

use strict;

use 5.006;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

# debugging
use Carp qw(cluck);

use Texinfo::Commands;
use Texinfo::Common;
# only needed in debugging comments.  Ok to keep it here anyway.
use Texinfo::Convert::Texinfo;

require Exporter;

our @ISA = qw(Exporter);

# There is no specific reason to export those functions and not
# other functions of the module.  It could be possible not to
# export any function.
our @EXPORT_OK = qw(
expand_today
expand_verbatiminclude
add_heading_number
);

our $VERSION = '7.2';

# API to open, set encoding and register files.  Used in main program
# and converters.
# In general $SELF is stored as $converter->{'output_files'}
# and should be accessed through $converter->output_files_information();

# TODO next four functions not documented anywhere, probably relevant to
# document both in POD and in HTML Customization API.
sub output_files_initialize
{
  return {'unclosed_files' => {}, 'opened_files' => {}};
}

sub output_files_disable_output_encoding($$)
{
  my ($self, $no_output_encoding) = @_;

  $self->{'output_encoding_disabled'} = $no_output_encoding;
}

# All the opened files are registered, except for stdout,
# and the closing of files should be registered too with
# output_files_register_closed() below.  This makes possible to
# unlink all the opened files and close the files not already
# closed.
#
# $FILE_PATH is the file path, it should be a binary string.
# If $USE_BINMODE is set, call binmode() to set binary mode.
# $OUTPUT_ENCODING argument overrides the output encoding.
# Returns
#  - the opened filehandle, or undef if opening failed,
#  - the $! error message or undef if opening succeeded.
#  - 1 if the $FILE_PATH was already opened, which means overwriting.
sub output_files_open_out($$$;$$)
{
  my $self = shift;
  my $customization_information = shift;
  my $file_path = shift;
  my $use_binmode = shift;
  my $output_encoding = shift;

  #if (!defined($file_path)) {
  #  cluck('output_files_open_out: file_path undef');
  #}

  my $encoding;
  if ($self->{'output_encoding_disabled'}) {
   # leave $encoding undefined
  } elsif (defined($output_encoding)) {
    $encoding = $output_encoding;
  } elsif (defined(
             $customization_information->get_conf('OUTPUT_PERL_ENCODING'))) {
    $encoding = $customization_information->get_conf('OUTPUT_PERL_ENCODING');
  }

  if ($file_path eq '-') {
    binmode(STDOUT) if $use_binmode;
    binmode(STDOUT, ":encoding($encoding)") if (defined($encoding));
    if ($self) {
      $self->{'unclosed_files'}->{$file_path} = \*STDOUT;
    }
    return \*STDOUT, undef;
  }

  # Check that this file has not already been registered
  # as opened_file.  If yes, it will be overwritten if open succeeds.
  # It is not possible to use the file name twice in converters
  # for regular output as files are only closed when all the output
  # units have been written.  It could be possible in HTML with js
  # scripts licence file set by the user to the same name as an output
  # file.
  my $overwritten_file = 0;
  # NOTE paths are not normalized, therefore different paths names
  # that refers to the same file will not be found.
  if (exists($self->{'opened_files'}->{$file_path})) {
    $overwritten_file = 1;
  }
  my $filehandle = do { local *FH };
  if (!open($filehandle, '>', $file_path)) {
    my $error_message = $!;
    return undef, $error_message, $overwritten_file;
  }
  # If $use_binmode is true, we run binmode to turn off outputting LF as CR LF
  # under MS-Windows, so that Info tag tables will have correct offsets.  This
  # must be done before setting the encoding filters with binmode.
  binmode($filehandle) if $use_binmode;
  if ($encoding) {
    binmode($filehandle, ":encoding($encoding)");
  }
  if ($self) {
    if ($self->{'unclosed_files'}->{$file_path}) {
      warn "BUG: already open: $file_path\n";
    } else {
      $self->{'opened_files'}->{$file_path} = 1;
    }
    $self->{'unclosed_files'}->{$file_path} = $filehandle;
  }
  return $filehandle, undef, $overwritten_file;
}

# see the description of $SELF in comment above output_files_open_out.
#
# $FILE_PATH is the file path, it should be a binary string.
sub output_files_register_closed($$)
{
  my $self = shift;
  my $file_path = shift;
  if ($self->{'unclosed_files'}->{$file_path}) {
    delete $self->{'unclosed_files'}->{$file_path};
  } else {
    cluck "BUG: $file_path not opened\n";
  }
}

# The next two functions should not be called from user-defined
# code, only from the main program.  They are defined here for
# consistency of the API and clarity of the code.
#
# see the description of $SELF in comment above output_files_open_out.
sub output_files_opened_files($)
{
  my $self = shift;
  return $self->{'opened_files'};
}

# see the description of $SELF in comment above output_files_open_out.
sub output_files_unclosed_files($)
{
  my $self = shift;
  return $self->{'unclosed_files'};
}
# end of output_files API



our @month_name =
    (
     Texinfo::Common::gdt('January'),
     Texinfo::Common::gdt('February'),
     Texinfo::Common::gdt('March'),
     Texinfo::Common::gdt('April'),
     Texinfo::Common::gdt('May'),
     Texinfo::Common::gdt('June'),
     Texinfo::Common::gdt('July'),
     Texinfo::Common::gdt('August'),
     Texinfo::Common::gdt('September'),
     Texinfo::Common::gdt('October'),
     Texinfo::Common::gdt('November'),
     Texinfo::Common::gdt('December')
    );

# this method requires a converter.
sub expand_today($)
{
  my $self = shift;
  if ($self->get_conf('TEST')) {
    return {'text' => 'a sunny day'};
  }

  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)
    = ($ENV{SOURCE_DATE_EPOCH}
        ? gmtime($ENV{SOURCE_DATE_EPOCH})
        : localtime(time));
  # See https://reproducible-builds.org/specs/source-date-epoch/.

  $year += ($year < 70) ? 2000 : 1900;
  return $self->cdt('{month} {day}, {year}',
          { 'month' => $self->cdt($month_name[$mon]),
            'day' => {'text' => $mday}, 'year' => {'text' => $year} });
}

sub definition_arguments_content($)
{
  my $element = shift;

  my ($category, $class, $type, $name, $args);
  return ($category, $class, $type, $name, $args)
     if (!$element->{'args'}->[0]->{'contents'});

  my @args = @{$element->{'args'}->[0]->{'contents'}};
  while (@args) {
    my $arg_type = $args[0]->{'type'};
    if ($arg_type eq 'def_category') {
      $category = shift @args;
    } elsif ($arg_type eq 'def_class') {
      $class = shift @args;
    } elsif ($arg_type eq 'def_type') {
      $type = shift @args;
    } elsif ($arg_type eq 'def_name') {
      $name = shift @args;
    } elsif ($arg_type eq 'def_arg' or $arg_type eq 'def_typearg'
             or $arg_type eq 'delimiter') {
      last;
    }
    shift @args;
  }
  if (scalar(@args) > 0) {
    $args = {'contents' => \@args};
  }
  return ($category, $class, $type, $name, $args);
}

# $SELF converter argument is optional
sub definition_category_tree($$)
{
  my $self = shift;
  my $current = shift;

  return undef if (!$current->{'args'}->[0]->{'contents'});

  # NOTE we take care of not changing the parent of the tree elements.
  # We could also copy them and set the parent (as in the XS code).

  my $arg_category;
  my $arg_class;
  foreach my $arg (@{$current->{'args'}->[0]->{'contents'}}) {
    my $type = $arg->{'type'};
    if ($type eq 'def_category') {
      $arg_category = $arg;
    } elsif ($type eq 'def_class') {
      $arg_class = $arg;
    } elsif ($type eq 'space') {
    } elsif ($type eq 'def_arg' or $type eq 'def_typearg'
             or $type eq 'delimiter') {
      last;
    }
  }

  return $arg_category
    if (!defined($arg_class));

  my $arg_class_code;
  if (! $self) {
    $arg_class_code = {'cmdname' => 'code'};
    my $brace_arg
      = {'type' => 'brace_container', 'contents' => [$arg_class],
         'parent' => $arg_class_code};
    $arg_class_code->{'args'} = [$brace_arg];
  }

  my $def_command = $current->{'extra'}->{'def_command'};
  if ($def_command eq 'defop'
      or $def_command eq 'deftypeop'
      or $def_command eq 'defmethod'
      or $def_command eq 'deftypemethod') {
    my $substrings = {'category' => $arg_category, 'class' => $arg_class};
    if ($self) {
      # TRANSLATORS: association of a method or operation name with a class
      # in descriptions of object-oriented programming methods or operations.
      return $self->cdt('{category} on @code{{class}}', $substrings);
    } else {
      my $tree = Texinfo::Translations::gdt('{category} on @code{{class}}',
                                 $current->{'extra'}->{'documentlanguage'},
                                 $substrings);
      return $tree;
    }
  } elsif ($def_command eq 'defivar'
           or $def_command eq 'deftypeivar'
           or $def_command eq 'defcv'
           or $def_command eq 'deftypecv') {
    my $substrings = {'category' => $arg_category, 'class' => $arg_class};
    if ($self) {
      # TRANSLATORS: association of a variable or instance variable with
      # a class in descriptions of object-oriented programming variables
      # or instance variable.
      return $self->cdt('{category} of @code{{class}}', $substrings);
    } else {
      return Texinfo::Translations::gdt('{category} of @code{{class}}',
                                 $current->{'extra'}->{'documentlanguage'},
                                 $substrings);
      #my $result = {};
      #$result->{'contents'}
      #  = [$arg_category, {'text' => ' of ', 'parent' => $result},
      #     $arg_class_code];
      #return $result;
    }
  }
}

# find the accent commands stack and the innermost text contents
sub find_innermost_accent_contents($)
{
  my $current = shift;

  my @accent_commands = ();
  my $debug = 0;
 ACCENT:
  while (1) {
    # the following can happen if called with a bad tree
    if (!$current->{'cmdname'}
        or !$Texinfo::Commands::accent_commands{$current->{'cmdname'}}) {
      #print STDERR "BUG: Not an accent command in accent\n";
      cluck "BUG: Not an accent command in accent\n";
      #print STDERR Texinfo::Convert::Texinfo::convert_to_texinfo($current)."\n";
      #print STDERR Data::Dumper->Dump([$current]);
      return (undef, \@accent_commands);
    }
    push @accent_commands, $current;
    # A bogus accent, that may happen
    if (!$current->{'args'}) {
      return (undef, \@accent_commands);
    }
    my $arg = $current->{'args'}->[0];
    if (!$arg->{'contents'}) {
      return (undef, \@accent_commands);
    }
    # inside the argument of an accent
    my $text_contents = [];
    foreach my $content (@{$arg->{'contents'}}) {
      if (!exists($content->{'text'}) and $content->{'cmdname'}) {
        if ($Texinfo::Commands::accent_commands{$content->{'cmdname'}}) {
        # if accent is tieaccent, keep everything and do not try to
        # nest more
          if ($current->{'cmdname'} ne 'tieaccent') {
            $current = $content;
            next ACCENT;
          }
        } elsif ($content->{'cmdname'} eq 'c'
                 or $content->{'cmdname'} eq 'comment') {
          next;
        }
      }
      push @$text_contents, $content;
    }
    # we go here if there was no nested accent
    return ({'contents' => $text_contents}, \@accent_commands);
  }
}

# $CONVERTER is optional, but without this
# argument and the 'INCLUDE_DIRECTORIES' available through
# get_conf(), the included file can only be found in specific
# circumstances.
sub expand_verbatiminclude($$)
{
  my $converter = shift;
  my $current = shift;

  return undef unless ($current->{'extra'}
                       and defined($current->{'extra'}->{'text_arg'}));
  my $file_name_text = $current->{'extra'}->{'text_arg'};

  my $input_encoding
    = Texinfo::Common::element_associated_processing_encoding($current);

  my ($file_name, $file_name_encoding)
    = encoded_input_file_name($converter,
                              $file_name_text, $input_encoding);

  my $file = Texinfo::Common::locate_include_file($file_name,
                          $converter->get_conf('INCLUDE_DIRECTORIES'));

  my $verbatiminclude;

  if (defined($file)) {
    if (!open(VERBINCLUDE, $file)) {
      if ($converter) {
        my $decoded_file = $file;
        # need to decode to the internal perl codepoints for error message
        $decoded_file = Encode::decode($file_name_encoding, $file)
           if (defined($file_name_encoding));
        $converter->converter_line_error(
                      sprintf(__("could not read %s: %s"), $decoded_file, $!),
                      $current->{'source_info'});
      }
    } else {
      if (defined($input_encoding)) {
        binmode(VERBINCLUDE, ":encoding($input_encoding)");
      }
      $verbatiminclude = { 'cmdname' => 'verbatim',
                           'parent' => $current->{'parent'},
                           'contents' => [],
                         };
      while (<VERBINCLUDE>) {
        push @{$verbatiminclude->{'contents'}},
                  {'type' => 'raw', 'text' => $_ };
      }
      if (!close (VERBINCLUDE)) {
        if ($converter) {
          my $decoded_file = $file;
          # need to decode to the internal perl codepoints for error message
          $decoded_file = Encode::decode($file_name_encoding, $file)
             if (defined($file_name_encoding));
          $converter->converter_document_warn(
                 sprintf(__(
                      "error on closing \@verbatiminclude file %s: %s"),
                          $decoded_file, $!));
        }
      }
    }
  } elsif ($converter) {
    $converter->converter_line_error(
                           sprintf(__("\@%s: could not find %s"),
                                       $current->{'cmdname'}, $file_name_text),
                           $current->{'source_info'});
  }
  return $verbatiminclude;
}

# $TEXT can be indented, however this can only happen for
# *heading headings, which are not numbered.  If it was not the case,
# the code would need to be changed.
sub add_heading_number($$$;$)
{
  my $self = shift;
  my $current = shift;
  my $text = shift;
  my $numbered = shift;

  my $number;
  if ($current->{'extra'}
      and defined($current->{'extra'}->{'section_number'})
      and ($numbered or !defined($numbered))) {
    $number = $current->{'extra'}->{'section_number'};
  }

  my $result;
  if ($self) {
    # NOTE we reach here when called from Texinfo::Convert::Text
    # only if associated with a converter.  This should not happen
    # for sectioning commands, so in practice this code is not reached
    # from Texinfo::Convert::Text when called from texi2any.pl.
    # There is a test especially crafted to reach that point in
    # convert_to_text.t
    if (defined($number)) {
      if ($current->{'cmdname'} eq 'appendix'
          and $current->{'extra'}->{'section_level'} == 1) {
        $result = $self->cdt_string('Appendix {number} {section_title}',
                   {'number' => $number, 'section_title' => $text});
      } else {
        $result = $self->cdt_string('{number} {section_title}',
                   {'number' => $number, 'section_title' => $text});
      }
    } else {
      $result = $text;
    }
  } else {
    $result = $text;
    $result = $number.' '.$result if (defined($number));
    if ($current->{'cmdname'} eq 'appendix'
        # in case structuring code was not called could be undef
        and defined($current->{'extra'}->{'section_level'})
        and $current->{'extra'}->{'section_level'} == 1) {
      $result = 'Appendix '.$result;
    }
  }
  return $result;
}

# Similar to Texinfo::Common::is_content_empty
sub find_root_command_next_heading_command($$;$$)
{
  my $root = shift;
  my $expanded_format_raw = shift;
  my $do_not_ignore_contents = shift;
  my $do_not_ignore_index_entries = shift;

  return undef if (!$root->{'contents'});

  $expanded_format_raw = {} if (!defined($expanded_format_raw));

  foreach my $content (@{$root->{'contents'}}) {
    #print STDERR Texinfo::Common::debug_print_element($content)."\n";
    if ($content->{'cmdname'}) {
      if ($Texinfo::Commands::sectioning_heading_commands{$content->{'cmdname'}}) {
        #print STDERR "HEADING FOUND ASSOCIATED $content->{'cmdname'}\n";
        return $content;
      }
      if ($content->{'type'} and $content->{'type'} eq 'index_entry_command') {
        if ($do_not_ignore_index_entries) {
          return undef;
        } else {
          next;
        }
      }
      if (exists($Texinfo::Commands::line_commands{$content->{'cmdname'}})) {
        if ($Texinfo::Commands::formatted_line_commands{$content->{'cmdname'}}
            or $Texinfo::Commands::formattable_line_commands{$content->{'cmdname'}}
            or ($do_not_ignore_contents
                and ($content->{'cmdname'} eq 'contents'
                     or $content->{'cmdname'} eq 'shortcontents'
                     or $content->{'cmdname'} eq 'summarycontents'))) {
          return undef;
        } else {
          next;
        }
      } elsif (exists($Texinfo::Commands::nobrace_commands{$content->{'cmdname'}})) {
        if ($Texinfo::Commands::formatted_nobrace_commands{$content->{'cmdname'}}) {
          return undef;
        } else {
          next;
        }
      } elsif (exists($Texinfo::Commands::block_commands{$content->{'cmdname'}})) {
        if ($Texinfo::Commands::non_formatted_block_commands{$content->{'cmdname'}}
            or $Texinfo::Commands::block_commands{$content->{'cmdname'}} eq 'region'
            # ignored conditional
            or $Texinfo::Commands::block_commands{$content->{'cmdname'}} eq 'conditional'
            or ($Texinfo::Commands::block_commands{$content->{'cmdname'}} eq 'format_raw'
                and !$expanded_format_raw->{$content->{'cmdname'}})) {
          next;
        } else {
          return undef;
        }
      # brace commands
      } else {
        if ($Texinfo::Commands::non_formatted_brace_commands{$content->{'cmdname'}}) {
          next;
        } else {
          return undef;
        }
      }
    }
    if ($content->{'type'}) {
      if ($content->{'type'} eq 'paragraph') {
        return undef;
      }
    }
    # normally should not happen at the top level as text at top
    # level should only contain spaces (empty lines, text before
    # paragraphs).
    if ($content->{'text'} and $content->{'text'} =~ /\S/) {
      return undef;
    }
  }
  return undef;
}

# this requires a converter argument
sub encoded_output_file_name($$)
{
  my $self = shift;
  my $file_name = shift;

  my $encoding;
  my $output_file_name_encoding = $self->get_conf('OUTPUT_FILE_NAME_ENCODING');
  if ($output_file_name_encoding) {
    $encoding = $output_file_name_encoding;
  } elsif ($self->get_conf('DOC_ENCODING_FOR_OUTPUT_FILE_NAME')) {
    my $document_info;

    if ($self->{'document'}) {
      $document_info = $self->{'document'}->global_information();
    }

    $encoding = $document_info->{'input_encoding_name'}
      if ($document_info
          and defined($document_info->{'input_encoding_name'}));
  } else {
    $encoding = $self->get_conf('LOCALE_ENCODING');
  }

  return Texinfo::Common::encode_file_name($file_name, $encoding);
}

# this requires a converter argument as customization is read.
# The input file encoding can be given as $INPUT_FILE_ENCODING optional
# argument, it will be used if DOC_ENCODING_FOR_INPUT_FILE_NAME is
# undef or set.
# Reverse the decoding of the file name from the input encoding.
sub encoded_input_file_name($$;$)
{
  my $self = shift;
  my $file_name = shift;
  my $input_file_encoding = shift;

  my $encoding;
  my $input_file_name_encoding = $self->get_conf('INPUT_FILE_NAME_ENCODING');
  my $doc_encoding_for_input_file_name
    = $self->get_conf('DOC_ENCODING_FOR_INPUT_FILE_NAME');

  if ($input_file_name_encoding) {
    $encoding = $input_file_name_encoding;

  # not defined DOC_ENCODING_FOR_INPUT_FILE_NAME should not happen for
  # converters inheriting from Converter, but can happen for the Text
  # converter.
  } elsif (!defined($doc_encoding_for_input_file_name)
           or $doc_encoding_for_input_file_name) {
    if (defined($input_file_encoding)) {
      $encoding = $input_file_encoding;
    } else {
      my $document_info;

      if ($self->{'document'}) {
        $document_info = $self->{'document'}->global_information();
      }

      $encoding = $document_info->{'input_encoding_name'}
        if ($document_info
          and defined($document_info->{'input_encoding_name'}));
    }
  } else {
    $encoding = $self->get_conf('LOCALE_ENCODING');
  }

  return Texinfo::Common::encode_file_name($file_name, $encoding);
}

# this requires a converter argument.  It is defined here, in order
# to hide from the caller the 'translated_commands' converter key
# that is set by Texinfo::Convert::Converter.  This is especially
# relevant for converters that do not inherit Texinfo::Convert::Converter
# and call the method on a converter object they got (case of
# Texinfo::Convert::Text).
sub translated_command_tree($$)
{
  my $self = shift;
  my $cmdname = shift;
  if ($self->{'translated_commands'}
      and $self->{'translated_commands'}->{$cmdname}) {
    return $self->cdt($self->{'translated_commands'}->{$cmdname});
  }
  return undef;
}

1;

__END__

=head1 NAME

Texinfo::Convert::Utils - miscellaneous functions usable in all converters

=head1 SYNOPSIS

  use Texinfo::Convert::Utils;

  my $today_tree = Texinfo::Convert::Utils::expand_today($converter);
  my $verbatiminclude_tree
     = Texinfo::Convert::Utils::expand_verbatiminclude($converter,
                                                       $verbatiminclude);

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

Miscellaneous methods that may be useful for backends converting Texinfo
trees.  This module contains the methods that can be used in converters
which do not inherit from L<Texinfo::Convert::Converter>.

=head1 METHODS

No method is exported in the default case.

Most methods takes a I<$converter> as argument, in some cases optionally,
to get some information, see
L<Texinfo::Convert::Converter/Getting and setting customization variables>
and use methods for error reporting, see L<Texinfo::Convert::Converter>
and L<Texinfo::Report>, and for
strings translations, see L<Texinfo::Translations>.

Even when the caller does not inherit from L<Texinfo::Convert::Converter>, it
could implement the required interfaces and could also have a converter
available in some cases, to call the functions which require a converter.

=over

=item $result = add_heading_number($converter, $heading_element, $heading_text, $do_number)
X<C<add_heading_number>>

The I<$converter> argument may be undef.  I<$heading_element> is
a heading command tree element.  I<$heading_text> is the already
formatted heading text.  if the I<$do_number> optional argument is
defined and false, no number is used and the text is returned as is.
This function returns the heading with a number and the appendix
part if needed.  If I<$converter> is not defined, the resulting
string won't be translated.

=item ($category, $class, $type, $name, $arguments) = definition_arguments_content($element)
X<C<definition_arguments_content>>

I<$element> should be a C<@def*> Texinfo tree element.  The
I<$category>, I<$class>, I<$type>, I<$name> are elements corresponding
to the definition @-command line.  Texinfo elements
on the @-command line corresponding to arguments in the function
definition are returned in the I<$arguments> element.
Arguments correspond to text following the other elements
on the @-command line.  If there is no argument, I<$arguments>
will be C<undef>.

=item $tree = definition_category_tree($converter, $def_line)
X<C<definition_category_tree>>

The I<$converter> argument may be undef.  I<$def_line> is a
C<def_line> Texinfo tree container.  This function
returns a Texinfo tree corresponding to the category of the
I<$def_line> taking the class into account, if there is one.
If I<$converter> is not defined, the resulting string won't be
translated.

=item ($encoded_name, $encoding) = $converter->encoded_input_file_name($character_string_name, $input_file_encoding)

=item ($encoded_name, $encoding) = $converter->encoded_output_file_name($character_string_name)
X<C<encoded_input_file_name>> X<C<encoded_output_file_name>>

Encode I<$character_string_name> in the same way as other file names are
encoded in converters, based on customization variables, and possibly
on the input file encoding.  Return the encoded name and the encoding
used to encode the name.  The C<encoded_input_file_name> and
C<encoded_output_file_name> functions use different customization variables to
determine the encoding.  The I<$converter> argument is not optional
and is used both to access to customization variables and to access to parser
information.

The I<$input_file_encoding> argument is optional.  If set, it is used for
the input file encoding.  It is useful if there is more precise information
on the input file encoding where the file name appeared.

=item $tree = expand_today($converter)
X<C<expand_today>>

Expand today's date, as a Texinfo tree with translations.  The I<$converter>
argument is not optional and is used both to retrieve customization information
and to translate strings.

=item $tree = expand_verbatiminclude($converter, $verbatiminclude)
X<C<expand_verbatiminclude>>

The I<$converter> argument is required and is used to output error messages and
retrieve customization information L<Texinfo::Convert::Converter/Getting and
setting customization variables>.  I<$verbatiminclude> is a C<@verbatiminclude>
tree element.  This function returns a C<@verbatim> tree elements after finding
the included file and reading it.

=item ($contents_element, \@accent_commands) = find_innermost_accent_contents($element)
X<C<find_innermost_accent_contents>>

I<$element> should be an accent command Texinfo tree element.  Returns
an element containing the innermost accent @-command contents,
normally a text element with one or two letter, and an array reference
containing the accent commands nested in I<$element> (including
I<$element>).  If there is no argument at all for the accent command,
I<$contents_element> is C<undef>.

=item $heading_element = find_root_command_next_heading_command($element, $expanded_format_raw, $do_not_ignore_contents, $do_not_ignore_index_entries)

Return an heading element found in the I<$element> contents if it
appears before contents that could be formatted.  I<$expanded_format_raw>
is a hash reference with raw output formats (html, docbook, xml...) as
keys, associated value should be set for expanded raw output formats.
I<$do_not_ignore_contents> is optional.  If set, C<@contents> and
C<@shortcontents> are considered to be formatted.
I<$do_not_ignore_index_entries> is optional.  If set, index entries
are considered to be formatted.

Only heading elements corresponding to C<@heading>, C<@subheading> and similar
@-commands that are not associated to nodes in general are found, not
sectioning commands.

=back

=head1 SEE ALSO

L<Texinfo::Convert::Converter> and L<Texinfo::Translations>.

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
