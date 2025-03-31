# Common.pm: Common code of other Texinfo modules.
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
# Parts (also from Patrice Dumas) come from texi2html.pl or texi2html.init.

package Texinfo::Common;

# for unicode/layer support in binmode
# for binmode documented as pushing :utf8 on top of :encoding
use 5.008001;

use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

# to determine the null file
use Config;
use File::Spec;
# for find_encoding, resolve_alias
use Encode;

# debugging
use Carp qw(cluck confess);

# uncomment to check that settable commands are contained in global commands
#use List::Compare;

use Locale::Messages;

use Texinfo::Documentlanguages;
use Texinfo::Commands;
use Texinfo::Options;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
collect_commands_in_tree
collect_commands_list_in_tree
valid_customization_option
valid_tree_transformation
);

# This is where the Texinfo modules get access to __( without explicit
# import.
our @EXPORT = qw(
__ __p
);

our $VERSION = '7.2';

# i18n
# For the messages translations.
my $messages_textdomain = 'texinfo';

sub __($) {
  my $msgid = shift;
  return Locale::Messages::dgettext($messages_textdomain, $msgid);
}

sub __p($$) {
  my $context = shift;
  my $msgid = shift;
  return Locale::Messages::dpgettext($messages_textdomain, $context, $msgid);
}


# For the in-document output strings translations in the texinfo_document
# textdomain.
#
# Return the string but do nothing else, used to mark strings to be translated
# in the Gettext framework.
# Can be used in other modules.
sub gdt($)
{
  return $_[0];
}

# First argument is the translation context.
sub pgdt($$)
{
  return $_[1];
}

# to be used when the context needs to be returned too
sub pgdt_context($$)
{
  return [$_[0], $_[1]];
}


# determine the null devices
my $default_null_device = File::Spec->devnull();
our %null_device_file = (
  $default_null_device => 1
);
# special case, djgpp recognizes both null devices
if ($Config{osname} eq 'dos' and $Config{osvers} eq 'djgpp') {
  $null_device_file{'/dev/null'} = 1;
  $null_device_file{'NUL'} = 1;
}


# Customization options

# used in main program too
our %non_decoded_customization_variables;
foreach my $variable_name ('MACRO_EXPAND', 'INTERNAL_LINKS') {
  $non_decoded_customization_variables{$variable_name} = 1;
}

# variables not specific of Parser, used in other contexts.  Spread over
# the different categories set below.  The default values are in general
# the same as elsewhere, but occasionally may be specific of the Parser.
my %common_parser_customization = (
  'INCLUDE_DIRECTORIES' => [ '.' ],
  'documentlanguage' => undef,  # not 'en' as it is better to specify that there is no
                                # need for translation since the strings are in english
                                # rather than ask for translations to en
  'EXPANDED_FORMATS' => [],
  'DEBUG' => 0,     # if >= 10, tree is printed in texi2any.pl after parsing.
                    # If >= 100 tree is printed every line.
  'FORMAT_MENU' => 'menu',           # if not 'menu' no menu error related.
  'DOC_ENCODING_FOR_INPUT_FILE_NAME' => 1, # use document encoding for input file
                                           # names encoding if set
  'COMMAND_LINE_ENCODING' => undef, # encoding of command line strings
                                    # used to decode file names for error message
  'INPUT_FILE_NAME_ENCODING' => undef, # used for input file name encoding
  'LOCALE_ENCODING' => undef, # used for file name encoding
);

# Customization variables obeyed only by the parser, and the default values.
my %parser_customization = (
  'IGNORE_SPACE_AFTER_BRACED_COMMAND_NAME' => 1,
  'CPP_LINE_DIRECTIVES' => 1, # handle cpp like synchronization lines
  'MAX_MACRO_CALL_NESTING' => 100000, # max number of nested macro calls
  'NO_INDEX' => 0, # if set, do not record index entries and ignore
                   # index related @-commands
  'NO_USER_COMMANDS' => 0, # if set, ignore @*macro, @def*index, @alias and
                           # @definfoenclose
);

# this serves both to set defaults and list customization variable
# valid for the parser.
# also used in util/txicustomvars
our %default_parser_customization_values = (%common_parser_customization,
                                            %parser_customization);

# can be modified through command-line, but not customization options
our %parser_document_state_configuration = (
  # parsed document parsing information still relevant after parsing
  'values' => {'txicommandconditionals' => 1},
                              # the key is the name, the value the @set name
                              # argument.
                              # The txicommandconditionals is a special value
                              # that is set to mark that @ifcommandnotdefined
                              # is implemented
);

# parser keys related to customization
# Set when initializing a parser, but never from command-line/init files
my %parser_inner_options = (
  'accept_internalvalue' => 0, # whether @txiinternalvalue should be added
                               # to the tree or considered invalid.
                               # currently set if called by gdt.
);

our %parser_document_parsing_options = (
                       %default_parser_customization_values,
                       %parser_document_state_configuration,
                       %parser_inner_options);

# check that settable commands are contained in global commands
# from command_data.txt
if (0) {
#if (1) {
  my @global_unique_settable = keys(%Texinfo::Options::unique_at_command_options);
  my @global_unique_commands = keys(%Texinfo::Commands::global_unique_commands);
  my $lcu = List::Compare->new(\@global_unique_settable, \@global_unique_commands);
  # only in the first list
  if (scalar($lcu->get_unique)) {
    warn 'BUG: Unique settable not global: '.join(',',$lcu->get_unique)."\n";
  }
  if (scalar($lcu->get_complement)) {
    print STDERR "REMARK: global_uniq commands not settable: "
                              .join(',', $lcu->get_complement)."\n";
  }

  my @global_multi_settable = keys(%Texinfo::Options::multiple_at_command_options);
  my @global_multi_commands = keys(%Texinfo::Commands::global_commands);
  my $lcm = List::Compare->new(\@global_multi_settable, \@global_multi_commands);
  if (scalar($lcm->get_unique)) {
    warn 'BUG: Multi settable not global: '.join(',',$lcm->get_unique)."\n";
  }
  if (scalar($lcm->get_complement)) {
    print STDERR "REMARK: global commands not settable: "
                                    .join(',', $lcm->get_complement)."\n";
  }
}

# defaults for the main program.  In general transmitted to converters as defaults
our %default_main_program_customization_options = (
 %Texinfo::Options::program_cmdline_options,
 %Texinfo::Options::program_customization_options);

# used in converters
our %document_settable_at_commands
  = (%Texinfo::Options::multiple_at_command_options,
     %Texinfo::Options::unique_at_command_options);

my %valid_customization_options;
foreach my $var (keys(%document_settable_at_commands),
         keys(%Texinfo::Options::program_cmdline_options),
         keys(%Texinfo::Options::converter_cmdline_options),
         keys(%Texinfo::Options::program_customization_options),
         keys(%parser_customization),
         keys(%Texinfo::Options::converter_customization_options),
         keys(%Texinfo::Options::converter_other_options),
         keys(%Texinfo::Options::array_cmdline_options)) {
  $valid_customization_options{$var} = 1;
}

sub valid_customization_option($)
{
  my $option = shift;
  return $valid_customization_options{$option};
}

# not documented on purpose, should not be directly called in user-defined
# codes
# FIXME not implementable in XS, would need a type, dynamically added
# customization variables...
sub add_valid_customization_option($)
{
  my $option = shift;
  if ($option =~ /^[A-Z][A-Z_]{2,}$/) {
    $valid_customization_options{$option} = 1;
    return 1;
  }
  return 0;
}


# Output formats

our %texinfo_output_formats;
foreach my $output_format_command ('info', 'plaintext',
       grep {$Texinfo::Commands::block_commands{$_} eq 'format_raw'}
            keys(%Texinfo::Commands::block_commands)) {
  $texinfo_output_formats{$output_format_command} = $output_format_command;
}


# constants.  Set by the main program.
my %build_constants;

sub set_build_constant($$)
{
  my $key = shift;
  my $value = shift;

  $build_constants{$key} = $value;
}

sub get_build_constant($)
{
  my $key = shift;

  return $build_constants{$key};
}


# Tree transformations

my %valid_tree_transformations;
foreach my $valid_transformation (
    'fill_gaps_in_sectioning', 'move_index_entries_after_items',
    'relate_index_entries_to_items',
    'insert_nodes_for_sectioning_commands',
    'complete_tree_nodes_menus',
    'complete_tree_nodes_missing_menu',
    'regenerate_master_menu',
    'indent_menu_descriptions') {
  $valid_tree_transformations{$valid_transformation} = 1;
}

sub valid_tree_transformation ($)
{
  my $transformation = shift;
  return 1 if (defined($transformation)
               and $valid_tree_transformations{$transformation});
  return 0;
}


# information on encodings

# in Texinfo up to 5.2, we presume that ISO-8859-1 was considered as
# the default encoding (although it had never been said explicitly in
# the manual, it is consistent with HTML output without encoding
# being the default for makeinfo output in earlier versions and being,
# at that time, considered as ISO-8859-1).  The wording in the Texinfo
# manual implied that setting US-ASCII had no effect, a possible
# interpretation being that it was an alias for ISO-8859-1.  Since
# ISO-8859-1 extends US-ASCII in a compatible way, this interpretation
# is valid.  Also, as long as the same 8bit encoding is used for input and
# output, the precise 8bit encoding used to extend US-ASCII has no
# practical consequence, something consistent with past makeinfo supporting
# any 8bit encoding without documentencoding and also when US-ASCII was
# specified as encoding.
#
# To support old manuals in which US-ASCII can be specified although
# the encoding corresponds to any 8bit encoding compatible with ISO-8859-1,
# we convert US-ASCII as ISO-8859-1 to avoid errors for characters in
# ISO-8859-1 but not in US-ASCII.
our %encoding_name_conversion_map;
%encoding_name_conversion_map = (
  'us-ascii' => 'iso-8859-1',
  # The mapping to utf-8 is important for perl code, as it means using a strict
  # conversion to utf-8 and not a lax conversion:
  # https://perldoc.perl.org/perlunifaq#What's-the-difference-between-UTF-8-and-utf8?
  # In more detail, we want to use utf-8 only for two different reasons
  # 1) if input is malformed it is better to error out it as soon as possible
  # 2) we do not want to have different behaviour and hard to find bugs
  #    depending on whether the user used @documentencoding utf-8
  #    or @documentencoding utf8.  There is a warning with utf8, but
  #    we want to be clear in any case.
  'utf8' => 'utf-8',
);


# information on @-commands

our %nobrace_symbol_text;
%nobrace_symbol_text = (
           '*', "\n",
           ' ', ' ',
           "\t", ' ',
           "\n", ' ',
           '-', '',  # hyphenation hint
           '|', '',  # used in formatting commands @evenfooting and friends
           '/', '',
           ':', '',
           '!', '!',
           '?', '?',
           '.', '.',
           '@', '@',
           '}', '}',
           '{', '{',
           '&', '&',
           '\\', '\\',  # should only appear in math
);

# used by Texinfo::Convert::Text, Texinfo::Convert::NodeNormalization
# and Texinfo::Convert::TextContent.
# 'today' is not set here.
our %text_brace_no_arg_commands = (
               # characters
               'atchar'        => '@',
               'ampchar'       => '&',
               'backslashchar' => '\\',
               'comma'         => ',',
               'hashchar'      => '#',
               'lbracechar'    => '{',
               'rbracechar'    => '}',

               # symbols (22)
               'arrow'              => '->',
               'bullet'             => '*',
               'copyright'          => '(C)',
               'dots'               => '...',
               'enddots'            => '...',
               'equiv'              => '==',
               'euro'               => 'Euro',
               'exclamdown'         => '!',
               'expansion'          => '==>',
               'geq'                => '>=',
               'LaTeX'              => 'LaTeX',
               'leq'                => '<=',
               'minus'              => '-',
               'ordf'               => 'a',
               'ordm'               => 'o',
               'point'              => '-!-',
               'pounds'             => '#',
               'print'              => '-|',
               'questiondown'       => '?',
               'registeredsymbol'   => '(R)',
               'result'             => '=>',
               'TeX'                => 'TeX',
               'textdegree'         => 'o',

               # quotes
               'guillemetleft'   => '<<',
               'guillemetright'  => '>>',
               'guillemotleft'   => '<<',
               'guillemotright'  => '>>',
               'guilsinglleft'   => '<',
               'guilsinglright'  => '>',
               'quotedblbase'    => ',,',
               'quotedblleft'    => '"',
               'quotedblright'   => '"',
               'quoteleft'       => '`',
               'quoteright'      => "'",
               'quotesinglbase'  => ',',

               # letters
               'AA'           => 'AA',
               'aa'           => 'aa',
               'AE'           => 'AE',
               'ae'           => 'ae',
               'DH'           => 'D',
               'dh'           => 'd',
               'L'            => '/L',
               'l'            => '/l',
               'OE'           => 'OE',
               'oe'           => 'oe',
               'O'            => '/O',
               'o'            => '/o',
               'ss'           => 'ss',
               'TH'           => 'TH', # http://www.evertype.com/standards/wynnyogh/thorn.html
               'th'           => 'th',

               # other
               'click'        => '', # specially treated
               'error'              => 'error-->',
               'tie'          => ' ',
);

our %def_map = (
    # basic commands.
    # 'arg' and 'argtype' are for everything appearing after the other
    # arguments.
    'defline',     [ 'category', 'name', 'arg' ],
    'deftypeline', [ 'category', 'type', 'name', 'argtype' ],
    'deffn',     [ 'category', 'name', 'arg' ],
    'defvr',     [ 'category', 'name' ],
    'deftypefn', [ 'category', 'type', 'name', 'argtype' ],
    'deftypeop', [ 'category', 'class' , 'type', 'name', 'argtype' ],
    'deftypevr', [ 'category', 'type', 'name' ],
    'defcv',     [ 'category', 'class' , 'name' ],
    'deftypecv', [ 'category', 'class' , 'type', 'name' ],
    'defop',     [ 'category', 'class' , 'name', 'arg' ],
    'deftp',     [ 'category', 'name', 'argtype' ],
    # shortcuts
    # The strings are marked to be translated in the parsers in type
    # 'untranslated_def_line_arg'.
    'defun',         {'deffn'     => pgdt_context(
                                         'category of functions for @defun',
                                         'Function')},
    # TRANSLATORS: category of macros for @defmac
    'defmac',        {'deffn'     => gdt('Macro')},
    # TRANSLATORS: category of special forms for @defspec
    'defspec',       {'deffn'     => gdt('Special Form')},
    'defvar',        {'defvr'     => pgdt_context(
                                         'category of variables for @defvar',
                                          'Variable')},
    # TRANSLATORS: category of user-modifiable options for @defopt
    'defopt',        {'defvr'     => gdt('User Option')},
    'deftypefun',    {'deftypefn' => pgdt_context(
                      'category of functions for @deftypefun',
                                         'Function')},
    'deftypevar',    {'deftypevr' => pgdt_context(
                     'category of variables in typed languages for @deftypevar',
                                         'Variable')},
    'defivar',       {'defcv'     => pgdt_context(
      'category of instance variables in object-oriented programming for @defivar',
                                          'Instance Variable')},
    'deftypeivar',   {'deftypecv' => pgdt_context(
      'category of instance variables with data type in object-oriented programming for @deftypeivar',
                                          'Instance Variable')},
    'defmethod',     {'defop'     => pgdt_context(
       'category of methods in object-oriented programming for @defmethod',
                                         'Method')},
    'deftypemethod', {'deftypeop' => pgdt_context(
        'category of methods with data type in object-oriented programming for @deftypemethod',
                                         'Method')},
);

# Argument not metasyntactic variables only.
our %def_no_var_arg_commands;
our %def_aliases;
foreach my $def_command(keys %def_map) {
  if (ref($def_map{$def_command}) eq 'HASH') {
    my ($real_command) = keys (%{$def_map{$def_command}});
    $def_aliases{$def_command} = $real_command;
    $def_aliases{$def_command.'x'} = $real_command.'x';
  }
  $def_no_var_arg_commands{$def_command} = 1 if ($def_command =~ /^deftype/);
}

our %small_block_associated_command;
for my $cmd ('example', 'display', 'format', 'lisp', 'quotation',
             'indentedblock') {
  $small_block_associated_command{'small'.$cmd} = $cmd;
};

# Section and heading commands hierarchical levels
our %command_structuring_level = (
              'top'               => 0,
              'part'              => 0, # out of the main hierarchy
              'chapter'           => 1,
              'majorheading'      => 1, # same as chapheading
              'unnumbered'        => 1,
              'centerchap'        => 1, # like unnumbered
              'chapheading'       => 1,
              'appendix'          => 1,
              'section'           => 2,
              'unnumberedsec'     => 2,
              'heading'           => 2,
              'appendixsec'       => 2,
              'appendixsection'   => 2, # same as appendixsec
              'subsection'        => 3,
              'unnumberedsubsec'  => 3,
              'subheading',       => 3,
              'appendixsubsec'    => 3,
              'subsubsection'     => 4,
              'unnumberedsubsubsec' => 4,
              'subsubheading'     => 4,
              'appendixsubsubsec' => 4,
         );

our %level_to_structuring_command;

{
  my $sections = [ ];
  my $appendices = [ ];
  my $unnumbered = [ ];
  my $headings = [ ];

  # set levels for synonyms
  $level_to_structuring_command{'appendixsection'} = $appendices;
  $level_to_structuring_command{'majorheading'} = $headings;
  $level_to_structuring_command{'centerchap'} = $unnumbered;

  foreach my $command (keys (%command_structuring_level)) {
    next if defined($level_to_structuring_command{$command});
    if ($command =~ /^appendix/) {
      $level_to_structuring_command{$command} = $appendices;
    } elsif ($command =~ /^unnumbered/ or $command eq 'top') {
      $level_to_structuring_command{$command} = $unnumbered;
    } elsif ($command =~ /section$/ or $command eq 'chapter') {
      $level_to_structuring_command{$command} = $sections;
    } else {
      # no mapping for part, it is outside of the main hierarchy
      next if ($command eq 'part');
      $level_to_structuring_command{$command} = $headings;
    }
    my $command_level = $command_structuring_level{$command};
    if (defined($level_to_structuring_command{$command}->[$command_level])) {
      die "$command: level_to_structuring_command already set to "
             .$level_to_structuring_command{$command}->[$command_level]."\n";
    }
    $level_to_structuring_command{$command}->[$command_level]
      = $command;
  }
}

# %all_commands includes user-settable commands only.
# The internal commands are not in %all_commands.
# used in util/txicmdlist
our %all_commands;
foreach my $command (
  keys(%Texinfo::Commands::block_commands),
  keys(%Texinfo::Commands::brace_commands),
  keys(%Texinfo::Commands::line_commands),
  keys(%Texinfo::Commands::nobrace_commands),
 ) {
  $all_commands{$command} = 1;
  foreach my $internal_command (keys(%Texinfo::Commands::internal_commands)) {
    delete $all_commands{$internal_command};
  }
}



# functions used in main program, Parser and/or Texinfo::Structuring.
# Not supposed to be called in user-defined code.

# Called in perl parser
sub rearrange_tree_beginning($$)
{
  my $document = shift;
  my $before_node_section = shift;

  # Put everything before @setfilename in a special type.  This allows to
  # ignore everything before @setfilename.
  if ($document->global_commands_information()->{'setfilename'}
      and $document->global_commands_information()->{'setfilename'}->{'parent'}
                                                 eq $before_node_section) {
    my $before_setfilename = {'type' => 'preamble_before_setfilename',
                              'parent' => $before_node_section,
                              'contents' => []};
    while (@{$before_node_section->{'contents'}}
        and (!$before_node_section->{'contents'}->[0]->{'cmdname'}
          or $before_node_section->{'contents'}->[0]->{'cmdname'} ne 'setfilename')) {
      my $content = shift @{$before_node_section->{'contents'}};
      $content->{'parent'} = $before_setfilename;
      push @{$before_setfilename->{'contents'}}, $content;
    }
    unshift (@{$before_node_section->{'contents'}}, $before_setfilename)
      if (@{$before_setfilename->{'contents'}});
    delete $before_node_section->{'contents'}
      if (scalar(@{$before_node_section->{'contents'}}) == 0);
  }

  _add_preamble_before_content($before_node_section);
}

sub _add_preamble_before_content($)
{
  my $before_node_section = shift;

  # add a preamble for informational commands
  my $informational_preamble = {'type' => 'preamble_before_content',
                                'parent' => $before_node_section,};
  my @first_types;
  if ($before_node_section->{'contents'}) {
    while (@{$before_node_section->{'contents'}}) {
      my $next_content = $before_node_section->{'contents'}->[0];
      if ($next_content->{'type'}
          and ($next_content->{'type'} eq 'preamble_before_beginning'
               or $next_content->{'type'} eq 'preamble_before_setfilename')) {
        push @first_types, shift @{$before_node_section->{'contents'}};
      } elsif (($next_content->{'type'} and $next_content->{'type'} eq 'paragraph')
               or ($next_content->{'cmdname'} and
                   not $Texinfo::Commands::preamble_commands{
                                              $next_content->{'cmdname'}})) {
        last;
      } else {
        my $content = shift @{$before_node_section->{'contents'}};
        $content->{'parent'} = $informational_preamble;
        $informational_preamble->{'contents'} = []
            if (!$informational_preamble->{'contents'});
        push @{$informational_preamble->{'contents'}}, $content;
      }
    }
  }
  push @first_types, $informational_preamble;
  unshift (@{$before_node_section->{'contents'}}, @first_types);
}

# for Parser and main program
sub warn_unknown_language($) {
  my $lang = shift;

  my @messages = ();
  my $lang_code = $lang;
  my $region_code;

  if ($lang =~ /^([a-z]+)_([A-Z]+)/) {
    $lang_code = $1;
    $region_code = $2;
  }

  if (! $Texinfo::Documentlanguages::language_codes{$lang_code}) {
    push @messages, sprintf(__("%s is not a valid language code"),
                            $lang_code);
  }
  if (defined($region_code)
       and ! $Texinfo::Documentlanguages::region_codes{$region_code}) {
    push @messages, sprintf(__("%s is not a valid region code"),
                            $region_code);
  }
  return @messages;
}

# next functions are for code used in Structuring or Indices in addition
# to Parser.  Also possibly used in Texinfo::Transformations.

sub _find_end_brace($$)
{
  my $text = shift;
  my $braces_count = shift;

  my $before = '';
  while ($braces_count > 0 and length($text)) {
    if ($text =~ s/([^()]*)([()])//) {
      $before .= $1.$2;
      my $brace = $2;
      if ($brace eq '(') {
        $braces_count++;
      } else {
        $braces_count--;
        if ($braces_count == 0) {
          return ($before, $text, 0);
        }
      }
    } else {
      $before .= $text;
      $text = '';
    }
  }
  return ($before, undef, $braces_count);
}

# This only counts opening braces, and returns 0 once all the parentheses
# are closed
sub _count_opened_tree_braces($$);
sub _count_opened_tree_braces($$)
{
  my $current = shift;
  my $braces_count = shift;
  if (defined($current->{'text'})) {
    my ($before, $after);
    ($before, $after, $braces_count) = _find_end_brace($current->{'text'},
                                                          $braces_count);
  }
  return $braces_count;
}

sub ultimate_index($$) {
  my $indices_information = shift;
  my $index = shift;
  while ($index->{'merged_in'}) {
    $index = $indices_information->{$index->{'merged_in'}};
  }
  return $index;
}

# relocate $SOURCE_MARKS source marks with position between
# $BEGIN_POSITION and $BEGIN_POSITION + $ADDED_LEN to be relative to
# $BEGIN_POSITION, and move to element $E.
# return $BEGIN_POSITION + $ADDED_LEN if there were source marks
sub relocate_source_marks($$$$)
{
  my $source_marks = shift;

  return undef if (!$source_marks);

  my $e = shift;
  my $begin_position = shift;
  my $added_len = shift;

  my $end_position = $begin_position + $added_len;

  my @indices_to_remove;
  # collect source marks to remove starting from the beginning to keep
  # the correct order in the $e element.  Order indices to remove
  # in the reverse order to start from the last in order not to change
  # the array order when the entry is splice'd away.
  for (my $i = 0; $i < scalar(@$source_marks); $i++) {
    my $source_mark = $source_marks->[$i];
    if (($begin_position == 0
         and (!defined($source_mark->{'position'})
              # this should never happen
              or $source_mark->{'position'} == 0))
        or (defined($source_mark->{'position'})
            and $source_mark->{'position'} > $begin_position
            and $source_mark->{'position'} <= $end_position)) {
      unshift @indices_to_remove, $i;
      if (defined($e->{'text'})) {
        if ($source_mark->{'position'}) {
          $source_mark->{'position'}
             = $source_mark->{'position'} - $begin_position;
        } elsif ($begin_position) {
          warn "BUG: no $source_mark->{'position'} but $begin_position\n";
        }
      } else {
        # if the source mark is to be added to a command, it can only be right
        # after the command.  The current use case is a symbol with a source
        # mark after the symbol replaced by an @-command, so we are in
        # the case of $added_length = 1 and
        # $source_mark->{'position'} == $end_position
        if ($source_mark->{'position'}
            and $source_mark->{'position'} - $begin_position > 1) {
          warn "BUG? after command $source_mark->{'position'} way past $begin_position\n";
        }
        delete $source_mark->{'position'};
      }
      $e->{'source_marks'} = [] if (! defined($e->{'source_marks'}));
      push @{$e->{'source_marks'}}, $source_mark;
    } elsif (defined($source_marks->[$i]->{'position'})
             and $source_marks->[$i]->{'position'} > $end_position) {
      # only correct if positions are always monotonically increasing
      # but should be the case for now
      last;
    }
  }
  foreach my $i (@indices_to_remove) {
    splice (@$source_marks, $i, 1);
  }
  return $end_position;
}

# retrieve a leading manual name in parentheses, if there is one.
# $LABEL_CONTENTS_CONTAINER->{'contents'} is the Texinfo for the specification
# of a node.  It is relevant in any situation when a label is expected,
# @node, menu entry, float, anchor...  For the @node command, for instance,
# $LABEL_CONTENTS_CONTAINER is typically $node->{'args'}->[0].
#
# Returned object is a hash with two fields:
#
#     manual_content - Texinfo tree for a manual name extracted from the
#                      node specification.
#     node_content - Texinfo tree for the node name on its own
#
# If $MODIFY_TREE is set and manual name is retrieved, modify the
# $LABEL_CONTENTS_CONTAINER contents such that the parentheses, the manual
# part and the node part are not in the same elements in the contents,
# and use the corresponding elements in the returned object.
#
# Could be documented, but only if there is evidence that this function
# is useful in user-defined code.
sub parse_node_manual($;$)
{
  my $label_contents_container = shift;
  my $modify_node = shift;

  return (undef, undef)
     if (!$label_contents_container->{'contents'});

  my $contents = $label_contents_container->{'contents'};

  my $idx = 0;

  my $manual;
  my $result;
  my $node_content = [];

  if ($contents->[0] and $contents->[0]->{'text'}
      and $contents->[0]->{'text'} =~ /^\(/) {
    my ($new_first, $opening_brace);
    $manual = [];
    my $braces_count = 1; # Number of ( seen minus number of ) seen.
    # the leading ( from @$contents is not in manual.
    # If the first contents element is "(" followed by more text, split
    # the leading "(" into its own element.
    my $first = $contents->[0];
    if ($first->{'text'} ne '(') {
      if ($modify_node) {
        $opening_brace = {'text' => '(', 'parent' => $label_contents_container};
      }
      my $brace_text = $first->{'text'};
      $brace_text =~ s/^\(//;
      $new_first = { 'text' => $brace_text};
    } else {
      # first element is "(", it is not part of the manual, keep it
      $idx++;
    }
    for (; $idx < scalar(@$contents); $idx++) {
      my $content;
      if ($idx == 0) {
        $content = $new_first;
      } else {
        $content = $contents->[$idx];
      }
      if (!defined($content->{'text'}) or $content->{'text'} !~ /\)/) {
        push @$manual, $content;
        $braces_count = _count_opened_tree_braces($content, $braces_count);
        # This is an error, braces were closed in a command
        if ($braces_count == 0) {
          last;
        }
      } else {
        my ($before, $after);
        ($before, $after, $braces_count) = _find_end_brace($content->{'text'},
                                                              $braces_count);
        if ($braces_count == 0) {
          my @remaining_source_marks;
          my $current_position = 0;
          # At this point, we are sure that there is a manual part,
          # so the pending removal/addition of elements at the beginning
          # of the manual can proceed (if modify_node).
          if ($modify_node) {
            if ($opening_brace) {
              # remove the original first element and prepend the
              # split "(" and text elements
              shift @$contents;
              $new_first ->{'parent'} = $label_contents_container;
              unshift @$contents, $new_first;
              unshift @$contents, $opening_brace;
              $idx++;
              if ($first->{'source_marks'}) {
                my $current_position = relocate_source_marks(
                                   $first->{'source_marks'}, $opening_brace,
                                   0, length($opening_brace->{'text'}));
                relocate_source_marks($first->{'source_marks'}, $new_first,
                              $current_position, length($new_first->{'text'}));
              }
            }
            # Remove current element $content with closing brace from the tree.
            splice(@$contents, $idx, 1);
          }

          # remove the closing ), it is not in manual_content
          $before =~ s/(\))$//;
          my $end_paren = $1;
          if ($before ne '') {
            # text before ), part of the manual name
            my $last_manual_element = { 'text' => $before };
            push @$manual, $last_manual_element;
            if ($modify_node) {
              $last_manual_element->{'parent'} = $content->{'parent'};
              splice(@$contents, $idx, 0, $last_manual_element);
              $idx++;
              $current_position = relocate_source_marks(
                         $content->{'source_marks'}, $last_manual_element,
                         $current_position, length($before));
            }
          }
          if ($modify_node) {
            my $closing_brace = {'text' => ')',
                                 'parent' => $content->{'parent'}};
            splice(@$contents, $idx, 0, $closing_brace);
            $idx++;
            $current_position = relocate_source_marks(
                         $content->{'source_marks'}, $closing_brace,
                         $current_position, length($closing_brace->{'text'}));
          }
          $after =~ s/^(\s*)//;
          my $spaces_after = $1;
          if ($spaces_after and $modify_node) {
            my $spaces_element = {'text' => $spaces_after,
                                  'parent' => $content->{'parent'}};
            splice(@$contents, $idx, 0, $spaces_element);
            $idx++;
            $current_position = relocate_source_marks(
                         $content->{'source_marks'}, $spaces_element,
                         $current_position, length($spaces_after));
          }
          if ($after ne '') {
            # text after ), part of the node name.
            my $leading_node_content = {'text' => $after};
            push @$node_content, $leading_node_content;
            if ($modify_node) {
              $leading_node_content->{'parent'} = $content->{'parent'};
              splice(@$contents, $idx, 0, $leading_node_content);
              $current_position = relocate_source_marks(
                           $content->{'source_marks'}, $leading_node_content,
                           $current_position, length($after));
            }
            $idx++;
          }
          last;
        } else {
          push @$manual, $content;
        }
      }
    }
    if ($braces_count != 0) {
      # unclosed brace, reset
      $manual = undef;
      $idx = 0;
    } else {
      $result = {};
      $result->{'manual_content'} = {'contents' => $manual};
    }
  }

  if ($idx < scalar(@$contents)) {
    push(@$node_content, @$contents[$idx .. scalar(@$contents)-1]);
  }

  if (scalar(@$node_content)) {
    $result = {} if (!$result);
    $result->{'node_content'} = {'contents' => $node_content};
  }

  return $result;
}



# misc functions used in diverse contexts and useful in converters

# Used in main program, tests and HTML Converter.
# TODO document?
#
# $INPUT_FILE_PATH: file name to locate.  Binary string.  If it is a file
#                   path, it is not searched for in directories.
# $DIRECTORIES: a reference on a array containing a list of directories to
#               search the file in. Binary strings.
# $ALL_FILES:   if true collect all the files with that name, otherwise stop
#               at first match.
# $DEPRECATED_DIRS:  optional argument.  If set, associates deprecated directory
#                    names with the directory name that should be used
#
# Return an array reference with the files found, only one if $ALL_FILES
# is false, and an array reference with the deprecated directories used.
sub locate_file_in_dirs($$$;$)
{
  my $input_file_path = shift;
  my $directories = shift;
  my $all_files = shift;
  my $deprecated_dirs = shift;

  my $deprecated_dirs_used;

  if (File::Spec->file_name_is_absolute($input_file_path)) {
    return ([$input_file_path], undef)
       if (-e $input_file_path and -r $input_file_path);
  } else {
    my ($volume, $path_directories, $file)
       = File::Spec->splitpath($input_file_path);
    my @path_directories = File::Spec->splitdir($path_directories);
    if (scalar(@path_directories) > 0) {
      # do not search in directories if the file name already contains
      # directories.
      return ([$input_file_path], undef)
         if (-e $input_file_path and -r $input_file_path);
    } else {
      my @files;
      foreach my $dir (@$directories) {
        next unless (-d $dir);
        my $possible_file = "$dir/$input_file_path";
        if (-e $possible_file and -r $possible_file) {
          if ($deprecated_dirs and $deprecated_dirs->{$dir}) {
            $deprecated_dirs_used = [] if (!defined($deprecated_dirs_used));
            push @$deprecated_dirs_used, $dir;
          }
          if ($all_files) {
            push (@files, $possible_file);
          } else {
            return [$possible_file], $deprecated_dirs_used;
          }
        }
      }
      return (\@files, $deprecated_dirs_used)
        if ($all_files and scalar(@files));
    }
  }
  return undef, undef;
}

sub perl_encoding_name($)
{
  my $encoding = shift;

  my $perl_encoding;

  if (defined($encoding) and $encoding ne '') {
    $encoding = $encoding_name_conversion_map{$encoding}
      if (defined($encoding_name_conversion_map{$encoding}));
    my $Encode_encoding_object = Encode::find_encoding($encoding);
    if (defined($Encode_encoding_object)) {
      $perl_encoding = $Encode_encoding_object->name();
      $perl_encoding = undef if (defined($perl_encoding)
                                 and $perl_encoding eq '');
    }
  }

  return $perl_encoding;
}

sub element_associated_processing_encoding($)
{
  my $element = shift;

  my $encoding = $element->{'extra'}->{'input_encoding_name'}
    if ($element->{'extra'});

  return perl_encoding_name($encoding);
}

# Reverse the decoding of the file name from the input encoding.  When
# dealing with file names, we want Perl strings representing sequences of
# bytes, not Unicode codepoints.
#     This is necessary even if the name of the included file is purely
# ASCII, as the name of the directory it is located within may contain
# non-ASCII characters.
#   Otherwise, the -e operator and similar may not work correctly.
sub encode_file_name($$)
{
  my $file_name = shift;
  my $input_encoding = shift;

  my $encoding;

  return ($file_name, $encoding)
    if (not defined($input_encoding));

  if ($input_encoding eq 'utf-8' or $input_encoding eq 'utf-8-strict') {
    $encoding = 'utf-8';
  } else {
    $encoding = $input_encoding;
  }
  my $encoded_file_name = Encode::encode($encoding, $file_name);
  return ($encoded_file_name, $encoding);
}

sub locate_include_file($;$)
{
  my $input_file_path = shift;
  my $include_directories = shift;

  my $ignore_include_directories = 0;

  # If the path is absolute or begins with . or .., do not search in
  # include directories.  This is consistent with Kpathsea for Texinfo TeX.
  if (File::Spec->file_name_is_absolute($input_file_path)) {
    $ignore_include_directories = 1;
  } else {
    my ($volume, $directories, $filename)
      = File::Spec->splitpath($input_file_path);
    my @directories = File::Spec->splitdir($directories);

    foreach my $dir (@directories) {
      if ($dir eq File::Spec->updir() or $dir eq File::Spec->curdir()) {
        $ignore_include_directories = 1;
        last;
      } elsif ($dir ne '') {
        last;
      }
    }
  }

  if ($ignore_include_directories) {
    if (-e $input_file_path and -r $input_file_path) {
      return $input_file_path;
    }
  } else {
    if (!$include_directories) {
      # no directory list and not an absolute path, never succeed
      return undef;
    }
    foreach my $include_dir (@$include_directories) {
      my $possible_file = "$include_dir/$input_file_path";
      if (-e $possible_file and -r $possible_file) {
        return $possible_file;
      }
    }
  }
  return undef;
}

# TODO document?
sub informative_command_value($)
{
  my $element = shift;

  my $cmdname = $element->{'cmdname'};

  if ($Texinfo::Commands::line_commands{$cmdname} eq 'lineraw') {
    if (not $Texinfo::Commands::commands_args_number{$cmdname}) {
      return 1;
    } elsif ($element->{'args'}) {
      return join(' ', map {$_->{'text'}} @{$element->{'args'}});
    }
  } elsif ($element->{'extra'}
           and exists($element->{'extra'}->{'text_arg'})) {
    return $element->{'extra'}->{'text_arg'};
  } elsif ($element->{'extra'} and $element->{'extra'}->{'misc_args'}
           and exists($element->{'extra'}->{'misc_args'}->[0])) {
    return $element->{'extra'}->{'misc_args'}->[0];
  } elsif ($Texinfo::Commands::line_commands{$cmdname} eq 'line'
           and $element->{'args'} and scalar(@{$element->{'args'}})
           and $element->{'args'}->[0]
           and $element->{'args'}->[0]->{'contents'}
           and scalar(@{$element->{'args'}->[0]->{'contents'}})
           and exists($element->{'args'}->[0]->{'contents'}->[0]->{'text'})) {
    return $element->{'args'}->[0]->{'contents'}->[0]->{'text'};
  }
  return undef;
}

# REMARK documentencoding handling is not reverted by resetting a value with
# set_conf, as the encodings are set using other sources of information
# (possibly based on @documentencoding) in converter.
sub set_informative_command_value($$)
{
  my $self = shift;
  my $element = shift;

  my $cmdname = $element->{'cmdname'};
  $cmdname = 'shortcontents' if ($cmdname eq 'summarycontents');

  my $value = informative_command_value($element);

  if (defined($value)) {
    my $set = $self->set_conf($cmdname, $value);
    return $set;
  }
  return 0;
}

sub _in_preamble($)
{
  my $element = shift;
  my $current_element = $element;
  while ($current_element->{'parent'}) {
    if (defined($current_element->{'parent'}->{'type'})
        and $current_element->{'parent'}->{'type'} eq 'preamble_before_content') {
      return 1;
    }
    $current_element = $current_element->{'parent'};
  }
  return 0;
}

# $COMMAND_LOCATION is 'last', 'preamble' or 'preamble_or_first'
# 'preamble' means setting sequentially to the values in the preamble.
# 'preamble_or_first'  means setting to the first value for the command
# in the document if the first command is not in the preamble, else set
# sequentially to the values in the preamble.
# 'last' means setting to the last value for the command in the document.
#
# For unique command, the last may be considered to be the same as the first.
sub get_global_document_command($$$)
{
  my $global_commands_information = shift;
  my $global_command = shift;
  my $command_location = shift;

  if ($command_location ne 'last' and $command_location ne 'preamble_or_first'
      and $command_location ne 'preamble') {
    warn "BUG: get_global_document_command: unknown command_location: $command_location";
  }

  my $element;
  if ($global_commands_information
      and $global_commands_information->{$global_command}) {
    if (ref($global_commands_information->{$global_command}) eq 'ARRAY') {
      if ($command_location eq 'last') {
        $element = $global_commands_information->{$global_command}->[-1];
      } else {
        if ($command_location eq 'preamble_or_first'
            and not _in_preamble($global_commands_information->{$global_command}->[0])) {
          $element =
            $global_commands_information->{$global_command}->[0];
        } else {
          foreach my $command_element (@{$global_commands_information->{$global_command}}) {
            if (_in_preamble($command_element)) {
              $element = $command_element;
            } else {
              last;
            }
          }
        }
      }
    } else {
      # unique command, first, preamble and last are the same
      $element = $global_commands_information->{$global_command};
    }
  }
  return $element;
}

# Notice that the only effect is to use set_conf (directly or through
# set_informative_command_value), no @-commands setting side effects are done
# and associated customization variables are not set/reset either.
sub set_global_document_command($$$$)
{
  my $self = shift;
  my $global_commands_information = shift;
  my $global_command = shift;
  my $command_location = shift;

  my $element = get_global_document_command($global_commands_information,
                                            $global_command, $command_location);

  if ($element) {
    set_informative_command_value($self, $element);
  }
  return $element;
}

sub lookup_index_entry($$)
{
  my $index_entry_info = shift;
  my $indices_information = shift;

  if (!defined($index_entry_info)) {
    cluck ("BUG: lookup_index_entry: index_entry_info undef\n");
  }
  my ($entry_index_name, $entry_number) = @{$index_entry_info};

  my $index_info;

  if ($indices_information->{$entry_index_name}) {
    $index_info = $indices_information->{$entry_index_name};
    if ($index_info->{'index_entries'}
        and $index_info->{'index_entries'}->[$entry_number-1]) {
      return ($index_info->{'index_entries'}->[$entry_number-1], $index_info);
    }
  }
  return (undef, $index_info);
}

# only used from Perl
# Remove first $ELEMENT from $ARRAY
sub remove_from_array($$)
{
  my $array = shift;
  my $element = shift;

  #if (!defined($array)) {
  #  cluck();
  #}

  for (my $index = 0; $index < scalar(@$array); $index++) {
    if ($array->[$index] eq $element) {
      return splice(@$array, $index, 1);
    }
  }
  return undef;
}

sub set_output_encoding($$)
{
  my $customization_information = shift;
  my $document = shift;

  my $document_information;
  if ($document) {
    $document_information = $document->global_information();
  }
  $customization_information->set_conf('OUTPUT_ENCODING_NAME',
               $document_information->{'input_encoding_name'})
     if ($document_information
         and $document_information->{'input_encoding_name'});
}

sub set_output_perl_encoding($)
{
  my $customization_information = shift;

  if (not defined($customization_information->get_conf('OUTPUT_PERL_ENCODING'))
      and defined($customization_information->get_conf('OUTPUT_ENCODING_NAME'))) {
    my $conversion_encoding
       = $customization_information->get_conf('OUTPUT_ENCODING_NAME');
    if (defined($encoding_name_conversion_map{$conversion_encoding})) {
      $conversion_encoding
         = $encoding_name_conversion_map{$conversion_encoding};
    }
    my $perl_encoding = Encode::resolve_alias($conversion_encoding);
    if (defined($perl_encoding) and $perl_encoding ne '') {
      $customization_information->set_conf('OUTPUT_PERL_ENCODING',
                                           $perl_encoding);
    }
  }
}

my $min_level = $command_structuring_level{'chapter'};
my $max_level = $command_structuring_level{'subsubsection'};

# Return numbered level of an element, as modified by raise/lowersections
sub section_level($)
{
  my $section = shift;
  my $level = $command_structuring_level{$section->{'cmdname'}};
  # correct level according to raise/lowersections
  if ($section->{'extra'} and $section->{'extra'}->{'level_modifier'}) {
    $level -= $section->{'extra'}->{'level_modifier'};
    if ($level < $min_level) {
      if ($command_structuring_level{$section->{'cmdname'}} < $min_level) {
        $level = $command_structuring_level{$section->{'cmdname'}};
      } else {
        $level = $min_level;
      }
    } elsif ($level > $max_level) {
      $level = $max_level;
    }
  }
  return $level;
}

# decompose a decimal number on a given base.  It is not the
# decomposition used for counting as we start at 0, not 1 for all
# the factors.  This is in order to get aa and not ba in calling
# code.
sub _decompose_integer($$)
{
  my $number = shift;
  my $base = shift;
  my @result = ();

  while ($number >= 0) {
    my $factor = $number % $base;
    push (@result, $factor);
    $number = int(($number - $factor) / $base) - 1;
  }
  return @result;
}

sub enumerate_item_representation($$)
{
  my $specification = shift;
  my $number = shift;

  if ($specification =~ /^[0-9]+$/) {
    return $specification + $number -1;
  }

  my $result = '';
  my $base_letter = ord('a');
  $base_letter = ord('A') if (ucfirst($specification) eq $specification);
  my @letter_ords = _decompose_integer(ord($specification) - $base_letter + $number - 1, 26);
  foreach my $ord (@letter_ords) {
    $result = chr($base_letter + $ord) . $result;
  }
  return $result;
}

sub is_content_empty($;$);
sub is_content_empty($;$)
{
  my $tree = shift;
  my $do_not_ignore_index_entries = shift;
  if (!defined($tree) or !exists($tree->{'contents'})) {
    return 1;
  }
  foreach my $content (@{$tree->{'contents'}}) {
    if (defined($content->{'text'})) {
      if ($content->{'text'} =~ /\S/) {
        return 0;
      } else {
        next;
      }
    }
    if ($content->{'cmdname'}) {
      if ($content->{'type'} and $content->{'type'} eq 'index_entry_command') {
        if ($do_not_ignore_index_entries) {
          return 0;
        } else {
          next;
        }
      }
      if (exists($Texinfo::Commands::line_commands{$content->{'cmdname'}})) {
        if ($Texinfo::Commands::formatted_line_commands{$content->{'cmdname'}}
            or $Texinfo::Commands::formattable_line_commands{$content->{'cmdname'}}) {
          return 0;
        } else {
          next;
        }
      } elsif (exists($Texinfo::Commands::nobrace_commands{$content->{'cmdname'}})) {
        if ($Texinfo::Commands::formatted_nobrace_commands{$content->{'cmdname'}}) {
          return 0;
        } else {
          next;
        }
      } elsif ($Texinfo::Commands::non_formatted_brace_commands{$content->{'cmdname'}}
               or $Texinfo::Commands::non_formatted_block_commands{$content->{'cmdname'}}) {
        next;
      } else {
        return 0;
      }
    }
    if ($content->{'type'}) {
      if ($content->{'type'} eq 'paragraph') {
        return 0;
      }
    }
    if (not is_content_empty($content, $do_not_ignore_index_entries)) {
      return 0;
    }
  }
  return 1;
}

# if in this container, we are 'inline', within a running text
my @inline_types = ('def_line', 'paragraph', 'preformatted',
  'line_arg', 'block_line_arg', 'menu_entry_name', 'menu_entry_node');

my %inline_types;
foreach my $type (@inline_types) {
  $inline_types{$type} = 1;
}

my %not_inline_commands;
foreach my $command (
     keys(%Texinfo::Commands::root_commands),
     keys(%Texinfo::Commands::block_commands),
     grep {$Texinfo::Commands::brace_commands{$_} eq 'context'}
           keys(%Texinfo::Commands::brace_commands)) {
  $not_inline_commands{$command} = 1;
}

# Return 1 if inline in a running text, 0 if right in top-level or block
# environment, and undef otherwise.
sub _inline_or_block($)
{
  my $current = shift;
  if ($current->{'type'} and $inline_types{$current->{'type'}}) {
    return 1;
  } elsif ($current->{'cmdname'}
           and exists($not_inline_commands{$current->{'cmdname'}})) {
    return 0;
  }
  return undef;
}

# return true if in running text context.
# If $CHECK_CURRENT is set, check the element itself, too, in
# addition to the parent context.
sub element_is_inline($;$)
{
  my $current = shift;
  my $check_current = shift;

  if ($check_current) {
    my $inline_or_block = _inline_or_block($current);
    return ($inline_or_block) if (defined($inline_or_block));
  }

  while ($current->{'parent'}) {
    $current = $current->{'parent'};
    my $inline_or_block = _inline_or_block($current);
    return ($inline_or_block) if (defined($inline_or_block));
  }
  return 0;
}

sub normalize_top_node_name($)
{
  my $node_name = shift;
  if ($node_name =~ /^top$/i) {
    return 'Top';
  }
  return $node_name;
}

# Used in count_bytes
my $Encode_encoding_object;
my $last_encoding;

# Only used in the unmaintained IXIN converter, but could be useful in
# other converters, so it is better to keep it to get an idea of the type of
# code that needs the output perl encoding information.
sub count_bytes($$;$)
{
  my $self = shift;
  my $string = shift;
  my $encoding = shift;

  if (!defined($encoding) and $self and $self->get_conf('OUTPUT_PERL_ENCODING')) {
    $encoding = $self->get_conf('OUTPUT_PERL_ENCODING');
  }

  if ($encoding and $encoding ne 'ascii') {
    if (!defined($last_encoding) or $last_encoding ne $encoding) {
      # Look up and save encoding object for next time.  This is
      # slightly faster than calling Encode::encode.
      $last_encoding = $encoding;
      $Encode_encoding_object = Encode::find_encoding($encoding);
      if (!defined($Encode_encoding_object)) {
        Carp::croak "Unknown encoding '$encoding'";
      }
    }
    return length($Encode_encoding_object->encode($string));
  } else {
    return length($string);
  }
}

# if $PREFER_REFERENCE_ELEMENT is set, prefer an untranslated element.
sub index_content_element($;$)
{
  my $element = shift;
  my $prefer_reference_element = shift;
  if ($element->{'extra'} and $element->{'extra'}->{'def_command'}) {
    if ($prefer_reference_element
        and $element->{'extra'}->{'def_index_ref_element'}) {
      return $element->{'extra'}->{'def_index_ref_element'};
    } else {
      return $element->{'extra'}->{'def_index_element'};
    }
  } else {
    return $element->{'args'}->[0];
  }
}

# custom heading command line is split at @|
sub split_custom_heading_command_contents($)
{
  my $element = shift;

  my $result = undef;

  my $nr_split_contents = 0;

  my $contents_nr = scalar(@{$element->{'contents'}});

  if (!$contents_nr) {
    return $result;
  }

  $result = {'contents' => []};
  my $heading_element = {'contents' => []};
  push @{$result->{'contents'}}, $heading_element;

  for (my $i = 0; $i < $contents_nr; $i++) {
    my $current_content = $element->{'contents'}->[$i];
    #print STDERR "$nr_split_contents : "
    #          .debug_print_element($current_content)."\n";
    if (defined($current_content->{'cmdname'})
        and $current_content->{'cmdname'} eq '|') {
      if ($nr_split_contents < 2) {
        $heading_element = {'contents' => []};
        push @{$result->{'contents'}}, $heading_element;
        $nr_split_contents++;
      }
    } else {
      push @{$heading_element->{'contents'}}, $current_content;
    }
  }

  return $result;
}

# TODO document?
# currently untested/unused, but there is a similar function in XS that
# is used.
sub replace_element_in_contents($$$)
{
  my $parent = shift;
  my $removed = shift;
  my $added = shift;

  return 0 if (!defined($parent) or !$parent->{'contents'});

  my $nr_contents = scalar(@{$parent->{'contents'}});
  for (my $i = 0; $i < $nr_contents; $i++) {
    my $content = $parent->{'contents'}->[$i];
    if ($content eq $removed) {
      $parent->{'contents'}->[$i] = $added;
      return 1;
    }
  }
  return 0;
}

# not currently used
sub find_parent_root_command($$);
sub find_parent_root_command($$)
{
  my $self = shift;
  my $current = shift;

  my $root_command;
  while (1) {
    if ($current->{'cmdname'}) {
      if ($Texinfo::Commands::root_commands{$current->{'cmdname'}}) {
        return $current;
      } elsif ($Texinfo::Commands::block_commands{$current->{'cmdname'}}
               and $Texinfo::Commands::block_commands{$current->{'cmdname'}} eq 'region') {
        if ($current->{'cmdname'} eq 'copying' and $self and $self->{'document'}) {
          my $global_commands = $self->{'document'}->global_commands_information();
          if ($global_commands and $global_commands->{'insertcopying'}) {
            foreach my $insertcopying(@{$global_commands->{'insertcopying'}}) {
              my $root_command
                = find_parent_root_command($self, $insertcopying);
              return $root_command if (defined($root_command));
            }
          }
        } else {
          return undef;
        }
      }
    }
    if ($current->{'parent'}) {
      $current = $current->{'parent'};
    } else {
      return undef;
    }
  }
  # Should never get there
  return undef;
}

# In the default case, global informative commands are collected
# by the parsers.  The following functions allow to collect
# any @-command.
# Used in customization init files code and should be useful in
# particular in user-defined init files.

sub collect_commands_in_tree($$)
{
  my $root = shift;
  my $commands_list = shift;

  my $commands_hash = {};
  foreach my $command_name (@$commands_list) {
    $commands_hash->{$command_name} = [];
  }
  _collect_commands_in_tree($root, $commands_hash);
  return $commands_hash;
}

sub _collect_commands_in_tree($$);
sub _collect_commands_in_tree($$)
{
  my $current = shift;
  my $commands_hash = shift;

  if (defined($current->{'cmdname'})
      and defined($commands_hash->{$current->{'cmdname'}})) {
    push @{$commands_hash->{$current->{'cmdname'}}}, $current;
  }
  foreach my $key ('args', 'contents') {
    if ($current->{$key}) {
      foreach my $child (@{$current->{$key}}) {
        _collect_commands_in_tree($child, $commands_hash);
      }
    }
  }
}

sub collect_commands_list_in_tree($$)
{
  my $root = shift;
  my $commands_list = shift;

  my $collected_commands_list = [];
  my $commands_hash = {};
  foreach my $command_name (@$commands_list) {
    $commands_hash->{$command_name} = 1;
  }
  _collect_commands_list_in_tree($root, $commands_hash, $collected_commands_list);
  return $collected_commands_list;
}

sub _collect_commands_list_in_tree($$$);
sub _collect_commands_list_in_tree($$$)
{
  my $current = shift;
  my $commands_hash = shift;
  my $collected_commands_list = shift;

  if (defined($current->{'cmdname'})
      and defined($commands_hash->{$current->{'cmdname'}})) {
    push @{$collected_commands_list}, $current;
  }
  foreach my $key ('args', 'contents') {
    if ($current->{$key}) {
      foreach my $child (@{$current->{$key}}) {
        _collect_commands_list_in_tree($child, $commands_hash,
                                       $collected_commands_list);
      }
    }
  }
}


# Common to different module, but not meant to be used in user-defined
# codes.

sub get_label_element($)
{
  my $current = shift;
  return undef if (!defined($current->{'cmdname'}));
  if (($current->{'cmdname'} eq 'node' or $current->{'cmdname'} eq 'anchor')
      and $current->{'args'} and scalar(@{$current->{'args'}})) {
    return $current->{'args'}->[0];
  } elsif ($current->{'cmdname'} eq 'float'
      and $current->{'args'} and scalar(@{$current->{'args'}}) >= 2) {
    return $current->{'args'}->[1];
  }
  return undef;
}

# For code that can be called both from the main
# context, with a registrar and customization information, and from
# a converter
# NOTE it is considered internal and should not be called in user-defined
# code.  If this changes, should be documented.
sub converter_or_registrar_line_warn($$$$)
{
  my $registrar = shift;
  my $customization_information = shift;
  my $text = shift;
  my $error_location_info = shift;

  if (defined($registrar)) {
    my $debug;
    if ($customization_information) {
      $debug = $customization_information->get_conf('DEBUG');
    }
    $registrar->line_warn($text, $error_location_info, 0, $debug);
  } else {
    $customization_information->converter_line_warn($text,
                                                    $error_location_info);
  }
}

# functions used for debugging.  May be used in other modules.
# Not documented.

sub _parent_string($)
{
  my $current = shift;
  my $parent_string;
  if ($current->{'parent'}) {
    my $parent = $current->{'parent'};
    my $parent_cmd = '';
    my $parent_type = '';
    $parent_cmd = "\@$parent->{'cmdname'}" if (defined($parent->{'cmdname'}));
    $parent_type = "($parent->{'type'})" if (defined($parent->{'type'}));
    $parent_string = " <- $parent_cmd$parent_type";
  }
  return $parent_string
}

sub debug_command_name($)
{
  my $cmdname = shift;
  if ($cmdname eq "\n") {
    return '\n';
  } elsif ($cmdname eq "\t") {
    return '\t';
  } else {
    return $cmdname;
  }
}

# informations on a tree element, short version
sub debug_print_element($;$)
{
  my $current = shift;
  my $print_parent = shift;

  if (!defined($current)) {
    return "debug_print_element: UNDEF";
  }
  if (ref($current) ne 'HASH') {
    return "debug_print_element: $current not a hash";
  }
  my $type = '';
  my $cmd = '';
  my $text = '';
  my $args = '';
  my $contents = '';
  $type = "($current->{'type'})" if (defined($current->{'type'}));
  if (defined($current->{'text'})) {
    if ($current->{'text'} eq '') {
      $text = "[T]";
    } else {
      my $text_str = $current->{'text'};
      $text_str =~ s/\n/\\n/g;
      $text = "[T: $text_str]";
    }
  } else {
    if (defined($current->{'cmdname'})) {
      $cmd = '@' . debug_command_name($current->{'cmdname'});
    }
    $args = "[A".scalar(@{$current->{'args'}}).']' if $current->{'args'};
    $contents = "[C".scalar(@{$current->{'contents'}}).']'
       if $current->{'contents'};
  }
  my $parent_string = '';
  if ($print_parent) {
    $parent_string = _parent_string($current);
    $parent_string = '' if (!defined($parent_string));
  }
  return "$cmd$type$text$args$contents$parent_string";
}

# for debugging
sub debug_print_element_details($;$)
{
  my $current = shift;
  my $print_parent = shift;

  my $string = debug_print_element($current, $print_parent);
  foreach my $key (keys (%$current)) {
    $string .= "   $key: $current->{$key}\n";
  }
  if ($current->{'extra'}) {
    $string .= " EXTRA\n";
    foreach my $key (keys (%{$current->{'extra'}})) {
      $string .= "  $key: $current->{'extra'}->{$key}\n";
    }
  }
  if ($current->{'info'}) {
    $string .= " INFO\n";
    foreach my $key (keys (%{$current->{'info'}})) {
      $string .= "  $key: $current->{'info'}->{$key}\n";
    }
  }
  return $string;
}

sub debug_print_output_unit
{
  my $current = shift;

  if (!defined($current)) {
    return "debug_print_output_unit: UNDEF\n";
  }
  if (ref($current) ne 'HASH') {
    return "debug_print_output_unit: $current not a hash\n";
  }
  my $type = $current->{'unit_type'};
  # Should never happen
  $type = 'UNDEF' if (!defined($type));
  my $unit_cmd = '';
  if ($current->{'unit_command'}) {
    $unit_cmd = debug_print_element($current->{'unit_command'}, 0)
    .Texinfo::Convert::Texinfo::root_heading_command_to_texinfo(
                                       $current->{'unit_command'});
  }
  my $fname = '';
  if (defined($current->{'unit_filename'})) {
    $fname = "{F:$current->{'unit_filename'}}";
  }
  my $variety = '';
  if (defined($current->{'special_unit_variety'})) {
    $variety = "{V:$current->{'special_unit_variety'}}";
  }
  my $contents = '';
  $contents = "{C".scalar(@{$current->{'unit_contents'}}).'}'
    if $current->{'unit_contents'};
  return "{$type}$fname$variety$contents$unit_cmd";
}

# format list for debugging messages
sub debug_list
{
  my $label = shift;
  my (@list) = (ref $_[0] && $_[0] =~ /.*ARRAY.*/) ? @{$_[0]} : @_;

  my $str = "$label: [";
  my @items = ();
  for my $item (@list) {
    $item = "" if ! defined ($item);
    $item =~ s/\n/\\n/g;
    push (@items, $item);
  }
  $str .= join (" ", @items);
  $str .= "]";

  warn "$str\n";
}

# format hash for debugging messages
sub debug_hash
{
  my ($label) = shift;
  my (%hash) = (ref $_[0] && $_[0] =~ /.*HASH.*/) ? %{$_[0]} : @_;

  my $str = "$label: {";
  my @items = ();
  for my $key (sort keys %hash) {
    my $val = $hash{$key} || ""; # no undef
    $key =~ s/\n/\\n/g;
    $val =~ s/\n/\\n/g;
    push (@items, "$key:$val");
  }
  $str .= join (",", @items);
  $str .= "}";

  warn "$str\n";
}

# for debugging
use Data::Dumper;

my @kept_keys = ('contents', 'cmdname', 'type', 'text', 'args',
  'extra', 'info', 'spaces_before_argument',
  'spaces_after_argument', 'comment_at_end', 'index_entry'
);
my %kept_keys;
foreach my $key (@kept_keys) {
  $kept_keys{$key} = 1;
}
my @kept_keys_output_unit = ('unit_contents');
foreach my $key (@kept_keys_output_unit) {
  $kept_keys{$key} = 1;
}
my @kept_keys_handle = ('tree_document_descriptor');
foreach my $key (@kept_keys_handle) {
  $kept_keys{$key} = 1;
}
sub _filter_print_keys { [grep {$kept_keys{$_}} ( sort keys %{$_[0]} )] };
sub debug_print_tree($)
{
  my $tree = shift;
  local $Data::Dumper::Sortkeys = \&_filter_print_keys;
  local $Data::Dumper::Purity = 1;
  local $Data::Dumper::Indent = 1;

  return Data::Dumper->Dump([$tree]);
}


1;

__END__

=head1 NAME

Texinfo::Common - Texinfo modules common data and miscellaneous methods

=head1 SYNOPSIS

  use Texinfo::Common;


  my @commands_to_collect = ('math');
  my $collected_commands
    = Texinfo::Common::collect_commands_in_tree($document_root,
                                             \@commands_to_collect);

  my $package_version
    = Texinfo::Common::get_build_constant('PACKAGE_AND_VERSION');

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

Texinfo::Common holds hashes with miscellaneous information and some
hashes with information on Texinfo @-commands, as well as miscellaneous
methods.

=head1 MISC INFORMATION

Hashes are defined as C<our> variables, and are therefore available
outside of the module.

Values defined for a Texinfo build independently of any document or
output format are available by calling C<get_build_constant>:

=over

=item $value = get_build_constant($name)

The following build constants are available:

=over

=item PACKAGE

=item PACKAGE_CONFIG

=item PACKAGE_AND_VERSION

=item PACKAGE_AND_VERSION_CONFIG

=item PACKAGE_NAME

=item PACKAGE_NAME_CONFIG

=item PACKAGE_VERSION

=item PACKAGE_VERSION_CONFIG

=item PACKAGE_URL

=item PACKAGE_URL_CONFIG

Texinfo package name and versions.  Values of build constants without
C<_CONFIG> appended are set by configure.  For each variable set by
configure there is another one with C<_CONFIG> appended
to the name set to the same value, to match the name of the macros set in
C.  So, for example C<PACKAGE_VERSION_CONFIG> value is the same as
C<PACKAGE_VERSION>, set to the C<PACKAGE_VERSION> value set by configure.

=back

=back

=over

=item %texinfo_output_formats
X<C<%texinfo_output_formats>>

Cannonical output formats that have associated conditionals.  In
practice corresponds to C<format_raw> C<%block_commands> plus C<info>
and C<plaintext>.

=back

TODO: undocumented
%null_device_file %default_parser_customization_values %multiple_at_command_options %unique_at_command_options %converter_cmdline_options %default_main_program_customization_options %converter_customization_options %document_settable_at_commands %def_map %command_structuring_level %level_to_structuring_command %encoding_name_conversion_map %text_brace_no_arg_commands

=head1 @-COMMAND INFORMATION

Hashes are defined as C<our> variables, and are therefore available
outside of the module.

The key of the hashes are @-command names without the @.  The
following hashes are available:

=over

=item %all_commands
X<C<%all_commands>>

All the @-commands.

=item %def_aliases

=item %def_no_var_arg_commands
X<C<%def_aliases>>
X<C<%def_no_var_arg_commands>>

C<%def_aliases> associates an aliased command to the original command, for
example C<defun> is associated to C<deffn>.

C<%def_no_var_arg_commands> associates a definition command name with
a true value if the I<argument> on the definition command line can contain
non-metasyntactic variables.  For instance, it is true for C<deftypevr>
but false for C<defun>, since C<@defun> I<argument> is supposed to contain
metasyntactic variables only.

=item %nobrace_symbol_text
X<C<%nobrace_symbol_text>>

Values are ASCII representation of single character non-alphabetical commands
without brace such as C<*> or C<:>.  The value may be an empty string.

=item %small_block_associated_command
X<C<%small_block_associated_command>>

Associate small command like C<smallexample> to the regular command
C<example>.

=back

=head1 METHODS

Two methods are exported in the default case for Texinfo modules messages
translation in the Uniforum gettext framework, C<__> and C<__p>.

The Texinfo tree and Texinfo tree elements used in argument of some functions
are documented in L<Texinfo::Parser/TEXINFO TREE>.  When customization
information is needed, an object that defines C<set_conf> and/or C<get_conf> is
expected, for example a converter inheriting from
C<Texinfo::Convert::Converter>, see L<Texinfo::Convert::Converter/Getting and
setting customization variables>.

=over

=item $translated_string = __($msgid)

=item $translated_string = __p($msgctxt, $msgid)

Returns the I<$msgid> string translated in the Texinfo messages text domain.
C<__p> can be used instead of C<__> to pass a I<$msgctxt> context string to
provide translators with information on the string context when the string is
short or if the translation could depend on the context. C<__> corresponds to
the C<gettext> function and C<__p> to the C<pgettext> function.

It is not advised to use those functions in user-defined code.  It is not
practical either, as the translatable strings marked by C<__> or C<__p> need to
be collected and added to the Texinfo messages domain.  This facility could
only be used in user-defined code with translatable strings already present in
the domain anyway.  In fact, these functions are documented mainly because they
are automatically exported.

See L<Locale::Messages>,
L<C<gettext> C interface|https://www.gnu.org/software/gettext/manual/html_node/gettext.html>,
L<Perl in GNU Gettext|https://www.gnu.org/software/gettext/manual/html_node/Perl.html>.
For translation of strings in output, see L<Texinfo::Translations>.

=item collect_commands_in_tree($tree, $commands_list)
X<C<collect_commands_in_tree>>

Returns a hash reference with keys @-commands names specified
in the I<$commands_list> array reference and values arrays of
tree elements corresponding to those @-command found in I<$tree>
by traversing the tree.

=item collect_commands_list_in_tree($tree, $commands_list)
X<C<collect_commands_list_in_tree>>

Return a list reference containing the tree elements corresponding
to the @-commands names specified in the I<$commands_list> found
in I<$tree> by traversing the tree.  The order of the @-commands
should be kept.

=item $encoding_name = element_associated_processing_encoding($element)
X<C<element_associated_processing_encoding>>

Returns the encoding name that can be used for decoding derived
from the encoding that was set where I<$element> appeared.

=item $result = element_is_inline($element, $check_current)
X<C<element_is_inline>>

Return true if the element passed in argument is in running text
context.  If the optional I<$check_current> argument is set,
check the element itself, in addition to the parent context.

=item ($encoded_file_name, $encoding) = encode_file_name($file_name, $input_encoding)

Encode the I<$file_name> text string to a binary string I<$encoded_file_name>
based on I<$input_encoding>.  Also returns the I<$encoding> name actually
used which may have undergone some normalization.  This function is mostly
a wrapper around L<Encode::encode|Encode/encode> which avoids calling the module if not
needed.  Do nothing if I<$input_encoding> is C<undef>.

=item $text = enumerate_item_representation($specification, $number)
X<C<enumerate_item_representation>>

This function returns the number or letter correponding to item
number I<$number> for an C<@enumerate> specification I<$specification>,
appearing on an C<@enumerate> line.  For example

  enumerate_item_representation('c', 3)

is C<e>.

=item $command = find_parent_root_command($object, $tree_element)
X<C<find_parent_root_command>>

Find the parent root command (sectioning command or node) of a tree element.
The I<$object> argument is optional, its C<global_commands> field is used
to continue through C<@insertcopying> if in a C<@copying>.

=item $entry_content_element = index_content_element($element, $prefer_reference_element)

Return a Texinfo tree element corresponding to the content of the index
entry associated to I<$element>.  If I<$prefer_reference_element> is set,
prefer an untranslated element.  If the element is an index command like
C<@cindex> or an C<@ftable> C<@item>, the content element is the argument
of the command.  If the element is a definition line, the index entry
element is based on the name and class.

=item $result = is_content_empty($tree, $do_not_ignore_index_entries)
X<C<is_content_empty>>

Return true if the I<$tree> has content that could be formatted.
I<$do_not_ignore_index_entries> is optional.  If set, index entries
are considered to be formatted.

=item $file = locate_include_file($customization_information, $file_path)
X<C<locate_include_file>>

Locate I<$file_path>.  If I<$file_path> is an absolute path or has C<.>
or C<..> in the path directories it is checked that the path exists and is a
file.  Otherwise, the file name in I<$file_path> is located in include
directories also used to find texinfo files included in Texinfo documents.
I<$file_path> should be a binary string.  C<undef> is returned if the file was
not found, otherwise the file found is returned as a binary string.

=item ($index_entry, $index_info) = lookup_index_entry($index_entry_info, $indices_information)

Returns an I<$index_entry> hash based on the I<$index_entry_info> and
I<$indices_information>.  Also returns the I<$index_info> hash with information on
the index associated to the index entry.  I<$index_entry_info> should be
an array reference with an index name as first element and the index entry number
in that index (1-based) as second element.  In general, the I<$index_entry_info>
is an L<C<extra> I<index_entry>|Texinfo::Parser/index_entry> associated to an element.

The I<$index_entry> hash is described in L<Texinfo::Document/index_entries>.  The
I<$index_info> hash is described in L<< C<Texinfo::Document::indices_information>|Texinfo::Document/$indices_information = $document->indices_information() >>.

=item $normalized_name = normalize_top_node_name($node_string)
X<C<normalize_top_node_name>>

Normalize the node name string given in argument, by normalizing
Top node case.

=item $result = remove_from_array($array, $element)

Remove first occurence of I<$element> in the array reference I<$array>.
Return the removed element, or C<undef> if not found.

=item $level = section_level($section)
X<C<section_level>>

Return numbered level of the tree sectioning element I<$section>, as modified by
raise/lowersections.

=item $element = set_global_document_command($customization_information, $global_commands_information, $cmdname, $command_location)
X<C<set_global_document_command>>

Set the Texinfo customization variable corresponding to I<$cmdname> in
I<$customization_information>.  The I<$global_commands_information> should
contain information about global commands in a Texinfo document, typically obtained
from a parsed document L<< $document->global_commands_information()|Texinfo::Document/$commands = global_commands_information($document) >>.
I<$command_location> specifies where in the document the value should be taken from,
for commands that may appear more than once. The possibilities are:

=over

=item last

Set to the last value for the command.

=item preamble

Set sequentially to the values in the Texinfo preamble.

=item preamble_or_first

Set to the first value of the command if the first command is not
in the Texinfo preamble, else set as with I<preamble>,
sequentially to the values in the Texinfo preamble.

=back

The I<$element> returned is the last element that was used to set the
customization value, or C<undef> if no customization value was found.

Notice that the only effect of this function is to set a customization
variable value, no @-command side effects are run, no associated customization
variables are set.

=item $status = set_informative_command_value($customization_information, $element)
X<C<set_informative_command_value>>

Set the Texinfo customization option corresponding to the tree element
I<$element>.  The command associated to the tree element should be
a command that sets some information, such as C<@documentlanguage>,
C<@contents> or C<@footnotestyle> for example.  Return true if the command
argument was found and the customization variable was set.

=item set_output_encoding($customization_information, $document)
X<C<set_output_encoding>>

If not already set, set C<OUTPUT_ENCODING_NAME> based on input file
encoding.

=item set_output_perl_encoding($customization_information)
X<C<set_output_perl_encoding>>

Set C<OUTPUT_PERL_ENCODING> based on C<OUTPUT_ENCODING_NAME>.  In general,
C<OUTPUT_PERL_ENCODING> should not be set directly by user-defined code such
that it corresponds to C<OUTPUT_ENCODING_NAME>.

=item $split_contents = split_custom_heading_command_contents($element)
X<C<split_custom_heading_command_contents>>

Split the I<$element> contents at C<@|> in at max three parts.
Return an element containing the split parts in contents, or C<undef> if
the I<$element> has no useful content.  The input I<$element>
is supposed to be C<< $element->{'args'}->[0] >>
of C<%Texinfo::Commands::heading_spec_commands> commands such as C<@everyheading>.

=item $status = valid_customization_option($name)
X<C<valid_option>>

Return true if the I<$name> is a known customization option.

=item $status = valid_tree_transformation($name)
X<C<valid_tree_transformation>>

Return true if the I<$name> is a known tree transformation name
that may be passed with C<TREE_TRANSFORMATIONS> to modify a texinfo
tree.

=back

=head1 SEE ALSO

L<Texinfo::Parser>, L<Texinfo::Convert::Converter> and L<Texinfo::Report>.

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
