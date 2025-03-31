# Converter.pm: Common code for Converters.
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

package Texinfo::Convert::Converter;

use 5.006;
use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

# for fileparse
use File::Basename;
# for file names portability
use File::Spec;
use Encode qw(decode);
# for dclone
use Storable;
#use Data::Dumper;

use Carp qw(cluck confess);

use Texinfo::Convert::ConvertXS;
use Texinfo::XSLoader;

use Texinfo::Options;
use Texinfo::Common;

use Texinfo::Report;

use Texinfo::Convert::Utils;
use Texinfo::Convert::Unicode;
use Texinfo::Convert::Texinfo;
use Texinfo::Convert::Text;
use Texinfo::Convert::NodeNameNormalization;
use Texinfo::OutputUnits;

use Texinfo::Translations;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
xml_protect_text
xml_comment
xml_accent
xml_accents
);

our $VERSION = '7.2';

my $XS_convert = Texinfo::XSLoader::XS_convert_enabled();

our $module_loaded = 0;

my %XS_overrides = (
  # fully overriden for all the converters
  "Texinfo::Convert::Converter::_generic_converter_init",
   => "Texinfo::Convert::ConvertXS::generic_converter_init",
  "Texinfo::Convert::Converter::set_document"
   => "Texinfo::Convert::ConvertXS::converter_set_document",
  "Texinfo::Convert::Converter::set_conf"
   => "Texinfo::Convert::ConvertXS::set_conf",
  "Texinfo::Convert::Converter::force_conf"
   => "Texinfo::Convert::ConvertXS::force_conf",
  "Texinfo::Convert::Converter::get_conf"
   => "Texinfo::Convert::ConvertXS::get_conf",
  "Texinfo::Convert::Converter::get_converter_errors"
   => "Texinfo::Convert::ConvertXS::get_converter_errors",
  "Texinfo::Convert::Converter::converter_line_error"
   => "Texinfo::Convert::ConvertXS::converter_line_error",
  "Texinfo::Convert::Converter::converter_line_warn"
   => "Texinfo::Convert::ConvertXS::converter_line_warn",
  "Texinfo::Convert::Converter::converter_document_error"
   => "Texinfo::Convert::ConvertXS::converter_document_error",
  "Texinfo::Convert::Converter::converter_document_warn"
   => "Texinfo::Convert::ConvertXS::converter_document_warn",
  "Texinfo::Convert::Converter::get_converter_indices_sorted_by_letter"
   => "Texinfo::Convert::ConvertXS::get_converter_indices_sorted_by_letter",
  "Texinfo::Convert::Converter::get_converter_indices_sorted_by_index"
   => "Texinfo::Convert::ConvertXS::get_converter_indices_sorted_by_index",
  "Texinfo::Convert::Converter::set_global_document_commands"
   => "Texinfo::Convert::ConvertXS::converter_set_global_document_commands",

  # XS only
  "Texinfo::Convert::Converter::reset_converter"
   => "Texinfo::Convert::ConvertXS::reset_converter",
  "Texinfo::Convert::Converter::destroy"
   => "Texinfo::Convert::ConvertXS::destroy",

  "Texinfo::Convert::Converter::XS_get_unclosed_stream"
   => "Texinfo::Convert::ConvertXS::get_unclosed_stream",
);

sub import {
  if (!$module_loaded) {
    if ($XS_convert) {
      foreach my $sub (keys %XS_overrides) {
        Texinfo::XSLoader::override ($sub, $XS_overrides{$sub});
      }
    }

    $module_loaded = 1;
  }
  # The usual import method
  goto &Exporter::import;
}

# values for integer and string options in code generated from
# Texinfo/Convert/converters_defaults.txt
my $regular_defaults
  = Texinfo::Options::get_converter_regular_options('converter');

my %defaults = %$regular_defaults;

# values for integer and string options in code generated from
# Texinfo/Convert/converters_defaults.txt
my $common_defaults = Texinfo::Options::get_converter_regular_options('common');

# defaults for all converters that are not defined elsewhere.
# undef values in general marks information passed by the caller that
# is valid in the initialization hash, but is not considered
# as "configuration/customization". It is not available through get_conf()
# but is available directly in the converter as a hash key.
# FIXME separate the two types of information and check that those
# items are not valid customization options?  Or make them customization
# variables that can only be set from init files, like buttons or icons?
# NOTE converters for now only set customization variables.
# It would be good to keep it that way.
my %common_converters_defaults = (
  # Following are set in the main program
  'deprecated_config_directories' => undef,

  # Not set in the main program
  'translated_commands'  => {'error' => 'error@arrow{}',},

# integer and string customization variables common for all the converters
# with values different from main program values
  %$common_defaults
);

my %all_converters_defaults
 = (%Texinfo::Options::converter_cmdline_options,
    %Texinfo::Options::converter_customization_options,
    %Texinfo::Options::unique_at_command_options,
    %Texinfo::Options::multiple_at_command_options,
    %common_converters_defaults
);

# For translation of in document string.
if (0) {
  my $self;
  # TRANSLATORS: expansion of @error{} as Texinfo code
  $self->cdt('error@arrow{}');
}

our %default_args_code_style = (
  'email' => [1],
  'anchor' => [1],
  'uref' => [1],
  'url' => [1],
  'math' => [1],
  'inforef' => [1,undef,1],
  'image' => [1, 1, 1, undef, 1],
# and type?
  'float' => [1],
);

foreach my $code_style_command (keys(%Texinfo::Commands::brace_code_commands)) {
  $default_args_code_style{$code_style_command} = [1];
}
foreach my $ref_cmd ('pxref', 'xref', 'ref') {
  $default_args_code_style{$ref_cmd} = [1, undef, undef, 1];
}

################################################################
# converter API

# convert_tree() and convert() should be implemented in converters.
# There is an implementation of output() below but in general
# output() should also be implemented by Converters.  The simple
# implementation of convert_output_unit() below is likely to be
# ok for most converters.

# Functions that should be defined in specific converters
sub converter_defaults($$)
{
  return \%defaults;
}

# should be redefined by specific converters
sub converter_initialize($)
{
}

sub conversion_initialization($;$)
{
  my $converter = shift;
  my $document = shift;

  if ($document) {
    $converter->set_document($document);
  }
}

sub conversion_finalization($)
{
  #my $converter = shift;
}

sub output_internal_links($)
{
  my $self = shift;
  return undef;
}

sub set_document($$)
{
  my $converter = shift;
  my $document = shift;

  $converter->{'document'} = $document;

  Texinfo::Common::set_output_encoding($converter, $document);

  $converter->{'convert_text_options'}
     = Texinfo::Convert::Text::copy_options_for_convert_text($converter);

  # In general, OUTPUT_PERL_ENCODING set below is needed for the output()
  # entry point through Texinfo::Convert::Utils::output_files_open_out.  It is
  # also sometime needed for the converter itself.  If not, in general it
  # is not needed for the convert() entry point, so the call could also be
  # done more finely in converters, but it is not really important.
  Texinfo::Common::set_output_perl_encoding($converter);
}

# initialization either in generic XS converter or in Perl
sub _generic_converter_init($$;$)
{
  my $converter = shift;
  my $format_defaults = shift;
  my $conf = shift;

  my %defaults = %all_converters_defaults;

  if ($format_defaults) {
    foreach my $key (keys(%$format_defaults)) {
      $defaults{$key} = $format_defaults->{$key};
    }
  }
  $converter->{'conf'} = {};
  foreach my $key (keys(%defaults)) {
    if (Texinfo::Common::valid_customization_option($key)) {
      $converter->{'conf'}->{$key} = $defaults{$key};
    } else {
      $converter->{$key} = $defaults{$key};
    }
  }

  $converter->{'configured'} = {};
  if (defined($conf)) {
    foreach my $key (keys(%$conf)) {
      if (Texinfo::Common::valid_customization_option($key)) {
        $converter->{'conf'}->{$key} = $conf->{$key};
      } elsif (!exists($defaults{$key})) {
        my $class = ref($converter);
        warn "$class: $key not a possible configuration\n";
      } else {
        $converter->{$key} = $conf->{$key};
      }
      # configuration set here, from the argument of the converter,
      # in general coming from command-line or from init files will not
      # be reset by set_conf.
      $converter->{'configured'}->{$key} = 1;
    }
  }
  # set $converter->{'converter_init_conf'} to the customization
  # options obtained after setting the defaults and applying
  # the customization passed as argument.
  $converter->{'converter_init_conf'} = { %{$converter->{'conf'}} };

  # used for output files information, to register opened
  # and not closed files.  Accessed through output_files_information()
  $converter->{'output_files'}
    = Texinfo::Convert::Utils::output_files_initialize();

  # setup expanded formats as a hash.
  my $expanded_formats = $converter->{'conf'}->{'EXPANDED_FORMATS'};
  $converter->{'expanded_formats'} = {};
  if (defined($expanded_formats)) {
    foreach my $expanded_format (@$expanded_formats) {
      $converter->{'expanded_formats'}->{$expanded_format} = 1;
    }
  }

  $converter->{'error_warning_messages'} = [];
}

# this function is designed so as to be used in specific Converters
# and not redefined.
sub converter($;$)
{
  my $class = shift;
  my $conf = shift;

  my $converter = {};

  bless $converter, $class;

  my $format_defaults = $converter->converter_defaults($conf);

  _generic_converter_init($converter, $format_defaults, $conf);

  $converter->converter_initialize();

  return $converter;
}

sub convert_output_unit($$)
{
  my $self = shift;
  my $output_unit = shift;

  my $result = '';
  foreach my $element (@{$output_unit->{'unit_contents'}}) {
    $result .= $self->convert_tree($element);
  }
  return $result;
}

# should be redefined by specific converters
sub conversion_output_begin($;$$)
{
  my $self = shift;
  my $output_file = shift;
  my $output_filename = shift;

  return '';
}

sub conversion_output_end($)
{
  my $self = shift;

  return '';
}

sub output_tree($$)
{
  my $self = shift;
  my $document = shift;

  $self->conversion_initialization($document);

  my $root = $document->tree();

  my ($output_file, $destination_directory, $output_filename)
    = $self->determine_files_and_directory(
                              $self->get_conf('TEXINFO_OUTPUT_FORMAT'));

  my ($encoded_destination_directory, $dir_encoding)
    = $self->encoded_output_file_name($destination_directory);
  my $succeeded
    = $self->create_destination_directory($encoded_destination_directory,
                                          $destination_directory);
  unless ($succeeded) {
    $self->conversion_finalization();
    return undef;
  }

  my $fh;
  my $encoded_output_file;
  if (! $output_file eq '') {
    my $path_encoding;
    ($encoded_output_file, $path_encoding)
      = $self->encoded_output_file_name($output_file);
    my $error_message;
    # the third return information, set if the file has already been used
    # in this files_information is not checked as this cannot happen.
    ($fh, $error_message) = Texinfo::Convert::Utils::output_files_open_out(
                              $self->output_files_information(), $self,
                              $encoded_output_file);
    if (!$fh) {
      $self->converter_document_error(
           sprintf(__("could not open %s for writing: %s"),
                                    $output_file, $error_message));
      $self->conversion_finalization();
      return undef;
    }
  }

  my $output_beginning
    = $self->conversion_output_begin($output_file, $output_filename);

  my $result = '';
  $result .= $self->write_or_return($output_beginning, $fh);
  $result .= $self->write_or_return($self->convert_tree($root), $fh);

  my $output_end = $self->conversion_output_end();

  $result .= $self->write_or_return($output_end, $fh);

  if ($fh and $output_file ne '-') {
    Texinfo::Convert::Utils::output_files_register_closed(
                  $self->output_files_information(), $encoded_output_file);
    if (!close ($fh)) {
      $self->converter_document_error(
            sprintf(__("error on closing %s: %s"),
                                    $output_file, $!));
    }
  }
  $self->conversion_finalization();
  return $result;
}

# Nothing to do in Perl.  XS function resets converter
sub reset_converter($)
{
}

# Nothing to do in Perl.  XS function frees memory
sub destroy($)
{
}

sub XS_get_unclosed_stream($$)
{
  return undef;
}

sub output_files_information($)
{
  my $self = shift;
  return $self->{'output_files'};
}




# translations

sub cdt($$;$$)
{
  my ($self, $string, $replaced_substrings, $translation_context) = @_;

  return Texinfo::Translations::gdt($string,
                                    $self->get_conf('documentlanguage'),
                                    $replaced_substrings,
                                    $self->get_conf('DEBUG'),
                                    $translation_context);
}

sub cdt_string($$;$$)
{
  my ($self, $string, $replaced_substrings, $translation_context) = @_;

  return Texinfo::Translations::gdt_string($string,
                                    $self->get_conf('documentlanguage'),
                                    $replaced_substrings,
                                    $translation_context);
}

sub pcdt($$;$$)
{
  my ($self, $translation_context, $string, $replaced_substrings) = @_;

  return $self->cdt($string, $replaced_substrings, $translation_context);
}



# errors and warnings

sub converter_line_error($$$;$)
{
  my $self = shift;
  my $text = shift;
  my $error_location_info = shift;
  my $continuation = shift;

  my $message = Texinfo::Report::format_line_message('error', $text,
                                 $error_location_info, $continuation,
                                            $self->get_conf('DEBUG'));
  push @{$self->{'error_warning_messages'}}, $message;
}

sub converter_line_warn($$$;$)
{
  my $self = shift;
  my $text = shift;
  my $error_location_info = shift;
  my $continuation = shift;

  my $message = Texinfo::Report::format_line_message('warning', $text,
                                   $error_location_info, $continuation,
                                              $self->get_conf('DEBUG'));
  push @{$self->{'error_warning_messages'}}, $message;
}

sub converter_document_error($$;$)
{
  my $self = shift;
  my $text = shift;
  my $continuation = shift;

  my $program_name;

  if ($self->get_conf('PROGRAM') && $self->get_conf('PROGRAM') ne '') {
    $program_name = $self->get_conf('PROGRAM');
  }

  my $message
      = Texinfo::Report::format_document_message('error', $text, $program_name,
                                                 $continuation);
  push @{$self->{'error_warning_messages'}}, $message;
}

sub converter_document_warn($$;$)
{
  my $self = shift;
  my $text = shift;
  my $continuation = shift;

  my $program_name;

  if ($self->get_conf('PROGRAM') && $self->get_conf('PROGRAM') ne '') {
    $program_name = $self->get_conf('PROGRAM');
  }

  my $message
      = Texinfo::Report::format_document_message('warning', $text,
                                        $program_name, $continuation);
  push @{$self->{'error_warning_messages'}}, $message;
}

sub get_converter_errors($)
{
  my $self = shift;
  return $self->{'error_warning_messages'};
}



###############################################################
# Implementation of the customization API that is used in many
# Texinfo modules

# Unknown variables can only happen when called from init files.  From
# command-line checks are done before.

sub get_conf($$)
{
  my $self = shift;
  my $var_name = shift;

  if (!Texinfo::Common::valid_customization_option($var_name)) {
    $self->converter_document_error(sprintf(__(
                       "unknown customization variable: %s"),
                                      $var_name));
    if ($self->{'conf'}->{'TEST'}) {
      cluck ("BUG: get_conf: unknown customization variable: $var_name");
    }
    return undef;
  }

  return $self->{'conf'}->{$var_name};
}

sub set_conf($$$)
{
  my $self = shift;
  my $var_name = shift;
  my $value = shift;

  if (!Texinfo::Common::valid_customization_option($var_name)) {
    $self->converter_document_error(sprintf(__(
                       "unknown customization variable: %s"),
                                      $var_name));
    if ($self->{'conf'}->{'TEST'}) {
      cluck ("BUG: set_conf: unknown customization variable: $var_name");
    }
    return 0;
  }

  if ($self->{'configured'}->{$var_name}) {
    return 0;
  } else {
    $self->{'conf'}->{$var_name} = $value;
    return 1;
  }
}

sub force_conf($$$)
{
  my $self = shift;
  my $var_name = shift;
  my $value = shift;

  if (!Texinfo::Common::valid_customization_option($var_name)) {
    $self->converter_document_error(sprintf(__(
                       "unknown customization variable: %s"),
                                      $var_name));
    if ($self->{'conf'}->{'TEST'}) {
      cluck ("BUG: force_conf: unknown customization variable: $var_name");
    }
    return 0;
  }

  $self->{'conf'}->{$var_name} = $value;
  return 1;
}



#####################################################################
# Elements and output units file names
#
# - default file names setting for sectioning commands and nodes
# - output units files API
# - set_output_units_files, which uses both default file names setting
#   and output units files API

sub _id_to_filename($$)
{
  my $self = shift;
  my $id = shift;
  my $basefilename_length = $self->get_conf('BASEFILENAME_LENGTH');
  if (defined($basefilename_length) and $basefilename_length >= 0) {
    return substr($id, 0, $basefilename_length);
  } else {
    return $id;
  }
}

sub normalized_sectioning_command_filename($$)
{
  my $self = shift;
  my $command = shift;
  my $no_unidecode;

  $no_unidecode = 1 if (defined($self->get_conf('USE_UNIDECODE'))
                        and !$self->get_conf('USE_UNIDECODE'));

  my $normalized_name
    = Texinfo::Convert::NodeNameNormalization::normalize_transliterate_texinfo(
         {'contents' => $command->{'args'}->[0]->{'contents'}},
                  $no_unidecode);

  my $filename = $self->_id_to_filename($normalized_name);
  $filename .= '.'.$self->get_conf('EXTENSION')
    if (defined($self->get_conf('EXTENSION'))
      and $self->get_conf('EXTENSION') ne '');
  return ($normalized_name, $filename);
}

sub node_information_filename($$$)
{
  my $self = shift;
  my $normalized = shift;
  my $label_element = shift;

  my $no_unidecode;
  $no_unidecode = 1 if (defined($self->get_conf('USE_UNIDECODE'))
                        and !$self->get_conf('USE_UNIDECODE'));

  my $filename;
  if (defined($normalized)) {
    if ($self->get_conf('TRANSLITERATE_FILE_NAMES')) {
      $filename
  = Texinfo::Convert::NodeNameNormalization::normalize_transliterate_texinfo(
       {'contents' => $label_element->{'contents'}},
            $no_unidecode);
    } else {
      $filename = $normalized;
    }
  } elsif (defined($label_element)) {
    $filename = Texinfo::Convert::NodeNameNormalization::convert_to_identifier(
             { 'contents' => $label_element->{'contents'} });
  } else {
    $filename = '';
  }
  $filename = $self->_id_to_filename($filename);
  return $filename;
}

sub top_node_filename($$)
{
  my $self = shift;
  my $document_name = shift;

  if (defined($self->get_conf('TOP_FILE'))
      and $self->get_conf('TOP_FILE') ne '') {
    return $self->get_conf('TOP_FILE');
  } elsif (defined($document_name)) {
    my $top_node_filename = $document_name;
    if (defined($self->get_conf('EXTENSION'))
        and $self->get_conf('EXTENSION') ne '') {
      $top_node_filename .= '.'.$self->get_conf('EXTENSION')
    }
    return $top_node_filename
  }
  return undef;
}

sub initialize_output_units_files($)
{
  my $self = shift;

  $self->{'out_filepaths'} = {};
  $self->{'file_counters'} = {};
  $self->{'filenames'} = {};
}

# If CASE_INSENSITIVE_FILENAMES is set, reuse the first
# filename with the same name insensitive to the case.
sub register_normalize_case_filename($$)
{
  my $self = shift;
  my $filename = shift;

  if ($self->get_conf('CASE_INSENSITIVE_FILENAMES')) {
    if (exists($self->{'filenames'}->{lc($filename)})) {
      if ($self->get_conf('DEBUG')) {
        print STDERR "Reusing case-insensitive ".
                   $self->{'filenames'}->{lc($filename)}." for $filename\n";
      }
      $filename = $self->{'filenames'}->{lc($filename)};
    } else {
      $self->{'filenames'}->{lc($filename)} = $filename;
    }
  } else {
    if (exists($self->{'filenames'}->{$filename})) {
      if ($self->get_conf('DEBUG')) {
        print STDERR "Reusing ".$self->{'filenames'}->{$filename}
                     ." for $filename\n";
      }
    } else {
      $self->{'filenames'}->{$filename} = $filename;
    }
  }
  return $filename;
}

# return the registered filename if there is one, else return undef.
# Note that it only tells that a file name has been its name considered,
# not that the corresponding file is created.
# currently unused.
sub registered_filename($$)
{
  my $self = shift;
  my $filename = shift;

  if ($self->get_conf('CASE_INSENSITIVE_FILENAMES')) {
    if (exists($self->{'filenames'}->{lc($filename)})) {
      return $self->{'filenames'}->{lc($filename)};
    }
  } elsif (exists($self->{'filenames'}->{$filename})) {
    return $self->{'filenames'}->{$filename};
  }
  return undef;
}

# Sets $output_unit->{'unit_filename'}.
sub set_output_unit_file($$$)
{
  my $self = shift;
  my $output_unit = shift;
  my $filename = shift;

  if (!defined($filename)) {
    cluck("set_output_unit_file: filename not defined\n");
  }
  if (!defined($output_unit)) {
    cluck("set_output_unit_file: output_unit not defined\n");
  }

  $filename = $self->register_normalize_case_filename($filename);

  # This should never happen, set_output_unit_file is called once per
  # tree unit.
  if (exists($output_unit->{'unit_filename'})) {
    if ($output_unit->{'unit_filename'} eq $filename) {
      print STDERR "set_output_unit_file: already set: $filename\n"
         if ($self->get_conf('DEBUG'));
    } else {
      print STDERR  "set_output_unit_file: unit_filename reset: "
        .$output_unit->{'unit_filename'}.", $filename\n"
           if ($self->get_conf('DEBUG'));
    }
  }
  $output_unit->{'unit_filename'} = $filename;
}

# sets out_filepaths converter state, associating a file name
# to a file path.
# $FILEPATH can be given explicitly, otherwise it is based on $FILENAME
# and $DESTINATION_DIRECTORY
sub set_file_path($$$;$)
{
  my $self = shift;
  my $filename = shift;
  my $destination_directory = shift;
  my $filepath = shift;

  if (!defined($filename)) {
    cluck("set_file_path: filename not defined\n");
  }

  $filename = $self->register_normalize_case_filename($filename);

  if (not defined($filepath)) {
    if (defined($destination_directory) and $destination_directory ne '') {
      $filepath = join('/', ($destination_directory, $filename));
    } else {
      $filepath = $filename;
    }
  }
  # the file path should be set only once per file name.  With
  # CASE_INSENSITIVE_FILENAMES the same file path can appear more
  # than once when files differ in case.
  if (defined($self->{'out_filepaths'}->{$filename})) {
    if ($self->{'out_filepaths'}->{$filename} eq $filepath) {
      print STDERR "set_file_path: filepath set: $filepath\n"
         if ($self->get_conf('DEBUG'));
    } else {
      print STDERR  "set_file_path: filepath reset: "
        .$self->{'out_filepaths'}->{$filename}.", $filepath\n"
         if ($self->get_conf('DEBUG'));
    }
  }
  $self->{'out_filepaths'}->{$filename} = $filepath;
}

sub _get_root_element($$)
{
  my $self = shift;
  my $command = shift;

  my $current = $command;

  while (1) {
    if ($current->{'associated_unit'}) {
      return $current->{'associated_unit'};
    }
    if ($current->{'parent'}) {
      $current = $current->{'parent'};
    } else {
      return undef;
    }
  }
}

# TODO document
# set file_counters converter state
sub set_output_units_files($$$$$$)
{
  my $self = shift;
  my $output_units = shift;
  my $output_file = shift;
  my $destination_directory = shift;
  my $output_filename = shift;
  my $document_name = shift;

  # Ensure that the document has pages
  return undef if (!defined($output_units) or !@$output_units);

  $self->initialize_output_units_files();

  my $extension = '';
  $extension = '.'.$self->get_conf('EXTENSION')
            if (defined($self->get_conf('EXTENSION'))
                and $self->get_conf('EXTENSION') ne '');

  if (!$self->get_conf('SPLIT')) {
    $self->set_file_path($output_filename, undef, $output_file);
    foreach my $output_unit (@$output_units) {
      $self->set_output_unit_file($output_unit, $output_filename);
    }
  } else {
    my $node_top;

    my $identifiers_target;
    if ($self->{'document'}) {
      $identifiers_target = $self->{'document'}->labels_information();
    }

    $node_top = $identifiers_target->{'Top'}
                            if ($identifiers_target);

    my $top_node_filename = $self->top_node_filename($document_name);
    # first determine the top node file name.
    if ($node_top and defined($top_node_filename)) {
      my ($node_top_unit) = $self->_get_root_element($node_top);
      if (!defined($node_top_unit)) {
        print STDERR "No element for top node (".scalar(@$output_units)." units)\n"
         if ($self->get_conf('DEBUG'));
      } else {
        $self->set_file_path($top_node_filename, $destination_directory);
        $self->set_output_unit_file($node_top_unit, $top_node_filename);
      }
    }
    my $file_nr = 0;
    my $previous_page;
    foreach my $output_unit (@$output_units) {
      # For Top node.
      next if (defined($output_unit->{'unit_filename'}));
      my $file_output_unit = $output_unit->{'first_in_page'};
      if (!$file_output_unit) {
        cluck ("No first_in_page for $output_unit\n");
      }
      if (!defined($file_output_unit->{'unit_filename'})) {
        foreach my $root_command (@{$file_output_unit->{'unit_contents'}}) {
          if ($root_command->{'cmdname'}
              and $root_command->{'cmdname'} eq 'node') {
            my $node_filename;
            # double node are not normalized, they are handled here
            if (!defined($root_command->{'extra'}->{'normalized'})
                or !defined($identifiers_target->{
                               $root_command->{'extra'}->{'normalized'}})) {
              $node_filename = 'unknown_node';
            } else {
              $node_filename
               = $self->node_information_filename(
                               $root_command->{'extra'}->{'normalized'},
                               $root_command->{'args'}->[0]);
            }
            $node_filename .= $extension;
            $self->set_file_path($node_filename,$destination_directory);
            $self->set_output_unit_file($file_output_unit, $node_filename);
            last;
          }
        }
        if (!defined($file_output_unit->{'unit_filename'})) {
          # use section to do the file name if there is no node
          my $command = $file_output_unit->{'unit_command'};
          if ($command) {
            if ($command->{'cmdname'} eq 'top' and !$node_top
                and defined($top_node_filename)) {
              $self->set_file_path($top_node_filename, $destination_directory);
              $self->set_output_unit_file($file_output_unit, $top_node_filename);
            } else {
              my ($normalized_name, $filename)
                 = $self->normalized_sectioning_command_filename($command);
              $self->set_file_path($filename, $destination_directory);
              $self->set_output_unit_file($file_output_unit, $filename);
            }
          } else {
            # when everything else has failed
            if ($file_nr == 0 and !$node_top and defined($top_node_filename)) {
              $self->set_file_path($top_node_filename, $destination_directory);
              $self->set_output_unit_file($file_output_unit, $top_node_filename);
            } else {
              my $filename = $document_name . "_$file_nr";
              $filename .= $extension;
              $self->set_file_path($filename, $destination_directory);
              $self->set_output_unit_file($output_unit, $filename);
            }
            $file_nr++;
          }
        }
      }
      $self->set_output_unit_file($output_unit,
                    $file_output_unit->{'unit_filename'});
    }
  }

  foreach my $output_unit (@$output_units) {
    my $output_unit_filename = $output_unit->{'unit_filename'};
    $self->{'file_counters'}->{$output_unit_filename} = 0
       if (!exists($self->{'file_counters'}->{$output_unit_filename}));
    $self->{'file_counters'}->{$output_unit_filename}++;
    print STDERR 'Page '
     # uncomment for Perl object name
     #."$output_unit "
     .Texinfo::OutputUnits::output_unit_texi($output_unit)
     .": $output_unit_filename($self->{'file_counters'}->{$output_unit_filename})\n"
              if ($self->get_conf('DEBUG'));
  }
}



#############################################################
# useful methods for Converters.
# First methods are also used in this module.

# Generic/overall document methods

sub create_destination_directory($$$)
{
  my $self = shift;
  my $destination_directory_path = shift;
  my $destination_directory_name = shift;

  if (defined($destination_directory_path)
      and ! -d $destination_directory_path) {
    if (!mkdir($destination_directory_path, oct(755))) {
      $self->converter_document_error(sprintf(__(
                                "could not create directory `%s': %s"),
                                   $destination_directory_name, $!));
      return 0;
    }
  }
  return 1;
}

# output fo $fh if defined, otherwise return the text.
sub write_or_return($$$)
{
  my $self = shift;
  my $text = shift;
  my $fh = shift;
  if ($fh) {
    print $fh $text;
    return '';
  } else {
    return $text;
  }
}

my $STDIN_DOCU_NAME = 'stdin';

# this requires a document, and is, in general, used in output(), therefore
# a document need to be associated to the converter, not only a tree.
sub determine_files_and_directory($$)
{
  my $self = shift;
  my $output_format = shift;

  # determine input file base name
  my $input_basefile;
  my $document_info;

  if ($self->{'document'}) {
    $document_info = $self->{'document'}->global_information();
  }

  if ($document_info and defined($document_info->{'input_file_name'})) {
    # 'input_file_name' is not decoded, as it is derived from input
    # file which is not decoded either.  We want to return only
    # decoded character strings such that they can easily be mixed
    # with other character strings, so we decode here.
    my $input_file_name_bytes = $document_info->{'input_file_name'};
    my $encoding = $self->get_conf('COMMAND_LINE_ENCODING');
    my $input_file_name;
    if (defined($encoding)) {
      $input_file_name = decode($encoding, $input_file_name_bytes, sub { '?' });
      # use '?' as replacement character rather than U+FFFD in case it
      # is re-encoded to an encoding without this character
    } else {
      $input_file_name = $input_file_name_bytes;
    }
    # FIXME $input_file_name is already the base file name.  Not clear how
    # this is useful.
    my ($directories, $suffix);
    ($input_basefile, $directories, $suffix) = fileparse($input_file_name);
  } else {
    # This could happen if called on a piece of Texinfo and not a full manual.
    $input_basefile = '';
  }

  my $input_basename;
  if ($input_basefile eq '-') {
    $input_basename = $STDIN_DOCU_NAME;
  } else {
    $input_basename = $input_basefile;
    $input_basename =~ s/\.te?x(i|info)?$//;
  }

  my $setfilename;
  if (defined($self->get_conf('setfilename'))) {
    $setfilename = $self->get_conf('setfilename');
  } elsif ($document_info and defined($document_info->{'setfilename'})) {
    $setfilename = $document_info->{'setfilename'};
  }

  my $input_basename_for_outfile = $input_basename;
  my $setfilename_for_outfile = $setfilename;
  # PREFIX overrides both setfilename and the input file base name
  if (defined($self->get_conf('PREFIX'))) {
    $setfilename_for_outfile = undef;
    $input_basename_for_outfile = $self->get_conf('PREFIX');
  }

  # the document path, in general the outfile without
  # extension and can be set from setfilename if outfile is not set
  my $document_path;
  # determine output file and output file name
  my $output_file;
  if (!defined($self->get_conf('OUTFILE'))) {
    if (defined($setfilename_for_outfile)) {
      $document_path = $setfilename_for_outfile;
      $document_path =~ s/\.[^\.]*$//;
      if (!$self->get_conf('USE_SETFILENAME_EXTENSION')) {
        $output_file = $document_path;
        $output_file .= '.'.$self->get_conf('EXTENSION')
          if (defined($self->get_conf('EXTENSION'))
              and $self->get_conf('EXTENSION') ne '');
      } else {
        $output_file = $setfilename_for_outfile;
      }
    } elsif ($input_basename_for_outfile ne '') {
      $output_file = $input_basename_for_outfile;
      $document_path = $input_basename_for_outfile;
      $output_file .= '.'.$self->get_conf('EXTENSION')
        if (defined($self->get_conf('EXTENSION'))
            and $self->get_conf('EXTENSION') ne '');
    } else {
      $output_file = '';
      $document_path = $output_file;
    }
    if (defined($self->get_conf('SUBDIR')) and $output_file ne '') {
      my $dir = File::Spec->canonpath($self->get_conf('SUBDIR'));
      $output_file = join('/', ($dir, $output_file));
    }
  } else {
    $document_path = $self->get_conf('OUTFILE');
    $document_path =~ s/\.[^\.]*$//;
    $output_file = $self->get_conf('OUTFILE');
  }

  # the output file path, in general same as the outfile but can be
  # set from setfilename if outfile is not set.
  my $output_filepath = $output_file;
  # in this case one wants to get the result in a string and there
  # is a setfilename.  The setfilename is used to get something.
  # This happens in the test suite.
  if ($output_file eq '' and defined($setfilename_for_outfile)) {
    $output_filepath = $setfilename_for_outfile;
    $document_path = $setfilename_for_outfile;
    $document_path =~ s/\.[^\.]*$//;
  }

  # $document_name is the name of the document, which is the output
  # file basename, $output_filename, without extension.
  my ($document_name, $output_filename, $directories, $suffix);
  # We may be handling setfilename there, so it is not obvious that we
  # want to use fileparse and not consider unixish separators.  However,
  # if this is setfilename, it should be a simple file name, so it
  # should hopefully be harmless to use fileparse
  ($document_name, $directories, $suffix) = fileparse($document_path);
  ($output_filename, $directories, $suffix) = fileparse($output_filepath);
  my $destination_directory;
  if ($self->get_conf('SPLIT')) {
    if (defined($self->get_conf('OUTFILE'))) {
      $destination_directory = $self->get_conf('OUTFILE');
    } elsif (defined($self->get_conf('SUBDIR'))) {
      $destination_directory = $self->get_conf('SUBDIR');
    } else {
      $destination_directory = $document_name;
      if (defined($output_format) and $output_format ne '') {
        $destination_directory .= '_'.$output_format;
      }
    }
  } else {
    # $output_file_filename is not used, but $output_filename should be
    # the same as long as $output_file is the same as $output_filepath
    # which is the case except if $output_file is ''.
    # Note that fileparse may return a string for the directory part even
    # for a relative file without directory, ie
    # myfile.html -> $output_dir = './'
    # In that case the $destination_directory will never be ''.
    my ($output_file_filename, $output_dir, $suffix) = fileparse($output_file);
    $destination_directory = $output_dir;
  }
  if ($destination_directory ne '') {
    $destination_directory = File::Spec->canonpath($destination_directory);
  }
  return ($output_file, $destination_directory, $output_filename,
          $document_name, $input_basefile);
}

# determine the default, with $INIT_CONF if set, or the default common
# to all the converters
sub _command_init($$)
{
  my $global_command = shift;
  my $init_conf = shift;
  if (exists($Texinfo::Common::document_settable_at_commands{$global_command})) {
    if (defined($init_conf->{$global_command})) {
      return $init_conf->{$global_command};
    } elsif (defined($Texinfo::Common::document_settable_at_commands{$global_command})) {
      return $Texinfo::Common::document_settable_at_commands{$global_command};
    }
  }
  return undef;
}

# $COMMANDS_LOCATION is 'before', 'last', 'preamble' or 'preamble_or_first'
# 'before' means setting to the values before the document commands
# (defaults and command-line).
# 'preamble' means setting sequentially to the values in the preamble.
# 'preamble_or_first'  means setting to the first value for the command
# in the document if the first command is not in the preamble, else set
# sequentially to the values in the preamble.
# 'last' means setting to the last value for the command in the document.
#
# Notice that the only effect is to use set_conf (directly or through
# set_global_document_command), no @-commands setting side effects are done
# and associated customization variables are not set/reset either.
sub set_global_document_commands($$$)
{
  my $self = shift;
  my $commands_location = shift;
  my $selected_commands = shift;

  my $init_conf;
  if (defined($self->{'output_init_conf'})) {
    # use in priority the initial customization per output
    $init_conf = $self->{'output_init_conf'};
  } else {
    $init_conf = $self->{'converter_init_conf'};
  }

  if (not defined($selected_commands)) {
    die "set_global_document_commands: requires selected commands";
  }
  if ($commands_location eq 'before') {
    foreach my $global_command (@{$selected_commands}) {
      # for commands not appearing in the document, this should set the
      # same value, the converter initialization value
      $self->set_conf($global_command, _command_init($global_command, $init_conf));
      # NOTE if the variable is set from an handler, or in the converter after
      # $init_conf was set, but before starting the conversion, it is ignored here
      # and the $init_conf value is set.  The previously set value could be
      # in $self->get_conf(), but what is available from $self->get_conf() could
      # also be a value set by a previous call of set_global_document_commands.
      # There is no easy way to deal with this issue, other than making sure that
      # a customization value that is expected to be set early is set in $init_conf.
    }
  } else {
    my $global_commands;
    if ($self->{'document'}) {
      $global_commands = $self->{'document'}->global_commands_information();
    }
    foreach my $global_command (@{$selected_commands}) {
      if ($self->get_conf('DEBUG')) {
        print STDERR "SET_global($commands_location) $global_command\n";
      }

      my $element;
      if ($global_commands) {
        $element = Texinfo::Common::set_global_document_command($self,
                  $global_commands, $global_command, $commands_location);
      }
      if (not defined($element)) {
        # commands not appearing in the document, this should set the
        # same value, the converter initialization value
        # the NOTE above in 'before' holds here too.
        $self->set_conf($global_command,
                        _command_init($global_command, $init_conf));
      }
    }
  }
}

sub present_bug_message($$;$)
{
  my $self = shift;
  my $message = shift;
  my $current = shift;

  my $line_message = '';
  my $current_element_message = '';
  if ($current) {
    if ($current->{'source_info'}) {
      my $source_info = $current->{'source_info'};
      my $file = $source_info->{'file_name'};
      $line_message
        = "in: $source_info->{'file_name'}:$source_info->{'line_nr'}";
      if ($source_info->{'macro'} ne '') {
        $line_message .= " (possibly involving $source_info->{'macro'})";
      }
      $line_message .= "\n";
    }
    if ($current) {
      $current_element_message = "current: ".
        Texinfo::Common::debug_print_element($current, 1);
    }
  }
  my $additional_information = '';
  if ($line_message.$current_element_message ne '') {
    $additional_information = "Additional information:\n".
       $line_message.$current_element_message."\n";
  }
  warn "You found a bug: $message\n\n".$additional_information;
}

# Reverse the decoding of the file name from the input encoding.
# A wrapper around Texinfo::Utils::encoded_input_file_name() that
# can be called in converters through an objet oriented syntax.
sub encoded_input_file_name($$;$)
{
  my $self = shift;
  my $file_name = shift;
  my $input_file_encoding = shift;

  return Texinfo::Convert::Utils::encoded_input_file_name($self, $file_name,
                                                          $input_file_encoding);
}

# A wrapper around Texinfo::Utils::encoded_output_file_name() that
# can be called in converters through an objet oriented syntax.
sub encoded_output_file_name($$)
{
  my $self = shift;
  my $file_name = shift;
  return Texinfo::Convert::Utils::encoded_output_file_name($self, $file_name);
}

# This is used when the formatted text has no comment nor new line, but
# one want to add the comment or new line from the original arg
sub format_comment_or_return_end_line($$)
{
  my $self = shift;
  my $element = shift;

  my $end_line;

  my $comment = $element->{'args'}->[-1]->{'info'}->{'comment_at_end'}
    if $element->{'args'} and $element->{'args'}->[-1]->{'info'};

  if ($comment) {
    $end_line = $self->convert_tree($comment);
  } elsif ($element->{'args'} and $element->{'args'}->[-1]->{'info'}
      and $element->{'args'}->[-1]->{'info'}->{'spaces_after_argument'}) {
    my $text = $element->{'args'}->[-1]
                   ->{'info'}->{'spaces_after_argument'}->{'text'};
    if (chomp($text)) {
      $end_line = "\n";
    } else {
      $end_line = '';
    }
  } else {
    $end_line = '';
  }
  return $end_line;
}



# Specific elements formatting helper functions

sub txt_image_text($$$)
{
  my ($self, $element, $basefile) = @_;

  my ($text_file_name, $file_name_encoding)
    = $self->encoded_input_file_name($basefile.'.txt');

  my $txt_file = Texinfo::Common::locate_include_file($text_file_name,
                                  $self->get_conf('INCLUDE_DIRECTORIES'));
  if (!defined($txt_file)) {
    return undef, undef;
  } else {
    my $filehandle = do { local *FH };
    if (open($filehandle, $txt_file)) {
      my $encoding
          = Texinfo::Common::element_associated_processing_encoding($element);
      if (defined($encoding)) {
        binmode($filehandle, ":encoding($encoding)");
      }
      my $result = '';
      my $max_width = 0;
      while (<$filehandle>) {
        my $width = Texinfo::Convert::Unicode::string_width($_);
        if ($width > $max_width) {
          $max_width = $width;
        }
        $result .= $_;
      }
      if (!close ($filehandle)) {
        my $decoded_file_name = $txt_file;
        $decoded_file_name = Encode::decode($file_name_encoding, $txt_file)
          if (defined($file_name_encoding));
        $self->converter_document_warn(
           sprintf(__("error on closing image text file %s: %s"),
                                     $decoded_file_name, $!));
      }
      return $result, $max_width;
    } else {
      my $decoded_file_name = $txt_file;
      $decoded_file_name = Encode::decode($file_name_encoding, $txt_file)
        if (defined($file_name_encoding));
      $self->converter_line_warn(
               sprintf(__("\@image file `%s' unreadable: %s"),
                          $decoded_file_name, $!), $element->{'source_info'});
    }
  }
  return undef, undef;
}

sub float_type_number($$)
{
  my $self = shift;
  my $float = shift;

  my $type_element;
  if ($float->{'extra'}->{'float_type'} ne '') {
    $type_element = $float->{'args'}->[0];
  }
  my $float_number = $float->{'extra'}->{'float_number'};

  my $tree;
  if ($type_element) {
    if (defined($float_number)) {
      $tree = $self->cdt("{float_type} {float_number}",
                         {'float_type' => $type_element,
                          'float_number' => {'text' => $float_number}});
    } else {
      $tree = $self->cdt("{float_type}",
                         {'float_type' => $type_element});
    }
  } elsif (defined($float_number)) {
    $tree = $self->cdt("{float_number}",
                       {'float_number' => {'text' => $float_number}});
  }
  return $tree;
}

sub float_name_caption($$)
{
  my $self = shift;
  my $element = shift;

  my $caption_element;
  if ($element->{'extra'} and $element->{'extra'}->{'caption'}) {
    $caption_element = $element->{'extra'}->{'caption'};
  } elsif ($element->{'extra'} and $element->{'extra'}->{'shortcaption'}) {
    $caption_element = $element->{'extra'}->{'shortcaption'};
  }
  #if ($self->get_conf('DEBUG')) {
  #  my $caption_texi =
  #    Texinfo::Convert::Texinfo::convert_to_texinfo(
  #       { 'contents' => $caption_element->{'contents'}});
  #  print STDERR "  CAPTION: $caption_texi\n";
  #}

  my $substrings = {};

  my $float_number_element;
  if ($element->{'extra'}
      and defined($element->{'extra'}->{'float_number'})) {
    $float_number_element = {'text' => $element->{'extra'}->{'float_number'}};
    $substrings->{'float_number'} = $float_number_element;
  }

  my $prepended;
  if ($element->{'extra'} and defined($element->{'extra'}->{'float_type'})
      and $element->{'extra'}->{'float_type'} ne '') {
    $substrings->{'float_type'} = $element->{'args'}->[0];
    if ($caption_element) {
      if ($float_number_element) {
        # TRANSLATORS: added before caption
        $prepended = $self->cdt('{float_type} {float_number}: ', $substrings);
      } else {
        # TRANSLATORS: added before caption, no float label
        $prepended = $self->cdt('{float_type}: ', $substrings);
      }
    } else {
      if ($float_number_element) {
        $prepended = $self->cdt("{float_type} {float_number}", $substrings);
      } else {
        $prepended = $self->cdt("{float_type}", $substrings);
      }
    }
  } elsif ($float_number_element) {
    if ($caption_element) {
      # TRANSLATORS: added before caption, no float type
      $prepended = $self->cdt('{float_number}: ', $substrings);
    } else {
      $prepended = $self->cdt("{float_number}", $substrings);
    }
  }
  return ($caption_element, $prepended);
}

sub table_item_content_tree($$)
{
  my $self = shift;
  my $element = shift;

  my $table_command = $element->{'parent'}->{'parent'}->{'parent'};
  if ($element->{'args'}
      and $table_command->{'extra'}
      and $table_command->{'extra'}->{'command_as_argument'}) {
    my $command_as_argument
      = $table_command->{'extra'}->{'command_as_argument'};
    my $command_as_argument_cmdname = $command_as_argument->{'cmdname'};
    my $command = {'cmdname' => $command_as_argument_cmdname,
                   'source_info' => $element->{'source_info'},};
    if ($table_command->{'extra'}->{'command_as_argument_kbd_code'}) {
      $command->{'extra'} = {'code' => 1};
    }
    # command name for the Texinfo::Commands hashes tests
    my $builtin_cmdname;
    if ($command_as_argument->{'type'}
        and $command_as_argument->{'type'} eq 'definfoenclose_command') {
      $command->{'type'} = $command_as_argument->{'type'};
      $command->{'extra'} = {} if (!$command->{'extra'});
      $command->{'extra'}->{'begin'} = $command_as_argument->{'extra'}->{'begin'};
      $command->{'extra'}->{'end'} = $command_as_argument->{'extra'}->{'end'};
      $builtin_cmdname = 'definfoenclose_command';
    } else {
      $builtin_cmdname = $command_as_argument_cmdname;
    }
    my $arg;
    if ($Texinfo::Commands::brace_commands{$builtin_cmdname} eq 'context') {
      # This corresponds to a bogus @*table line with command line @footnote
      # or @math.  We do not really care about the formatting of the result
      # but we want to avoid debug messages, so we setup expected trees
      # for those @-commands.
      $arg = {'type' => 'brace_command_context',
              'parent' => $command,};
      if ($Texinfo::Commands::math_commands{$builtin_cmdname}) {
        $arg->{'contents'} = [$element->{'args'}->[0]];
      } else {
        my $paragraph = {'type' => 'paragraph',
                         'contents' => [$element->{'args'}->[0]],
                         'parent' => $arg};
        $arg->{'contents'} = [$paragraph];
      }
    } elsif ($Texinfo::Commands::brace_commands{$builtin_cmdname}
                                                   eq 'arguments') {
      $arg = {'type' => 'brace_arg',
              'contents' => [$element->{'args'}->[0]],
              'parent' => $command,};
    } else {
      $arg = {'type' => 'brace_container',
              'contents' => [$element->{'args'}->[0]],
              'parent' => $command,};
    }
    $command->{'args'} = [$arg];
    return $command;
  }
  return undef;
}

sub convert_accents($$$;$$)
{
  my $self = shift;
  my $accent = shift;
  my $format_accents = shift;
  my $output_encoded_characters = shift;
  my $in_upper_case = shift;

  my ($contents_element, $stack)
      = Texinfo::Convert::Utils::find_innermost_accent_contents($accent);
  my $arg_text = '';
  if (defined($contents_element)) {
    # NOTE the explanation argument is HTML specific, it may theoretically
    # be used for something else in other formats.  The type (string) should
    # be fixed to the type used in C/XS.
    $arg_text = $self->convert_tree($contents_element,
                                    "ACCENT ARG ".$accent->{'cmdname'});
  }

  if ($output_encoded_characters) {
    my $encoded = Texinfo::Convert::Unicode::encoded_accents($self,
                                       $arg_text, $stack,
                                       $self->get_conf('OUTPUT_ENCODING_NAME'),
                                       $format_accents,
                                       $in_upper_case);
    if (defined($encoded)) {
      return $encoded;
    }
  }
  my $result = $arg_text;
  foreach my $accent_command (reverse(@$stack)) {
    $result = &$format_accents ($self, $result, $accent_command,
                                $in_upper_case);
  }
  return $result;
}

# index sub-entries specified with @subentry, separated by commas, or by
# $SEPARATOR, if set
sub comma_index_subentries_tree {
  my ($self, $current_entry, $separator) = @_;

  $separator = ', ' if (!defined($separator));
  my @contents;
  while ($current_entry->{'extra'} and $current_entry->{'extra'}->{'subentry'}) {
    $current_entry = $current_entry->{'extra'}->{'subentry'};
    push @contents, {'text' => $separator}, $current_entry->{'args'}->[0];
  }
  if (scalar(@contents)) {
    return {'contents' => \@contents};
  }
  return undef;
}

sub get_converter_indices_sorted_by_letter($)
{
  my $self = shift;

  my $indices_information;
  if ($self->{'document'}) {
    $indices_information = $self->{'document'}->indices_information();

    if ($indices_information) {
      my $use_unicode_collation
        = $self->get_conf('USE_UNICODE_COLLATION');
      my $locale_lang;
      if (!(defined($use_unicode_collation) and !$use_unicode_collation)) {
        $locale_lang = $self->get_conf('COLLATION_LANGUAGE');
        if (!defined($locale_lang)
            and $self->get_conf('DOCUMENTLANGUAGE_COLLATION')) {
          $locale_lang = $self->get_conf('documentlanguage');
        }
      }

      return Texinfo::Document::sorted_indices_by_letter($self->{'document'},
                            $self, $use_unicode_collation, $locale_lang);
    }
  }
  return undef;
}

sub get_converter_indices_sorted_by_index($)
{
  my $self = shift;

  my $indices_information;
  if ($self->{'document'}) {
    $indices_information = $self->{'document'}->indices_information();

    if ($indices_information) {
      my $use_unicode_collation
        = $self->get_conf('USE_UNICODE_COLLATION');
      my $locale_lang;
      if (!(defined($use_unicode_collation) and !$use_unicode_collation)) {
        $locale_lang = $self->get_conf('COLLATION_LANGUAGE');
        if (!defined($locale_lang)
            and $self->get_conf('DOCUMENTLANGUAGE_COLLATION')) {
          $locale_lang = $self->get_conf('documentlanguage');
        }
      }

      return Texinfo::Document::sorted_indices_by_index($self->{'document'},
                            $self, $use_unicode_collation, $locale_lang);
    }
  }
  return undef;
}



# sort_element_counts code

sub _count_converted_text($$)
{
  my $converted_text = shift;
  my $count_words = shift;
  if ($count_words) {
    my @res = split /\W+/, $converted_text;
    return scalar(@res);
  } else {
    my @res = split /^/, $converted_text;
    return scalar(@res);
  }
}

# This method allows to count words in elements and returns an array
# and a text already formatted.
sub sort_element_counts($$;$$)
{
  my $converter =  shift;
  my $document = shift;
  my $use_sections = shift;
  my $count_words = shift;

  $converter->conversion_initialization($document);

  my $output_units;
  if ($use_sections) {
    $output_units = Texinfo::OutputUnits::split_by_section($document);
  } else {
    $output_units = Texinfo::OutputUnits::split_by_node($document);
  }

  my $max_count = 0;
  my @name_counts_array;

  foreach my $output_unit (@$output_units) {
    my $name;
    if ($output_unit->{'unit_command'}) {
      my $command = $output_unit->{'unit_command'};
      if ($command->{'args'}
          and $command->{'args'}->[0]->{'contents'}) {
        # convert contents to avoid outputting end of lines
        $name = "\@$command->{'cmdname'} "
          .Texinfo::Convert::Texinfo::convert_to_texinfo(
               {'contents' => $command->{'args'}->[0]->{'contents'}});
      }
    }
    $name = 'UNNAMED output unit' if (!defined($name));
    my $converted_text = $converter->convert_output_unit($output_unit);
    my $count = _count_converted_text($converted_text, $count_words);
    push @name_counts_array, [$count, $name];
    if ($count > $max_count) {
      $max_count = $count;
    }
  }
  $converter->conversion_finalization();

  my @sorted_name_counts_array = sort {$a->[0] <=> $b->[0]} @name_counts_array;
  @sorted_name_counts_array = reverse(@sorted_name_counts_array);

  my $max_length = length($max_count);
  my $result = '';
  foreach my $sorted_count (@sorted_name_counts_array) {
    $result .=  sprintf("%${max_length}d  $sorted_count->[1]\n",
                        $sorted_count->[0]);
  }
  return (\@sorted_name_counts_array, $result);
}



########################################################################
# XML related methods and variables that may be used in different
# XML Converters.

my $xml_numeric_entity_mdash = '&#'.hex('2014').';'; #8212
my $xml_numeric_entity_ndash = '&#'.hex('2013').';'; #8211
my $xml_numeric_entity_ldquo = '&#'.hex('201C').';'; #8220
my $xml_numeric_entity_rdquo = '&#'.hex('201D').';'; #8221
my $xml_numeric_entity_lsquo = '&#'.hex('2018').';'; #8216
my $xml_numeric_entity_rsquo = '&#'.hex('2019').';'; #8217

sub xml_format_text_with_numeric_entities($$)
{
  my $self = shift;
  my $text = shift;

  $text =~ s/``/$xml_numeric_entity_ldquo/g;
  $text =~ s/\'\'/$xml_numeric_entity_rdquo/g;
  $text =~ s/`/$xml_numeric_entity_lsquo/g;
  $text =~ s/\'/$xml_numeric_entity_rsquo/g;
  $text =~ s/---/$xml_numeric_entity_mdash/g;
  $text =~ s/--/$xml_numeric_entity_ndash/g;

  return $text;
}

sub xml_protect_text($$)
{
  my $self = shift;
  my $text = shift;
  if (!defined($text)) {
    cluck;
  }
  $text =~ s/&/&amp;/g;
  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;
  $text =~ s/\"/&quot;/g;
  return $text;
}

# 'today' is not set here.
our %xml_text_entity_no_arg_commands = (
               # nobrace_symbol_text
               '&'             => '&amp;',

# commands taken from %Texinfo::Common::text_brace_no_arg_commands
# are kept in comments to ease visual comparisons.
               # characters
               #'atchar'        => '@',
               'ampchar'       => '&amp;',
               #'backslashchar' => '\\',
               #'comma'         => ',',
               #'hashchar'      => '#',
               #'lbracechar'    => '{',
               #'rbracechar'    => '}',

               # symbols
               'arrow'             => '&rarr;',
               'bullet'            => '&bull;',
               'copyright'         => '&copy;',
               'dots'              => '&hellip;',
               #'enddots'           => '...',
               'equiv'             => '&equiv;',
               'euro'              => '&euro;',
               'exclamdown'        => '&iexcl;',
               'expansion'         => '&rarr;',
               'geq'               => '&ge;',
               #'LaTeX'             => 'LaTeX',
               'leq'               => '&le;',
               'minus'             => '&minus;',
               'ordf'              => '&ordf;',
               'ordm'              => '&ordm;',
               'point'             => '&lowast;',
               'pounds'            => '&pound;',
               #'print'             => '-|',
               'questiondown'      => '&iquest;',
               'registeredsymbol'  => '&reg;',
               'result'            => '&rArr;',
               #'TeX'               => 'TeX',
               'textdegree'        => '&deg;',

               # quotes
               'guillemetleft'     => '&laquo;',
               'guillemetright'    => '&raquo;',
               'guillemotleft'     => '&laquo;',
               'guillemotright'    => '&raquo;',
               'guilsinglleft'     => '&lsaquo;',
               'guilsinglright'    => '&rsaquo;',
               'quotedblbase'      => '&bdquo;',
               'quotedblleft'      => '&ldquo;',
               'quotedblright'     => '&rdquo;',
               'quoteleft'         => '&lsquo;',
               'quoteright'        => '&rsquo;',
               'quotesinglbase'    => '&sbquo;',

               # letters
               'AA'           => '&Aring;',
               'aa'           => '&aring;',
               'AE'           => '&AElig;',
               'ae'           => '&aelig;',
               'DH'           => '&ETH;',
               'dh'           => '&eth;',
               'L'            => '&#321;',
               'l'            => '&#322;',
               'OE'           => '&OElig;', # &OElig; not in html 3.2
               'oe'           => '&oelig;', # &oelig; not in html 3.2
               'O'            => '&Oslash;',
               'o'            => '&oslash;',
               'ss'           => '&szlig;',
               'TH'           => '&THORN;',
               'th'           => '&thorn;',

               # other
               'click'        => '&rarr;',
               # in general the following is not used since error
               # appears in 'translated_commands'
               'error'        => 'error--&gt;',
               'tie'          => '&nbsp;',
);

our %xml_text_entity_no_arg_commands_formatting
  = %xml_text_entity_no_arg_commands;

foreach my $brace_no_arg_command
     (keys(%Texinfo::Common::text_brace_no_arg_commands)) {
  if (!defined($xml_text_entity_no_arg_commands_formatting{
                                                $brace_no_arg_command})) {
    $xml_text_entity_no_arg_commands_formatting{$brace_no_arg_command}
      = $Texinfo::Common::text_brace_no_arg_commands{$brace_no_arg_command};
  }
}

foreach my $no_brace_command (keys(%Texinfo::Common::nobrace_symbol_text)) {
  if (!defined($xml_text_entity_no_arg_commands_formatting{
                                                $no_brace_command})) {
    $xml_text_entity_no_arg_commands_formatting{$no_brace_command}
      = $Texinfo::Common::nobrace_symbol_text{$no_brace_command};
  }
}

sub xml_comment($$)
{
  my $self = shift;
  my $text = shift;
  chomp $text;
  $text =~ s/--+/-/go;
  return '<!--' . $text . ' -->' . "\n";
}

our %xml_accent_entities = (
          '"',  'uml',
          '~',  'tilde',
          '^',  'circ',
          '`',  'grave',
          "'", 'acute',
          ",", 'cedil',
          'ringaccent', 'ring',
          'ogonek', 'ogon',
          'dotless', 'nodot',
         );

our %xml_accent_text_with_entities = (
      'ringaccent' => 'aA',
      "'"          => 'aeiouyAEIOUY',
      ','          => 'cC',
      '^'          => 'aeiouAEIOU',
      '`'          => 'aeiouAEIOU',
      '~'          => 'nNaoAO',
      '"'          => 'aeiouyAEIOU',
      'dotless'    => 'i',
# according to http://www2.lib.virginia.edu/small/vhp/download/ISO.txt
# however this doesn't seems to work in firefox
#      'ogonek'     => 'aeiuAEIU',
);

sub xml_numeric_entity_accent($$)
{
  my $accent = shift;
  my $text = shift;

  if (exists($Texinfo::Convert::Unicode::unicode_accented_letters{$accent})
      and exists($Texinfo::Convert::Unicode::unicode_accented_letters{$accent}->{$text})) {
    return '&#' .
      hex($Texinfo::Convert::Unicode::unicode_accented_letters{$accent}->{$text}). ';';
  }
  if (exists($Texinfo::Convert::Unicode::unicode_diacritics{$accent})) {
    my $diacritic = '&#'
       .hex($Texinfo::Convert::Unicode::unicode_diacritics{$accent}). ';';
    if ($accent ne 'tieaccent') {
      return $text . $diacritic;
    } else {
      # tieaccent diacritic is naturally and correctly composed
      # between two characters
      my $remaining_text = $text;
      # we consider that letters are either characters or entities
      if ($remaining_text =~ s/^([\p{L}\d]|&[a-zA-Z0-9]+;)([\p{L}\d]|&[a-zA-Z0-9]+;)(.*)$/$3/) {
        return $1.$diacritic.$2 . $remaining_text;
      } else {
        return $text . $diacritic;
      }
    }
  }
  return undef;
}

sub xml_accent($$$;$$$)
{
  my $self = shift;
  my $text = shift;
  my $command = shift;
  my $in_upper_case = shift;
  my $use_numeric_entities = shift;
  my $accent = $command->{'cmdname'};

  if ($in_upper_case and $text =~ /^\w$/) {
    $text = uc ($text);
  }

  # do not return a dotless i or j as such if it is further composed
  # with an accented letter, return the letter as is
  if ($accent eq 'dotless') {
    if ($Texinfo::Convert::Unicode::unicode_accented_letters{$accent}
        and exists($Texinfo::Convert::Unicode::unicode_accented_letters{$accent}->{$text})
        and ($command->{'parent'}
             and $command->{'parent'}->{'parent'}
             and $command->{'parent'}->{'parent'}->{'cmdname'}
             and $Texinfo::Convert::Unicode::unicode_accented_letters{$command->{'parent'}
                                        ->{'parent'}->{'cmdname'}})) {
      return $text;
    }
  }

  if ($use_numeric_entities) {
    my $formatted_accent = xml_numeric_entity_accent($accent, $text);
    if (defined($formatted_accent)) {
      return $formatted_accent;
    }
  } else {
    return "&${text}$xml_accent_entities{$accent};"
      if (defined($xml_accent_entities{$accent})
          and defined($xml_accent_text_with_entities{$accent})
          and ($text =~ /^[$xml_accent_text_with_entities{$accent}]$/));
    my $formatted_accent = xml_numeric_entity_accent($accent, $text);
    if (defined($formatted_accent)) {
      return $formatted_accent;
    }
  }

  # There are diacritics for every accent command except for dotless.
  # We should only get there with dotless if the argument is not recognized.
  return $text;
}

sub _xml_numeric_entities_accent($$$;$)
{
  my $self = shift;
  my $text = shift;
  my $command = shift;
  my $in_upper_case = shift;

  return xml_accent($self, $text, $command, $in_upper_case, 1);
}

sub xml_accents($$;$)
{
  my $self = shift;
  my $accent = shift;
  my $in_upper_case = shift;

  my $format_accents;
  if ($self->get_conf('USE_NUMERIC_ENTITY')) {
    $format_accents = \&_xml_numeric_entities_accent;
  } else {
    $format_accents = \&xml_accent;
  }

  return $self->convert_accents($accent, $format_accents,
                                $self->get_conf('OUTPUT_CHARACTERS'),
                                $in_upper_case);
}

1;

__END__

=head1 NAME

Texinfo::Convert::Converter - Parent class for Texinfo tree converters

=head1 SYNOPSIS

  package Texinfo::Convert::MyConverter;

  use Texinfo::Convert::Converter;
  @ISA = qw(Texinfo::Convert::Converter);

  sub converter_defaults ($$) {
    return \%myconverter_defaults;
  }
  sub converter_initialize($) {
    my $self = shift;
    ...
  }

  sub conversion_initialization($;$) {
    my $self = shift;
    my $document = shift;

    if ($document) {
      $self->set_document($document);
    }

    $self->{'document_context'} = [{}];
    ...
  }

  sub conversion_finalization($) {
    my $self = shift;
  }

  sub convert_tree($$) {
    ...
  }

  sub convert($$) {
    my $self = shift;
    my $document = shift;

    $self->conversion_initialization($document);

    ...
    $self->conversion_finalization();
  }

  sub output($$) {
    my $self = shift;
    my $document = shift;

    $self->conversion_initialization($document);

    ...
    $self->conversion_finalization();
    ...
  }

  # end of Texinfo::Convert::MyConverter

  my $converter = Texinfo::Convert::MyConverter->converter();
  $converter->output($texinfo_parsed_document);

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

C<Texinfo::Convert::Converter> is a super class that can be used to
simplify converters initialization.  The class also provide some
useful methods.  In turn, the converter should define some methods for
conversion.  In general C<convert_tree>, C<output> and C<convert> should be
defined.

=over

=item $result = $converter->convert_tree($tree)
X<C<convert_tree>>

The C<convert_tree> method is mandatory and should convert portions of Texinfo
tree. Takes a I<$converter> and Texinfo tree I<$tree> in arguments.  Returns
the converted output.

=item $result = $converter->output($document)

=item $result = $converter->output_tree($document)
X<C<output>>X<C<output_tree>>

The C<output> method is used by converters as entry point for conversion
to a file with headers and so on.  This method should be implemented by
converters.  C<output> is called from C<texi2any>.  C<output> takes a
I<$converter> and a Texinfo parsed document C<Texinfo::Document> I<$document>
as arguments.

C<Texinfo::Convert::Converter> implements a generic C<output_tree>
function suitable for conversion of the Texinfo tree, with the conversion
result output into a file or returned from the function. C<output_tree>
takes a I<$converter> and a Texinfo parsed document C<Texinfo::Document>
I<$document> as arguments. In a converter that uses C<output_tree>,
C<output> is in general defined as:

  sub output($$) {
    my $self = shift;
    my $document = shift;

    return $self->output_tree($document);
  }

In general, C<output> and C<output_tree> output to files and return C<undef>.
When the output file name is an empty string, however, it is customary
for C<output> and C<output_tree> to return the output as a character string
instead.  The output file name is obtained in C<output_tree> through a call to
L<<< C<determine_files_and_directory>|/($output_file, $destination_directory, $output_filename, $document_name, $input_basefile) = $converter->determine_files_and_directory($output_format) >>>.
In general C<determine_files_and_directory> is also used when C<output_tree> is not used.

=item $result = $converter->convert($document)
X<C<convert>>

Entry point for the conversion of a Texinfo parsed document to an output
format, without the headers usually done when outputting to a file.  C<convert>
takes a I<$converter> and a Texinfo parsed document C<Texinfo::Document>
I<$document> as arguments.  Returns the output as a character string.  Not
mandatory, not called from C<texi2any>, but used in the C<texi2any> test suite.

=item $result = $converter->convert_output_unit($output_unit)
X<C<convert_output_unit>>

Can be used for the conversion of output units by converters.
C<convert_output_unit> takes a I<$converter> and an output unit
I<$output_unit> as argument.  The implementation of
C<convert_output_unit> of C<Texinfo::Convert::Converter> could be suitable in
many cases.  Output units are typically returned by L<C<Texinfo::OutputUnits>
C<split_by_section>|Texinfo::OutputUnits/$output_units = split_by_section($document)>
or L<C<Texinfo::OutputUnits> C<split_by_node>|Texinfo::OutputUnits/$output_units =
split_by_node($document)>.

=back

Two methods, C<converter_defaults> and C<converter_initialize> are
used for initialization, to give information
to C<Texinfo::Convert::Converter> and can be redefined in converters.

To help with the conversion, the C<set_document> function associates a
C<Texinfo::Document> to a converter.  Other methods are called in default
implementations to be redefined to call code at specific moments of the
conversion. C<conversion_initialization>, for instance, is generally
called at the beginning of C<output>, C<output_tree> and C<convert>.
C<conversion_finalization> is generally called at the end of C<output_tree>,
C<output> and C<convert>.  C<output_tree> also calls the
C<conversion_output_begin> method before the Texinfo tree conversion to obtain
the beginning of the output. C<output_tree> calls the
C<conversion_output_end> method after the Texinfo tree conversion to obtain
the end of the output.

For output formats based on output units conversion, the
C<Texinfo::Convert::Plaintext> C<output> method could be a good starting
point.  HTML and Info output are also based on output units conversion.
Output units are not relevant for all the formats, the Texinfo tree can also be
converted directly, in general by using C<output_tree>.  This is how the other
Converters are implemented.

Existing backends based on C<output_tree> may be used as examples.
C<Texinfo::Convert::Texinfo> together with C<Texinfo::Convert::PlainTexinfo>,
as well as C<Texinfo::Convert::TextContent> are trivial examples.
C<Texinfo::Convert::Text> is less trivial, although still simple, while
C<Texinfo::Convert::DocBook> is a real converter that is also not too complex.

The documentation of L<Texinfo::Common>, L<Texinfo::OutputUnits>,
L<Texinfo::Convert::Unicode> and L<Texinfo::Convert::Text> describes modules or
additional function that may be useful for backends, while the parsed Texinfo
tree is described in L<Texinfo::Parser>.


=head1 METHODS

=head2 Converter Initialization

X<C<converter>>
X<C<Texinfo::Convert::Converter> initialization>

A module subclassing C<Texinfo::Convert::Converter> is created by calling
the C<converter> method that should be inherited from
C<Texinfo::Convert::Converter>.

=over

=item $converter = MyConverter->converter($options)

The I<$options> hash reference holds options for the converter.
These options should be Texinfo customization options.  The
customization options are described in the Texinfo manual or in the
customization API manual.

The C<converter> function returns a converter object (a blessed hash
reference) after checking the options and performing some initializations.

=back

To help with the initializations, the modules subclassing C<Texinfo::Convert::Converter>
can define two methods:

=over

=item \%defaults = $converter_or_class->converter_defaults($options)
X<C<converter_defaults>>

Returns a reference on a hash with defaults for the converter module
customization options or C<undef>.  The I<$options> hash reference holds
options for the converter.  This method is called through a converter by L<<<
C<converter>|/$converter = MyConverter->converter($options) >>>, but it may also
be called through a converter module class.

=item converter_initialize
X<C<converter_initialize>>

This method is called at the end of the C<Texinfo::Convert::Converter>
converter initialization.

=back

=head2 Conversion

For conversion with C<output> and C<convert> a document to convert should be
associated to the converter, in general the document passed in argument of
C<output> or C<convert>.  The C<set_document> function associates a
C<Texinfo::Document> to a converter.  This function is used in the default
implementations.

=over

=item $converter->set_document($document)
X<C<set_document>>

Associate I<$document> to I<$converter>.  Also set the encoding related customization
options based on I<$converter> customization information and information on
document encoding, and setup converter hash C<convert_text_options> value that
can be used to call L<C<Texinfo::Convert::Text::convert_to_text>|Texinfo::Convert::Text/$result = convert_to_text($tree, $text_options)>.

=back

The C<conversion_initialization>, C<conversion_finalization>,
C<conversion_output_begin> and C<conversion_output_end> can be redefined to
call code at diverse moments:

=over

=item $converter->conversion_initialization($document)

=item $converter->conversion_finalization()
X<C<conversion_initialization>>X<C<conversion_finalization>>

C<conversion_initialization> is called at the beginning of C<output_tree> and
of the default implementations of the C<output> and C<convert> functions.
C<conversion_finalization> is called at the end of C<output_tree> and of
the default C<output> and C<convert> methods implementations.
These functions should be redefined to have code run before a document
conversion and after the document conversion.

In the default case, C<conversion_initialization> calls
L<< set_document|/$converter->set_document($document) >> to associate the C<Texinfo::Document>
document passed in argument to the converter.  A subclass converter redefining
C<conversion_initialization> should in general call C<set_document> in the
redefined function too to associate the converted document to the converter.

=item $beginning = $converter->conversion_output_begin($output_file, $output_filename)

=item $end = $converter->conversion_output_end()
X<C<conversion_output_begin>>X<C<conversion_output_end>>

C<conversion_output_begin> returned string I<$beginning> is output
by the C<output_tree> calling method before the Texinfo tree conversion.
The I<$output_file> argument is the output file path.
If I<$output_file> is an empty string, it means that text will be returned by
the converter instead of being written to an output file.
I<$output_filename> is, in general, the file name portion of I<$output_file>
(without directory) but can also be set based on C<@setfilename>.

C<conversion_output_end> returned string I<$end> is output
by the C<output_tree> calling method after the Texinfo tree conversion.

The default methods implementations return an empty string.

=back

Calling C<conversion_initialization> and, if needed, C<conversion_finalization>
in redefined C<output> and C<convert> methods is not mandated, but it is
recommended to have similar converter codes.  In subclassed converters that do
not need to define C<conversion_initialization>, calling the default
C<Texinfo::Convert::Converter> C<conversion_initialization> implementation is
also recommended to avoid having to explictely call C<set_document>.
If C<conversion_initialization> is defined in a converter subclass it is
recommended to call C<set_document> at the very beginning of the function to
have the document associated to the converter.


=head2 Getting and setting customization variables

C<Texinfo::Convert::Converter> implements a simple interface to
set and retrieve Texinfo customization variables.  Helper
functions from diverse Texinfo modules needing customization
information expect an object implementing C<get_conf> and/or
C<set_conf>.  The converter itself can therefore be used in
such cases.

Customization variables are typically setup when
initializing a converter with L<<< C<converter>|/$converter = MyConverter->converter($options) >>>
and completed by Texinfo informative @-commands tree element values,
for commands such as C<@frenchspacing> or C<@footnotestyle>.

=over

=item $converter->force_conf($variable_name, $variable_value)
X<C<force_conf>>

Set the Texinfo customization option I<$variable_name> to I<$variable_value>.
This should rarely be used, but the purpose of this method is to be able
to revert a customization that is always wrong for a given output
format, like the splitting for example.

=item $converter->get_conf($variable_name)
X<C<get_conf>>

Returns the value of the Texinfo customization variable I<$variable_name>.

=item $status = $converter->set_conf($variable_name, $variable_value)
X<C<set_conf>>

Set the Texinfo customization option I<$variable_name> to I<$variable_value> if
not set as a converter option.  Returns false if the customization options
was not set.

=back

=head2 Registering error and warning messages

C<Texinfo::Convert::Converter> implements an interface to register error and
warning messages in the converter, that can be retrieved later on, in general
to be given to C<Texinfo::Report::add_formatted_message>.  Underneath,
C<Texinfo::Report> is used to setup the messages data structure.

=over

=item $converter->converter_document_error($text, $continuation)

=item $converter->converter_document_warn($text, $continuation)
X<C<converter_document_error>>X<C<converter_document_warn>>

Register a warning or an error.  The I<$text> is the text of the error or
warning.

The I<$continuation> optional arguments, if true, conveys that the line is a
continuation line of a message.

=item $converter->converter_line_error($text, $error_location_info, $continuation)

=item $converter->converter_line_warn($text, $error_location_info, $continuation)
X<C<converter_line_error>>X<C<converter_line_warn>>

Register a warning or an error with a line information.  The I<$text> is the
text of the error or warning.  The I<$error_location_info> argument holds the
information on the error or warning location.  The I<$error_location_info>
reference on hash may be obtained from Texinfo elements I<source_info> keys.
It may also be setup to point to a file name, using the C<file_name> key and to
a line number, using the C<line_nr> key.  The C<file_name> key value should be
a binary string.

The I<$continuation> optional arguments, if true, conveys that
the line is a continuation line of a message.

=item \@error_warning_messages = $converter->get_converter_errors()
X<C<get_converter_errors>>

Return a reference on an array containing the error or warning messages
registered in the converter.  Error and warning messages are hash references as
described in L<Texinfo::Report::errors|Texinfo::Report/($error_warnings_list,
$error_count) = errors($registrar)> and can be used in input of L<<
Texinfo::Report::add_formatted_message|Texinfo::Report/$registrar->add_formatted_message
($msg) >>.

=back

=head2 Translations in output documents

C<Texinfo::Convert::Converter> provides wrappers around
L<Texinfo::Translations> methods that sets the language to the current
C<documentlanguage>.

The C<cdt> and C<pcdt> methods are used to translate strings to be output in
converted documents, and return a Texinfo tree.  The C<cdt_string> is similar
but returns a simple string, for already converted strings.

=over

=item $tree = $converter->cdt($string, $replaced_substrings, $translation_context)

=item $string = $converter->cdt_string($string, $replaced_substrings, $translation_context)
X<C<cdt>> X<C<cdt_string>>

The I<$string> is a string to be translated.  With C<cdt>
the function returns a Texinfo tree, as the string is interpreted
as Texinfo code after translation.  With C<cdt_string> a string
is returned.

I<$replaced_substrings> is an optional hash reference specifying
some substitution to be done after the translation.  The key of the
I<$replaced_substrings> hash reference identifies what is to be substituted.
In the string to be translated word in brace matching keys of
I<$replaced_substrings> are replaced.
For C<cdt>, the value is a Texinfo tree that is substituted in the
resulting Texinfo tree. For C<cdt_string>, the value is a string that
is replaced in the resulting string.

The I<$translation_context> is optional.  If not C<undef> this is a translation
context string for I<$string>.  It is the first argument of C<pgettext>
in the C API of Gettext.

=item $tree = $object->pcdt($translation_context, $string, $replaced_substrings)
X<C<pcdt>>

Same to C<cdt> except that the I<$translation_context> is not optional.
This function is useful to mark strings with a translation context for
translation.  This function is similar to pgettext in the Gettext C API.

=back

=head2 Index sorting

You should call the following methods to sort indices in conversion:

=over

=item $sorted_indices = $converter->get_converter_indices_sorted_by_index()

=item $sorted_indices = $converter->get_converter_indices_sorted_by_letter()
X<C<get_converter_indices_sorted_by_index>>
X<C<get_converter_indices_sorted_by_letter>>

C<get_converter_indices_sorted_by_letter> returns the indices sorted by index
and letter, while C<get_converter_indices_sorted_by_index> returns the indices
with all entries of an index together.

When sorting by letter, an array reference of letter hash references is
associated with each index name.  Each letter hash reference has two
keys, a I<letter> key with the letter, and an I<entries> key with an array
reference of sorted index entries beginning with the letter.  The letter
is a character string suitable for sorting letters, but is not necessarily
the best to use for output.

When simply sorting, the array of the sorted index entries is associated
with the index name.

The functions call L<< C<Texinfo::Document::sorted_indices_by_letter>|Texinfo::Document/$sorted_indices = $document->sorted_indices_by_letter($customization_information, $use_unicode_collation, $locale_lang) >>
or L<< C<Texinfo::Document::sorted_indices_by_index>|Texinfo::Document/$sorted_indices = $document->sorted_indices_by_index($customization_information, $use_unicode_collation, $locale_lang) >>
with arguments based on C<USE_UNICODE_COLLATION>, C<COLLATION_LANGUAGE> and
C<DOCUMENTLANGUAGE_COLLATION> customization options, and, if relevant, current
C<@documentlanguage>.

=back

=head2 Conversion to XML

Some C<Texinfo::Convert::Converter> methods target conversion to XML.
Most methods take a I<$converter> as argument to get some
information and use methods for error reporting.

=over

=item $formatted_text = $converter->xml_format_text_with_numeric_entities($text)
X<C<xml_format_text_with_numeric_entities>>

Replace quotation marks and hyphens used to represent dash in
Texinfo text with numeric XML entities.

=item $protected_text = $converter->xml_protect_text($text)
X<C<xml_protect_text>>

Protect special XML characters (&, E<lt>, E<gt>, ") of I<$text>.

=item $comment = $converter->xml_comment($text)
X<C<xml_comment>>

Returns an XML comment for I<$text>.

=item $result = xml_accent($text, $accent_command, $in_upper_case, $use_numeric_entities)
X<C<xml_accent>>

I<$text> is the text appearing within an accent command.  I<$accent_command>
should be a Texinfo tree element corresponding to an accent command taking
an argument.  I<$in_upper_case> is optional, and, if set, the text is put
in upper case.  The function returns the accented letter as XML named entity
if possible, falling back to numeric entities if there is no named entity
and returns the argument as last resort.  I<$use_numeric_entities>
is optional.  If set, numerical entities are used instead of named entities
if possible.

=item $result = $converter->xml_accents($accent_command, $in_upper_case)
X<C<xml_accents>>

I<$accent_command> is an accent command, which may have other accent
commands nested.  If I<$in_upper_case> is set, the result should be
upper cased.  The function returns the accents formatted as XML.

=item $result = xml_numeric_entity_accent($accent_command_name, $text)
X<C<xml_numeric_entity_accent>>

I<$accent_command_name> is the name of an accent command.  I<$text> is the text
appearing within the accent command.  Returns the accented letter as XML numeric
entity, or C<undef> is there is no such entity.

=back

=head2 Helper methods

The module provides methods that may be useful for converter.
Most methods take a I<$converter> as argument to get some
information and use methods for error reporting, see L</Registering error and
warning messages>.  Also to translate strings, see L</Translations in output
documents>.  For useful methods that need a converter optionally and can be
used in converters that do not inherit from C<Texinfo::Convert::Converter>, see
L<Texinfo::Convert::Utils>.

=over

=item $contents_element = $converter->comma_index_subentries_tree($entry, $separator)
X<C<comma_index_subentries_tree>>

I<$entry> is a Texinfo tree index entry element. The function sets up
an array with the C<@subentry> contents.  The result is returned as
C<contents> in the I<$contents_element> element, or C<undef> if there is no
such content.  I<$separator> is an optional separator argument used, if given,
instead of the default: a comma followed by a space.

=item $result = $converter->convert_accents($accent_command, \&format_accents, $output_encoded_characters, $in_upper_case)
X<C<convert_accents>>

I<$accent_command> is an accent command, which may have other accent
commands nested.  The function returns the accents formatted either
as encoded letters if I<$output_encoded_characters> is set, or formatted
using I<\&format_accents>.  If I<$in_upper_case> is set, the result should be
uppercased.

=item $succeeded = $converter->create_destination_directory($destination_directory_path, $destination_directory_name)
X<C<create_destination_directory>>

Create destination directory I<$destination_directory_path>.
I<$destination_directory_path> should be a binary string, while
I<$destination_directory_name> should be a character string, that can be used in
error messages.  I<$succeeded> is true if the creation was successful or
uneeded, false otherwise.

=item ($output_file, $destination_directory, $output_filename, $document_name, $input_basefile) = $converter->determine_files_and_directory($output_format)
X<C<determine_files_and_directory>>

Determine output file and directory, as well as names related to files.  The
result depends on the presence of C<@setfilename>, on the Texinfo input file
name, and on customization options such as C<OUTPUT>, C<SUBDIR> or C<SPLIT>,
as described in the Texinfo manual.  If I<$output_format> is defined and not an
empty string, C<_$output_format> is prepended to the default directory name.

I<$output_file> is mainly relevant when not split and should be used as the
output file name.  In general, if not split and I<$output_file> is an empty
string, it means that text should be returned by the converter instead of being
written to an output file.  This is used in the test suite.
I<$destination_directory> is either the directory I<$output_file> is in, or if
split, the directory where the files should be created.  I<$output_filename>
is, in general, the file name portion of I<$output_file> (without directory)
but can also be set based on C<@setfilename>, in particular when
I<$output_file> is an empty string. I<$document_name> is I<$output_filename>
without extension.  I<$input_basefile> is based on the input Texinfo file name,
with the file name portion only (without directory).

The strings returned are text strings.

=item ($encoded_name, $encoding) = $converter->encoded_input_file_name($character_string_name, $input_file_encoding)

=item ($encoded_name, $encoding) = $converter->encoded_output_file_name($character_string_name)
X<C<encoded_input_file_name>> X<C<encoded_output_file_name>>

Encode I<$character_string_name> in the same way as other file names are
encoded in the converter, based on customization variables, and possibly
on the input file encoding.  Return the encoded name and the encoding
used to encode the name.  The C<encoded_input_file_name> and
C<encoded_output_file_name> functions use different customization variables to
determine the encoding.

The I<$input_file_encoding> argument is optional.  If set, it is used for
the input file encoding.  It is useful if there is more precise information
on the input file encoding where the file name appeared.

Note that C<encoded_output_file_name> is a wrapper around the
function with the same name in L<<< C<Texinfo::Convert::Utils::encoded_output_file_name>|Texinfo::Convert::Utils/($encoded_name, $encoding) = $converter->encoded_output_file_name($character_string_name) >>>,
and C<encoded_input_file_name> is a wrapper around the
function with the same name in L<<< C<Texinfo::Convert::Utils::encoded_input_file_name>|Texinfo::Convert::Utils/($encoded_name, $encoding) = $converter->encoded_input_file_name($character_string_name, $input_file_encoding) >>>.

=item ($caption, $prepended) = $converter->float_name_caption($float)
X<C<float_name_caption>>

I<$float> is a Texinfo tree C<@float> element.  This function
returns the caption element that should be used for the float formatting
and the I<$prepended> Texinfo tree combining the type and label
of the float.

=item $tree = $converter->float_type_number($float)
X<C<float_type_number>>

I<$float> is a Texinfo tree C<@float> element.  This function
returns the type and number of the float as a Texinfo tree with
translations.

=item $end_line = $converter->format_comment_or_return_end_line($element)
X<C<format_comment_or_return_end_line>>

Format comment at end of line or return the end of line associated with
the element.  In many cases, converters ignore comments and output is
better formatted with new lines added independently of the presence
of newline or comment in the initial Texinfo line, so most converters
are better off not using this method.

=item $filename = sub $converter->node_information_filename($normalized, $label_element)
X<C<node_information_filename>>

Returns the normalized file name corresponding to the I<$normalized>
node name and to the I<$label_element> node name element contents.

=item ($normalized_name, $filename) = $converter->normalized_sectioning_command_filename($element)
X<C<normalized_sectioning_command_filename>>

Returns a normalized name I<$normalized_name> corresponding to a sectioning
command tree element I<$element>, expanding the command argument using
transliteration and characters protection.  Also returns I<$filename>
the corresponding filename based on I<$normalized_name> taking into
account additional constraint on file names and adding a file extension.

=item $converter->present_bug_message($message, $element)
X<C<present_bug_message>>

Show a bug message using I<$message> text.  Use information on
I<$element> tree element if given in argument.

=item $converter->set_global_document_commands($commands_location, $selected_commands)
X<C<set_global_document_commands>>

Set the Texinfo customization options for @-commands.  I<$selected_commands>
is an array reference containing the @-commands set.  I<$commands_location>
specifies where in the document the value should be taken from. The
possibilities are:

=over

=item before

Set to the values before document conversion, from defaults and command-line.

=item last

Set to the last value for the command.

=item preamble

Set sequentially to the values in the Texinfo preamble.

=item preamble_or_first

Set to the first value of the command if the first command is not
in the Texinfo preamble, else set as with I<preamble>,
sequentially to the values in the Texinfo preamble.

=back

Notice that the only effect of this function is to set a customization
variable value, no @-command side effects are run, no associated customization
variables are set.

For more information on the function used to set the value for each of the command, see
L<C<Texinfo::Common> C<set_global_document_command>|Texinfo::Common/$element = set_global_document_command($customization_information, $global_commands_information, $cmdname, $command_location)>.

=item $table_item_tree = $converter->table_item_content_tree($element)
X<C<table_item_content_tree>>

I<$element> should be an C<@item> or C<@itemx> tree element.
Returns a tree in which the @-command in argument of C<@*table>
of the I<$element> has been applied to the I<$element> line argument,
or C<undef>.

=item $result = $converter->top_node_filename($document_name)
X<C<top_node_filename>>

Returns a file name for the Top node file using either C<TOP_FILE>
customization value, or C<EXTENSION> customization value and I<$document_name>.

=back

Finally, there is:

=over

=item $result = $converter->output_internal_links()
X<C<output_internal_links>>

At this level, the method just returns undef.  It is used in the HTML
output, following the C<--internal-links> option of C<texi2any>
specification.

=back

=head1 SEE ALSO

L<Texinfo::Common>, L<Texinfo::Convert::Unicode>, L<Texinfo::Report>,
L<Texinfo::Translations>, L<Texinfo::Convert::Utils> and L<Texinfo::Parser>.

=head1 AUTHOR

Patrice Dumas, E<lt>pertusus@free.frE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011- Free Software Foundation, Inc.  See the source file for
all copyright years.

This library is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or (at
your option) any later version.

=cut
