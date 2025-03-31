# ParserNonXS.pm: parse texinfo code into a tree.
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

# Since there are different parser implementation, XS and NonXS, it is
# better to have the Texinfo::Parser packages define only the parser
# API functions.  Constants, functions useful in both parsers, and other
# functions useful in other codes are better defined in other Texinfo
# modules.

# The organization of the file is the following:
#  default parser state.  With explanation of the internal structures.
#  determination of command types.
#  user visible subroutines and subroutines related to input.
#  internal subroutines, doing the parsing.

# In general, the Parser works with character strings decoded from the
# command line, from input files or from the parsed document.  There are
# exceptions for the following files and directory names that are binary
# strings:
# * the input file name passed through parse_texi_file is a binary string
# * @include file name and CPP line directive file names are encoded
#   into binary strings.
# Those binary strings are in 'file_name' keys, they transit through
# $self->{'input'} and end up in 'source_info' in tree elements and
# in error messages.
#
# The following parser information is directly determined from the
# input file name as binary strings
# ->{'global_info'}->{'input_file_name'}
# ->{'global_info'}->{'input_directory'}

package Texinfo::Parser;

# We need the unicode stuff.
use 5.006;
use strict;

# stop \s from matching non-ASCII spaces, etc.  \p{...} can still be
# used to match Unicode character classes.
use if $] >= 5.014, re => '/a';

# check that autovivification do not happen incorrectly.
#no autovivification qw(fetch delete exists store strict);

# debug
use Carp qw(cluck confess);
#use Data::Dumper;

# to detect if an encoding may be used to open the files
# to encode/decode in-memory strings used as files
use Encode qw(find_encoding decode encode);

# for fileparse
use File::Basename;

# Clone could be faster for small structures, which should be the case
# here, but Clone is not in Perl core modules, so we use Storable::dclone.
use Storable qw(dclone); # standard in 5.007003

# commands definitions
use Texinfo::Commands;
use Texinfo::Common;

# Error reporting and counting
use Texinfo::Report;

# fpr tree copy
use Texinfo::ManipulateTree;

# To register the parsed manual and associated information
# and also to call set_labels_identifiers_target.
use Texinfo::Document;

# in error messages, and for macro body expansion
use Texinfo::Convert::Texinfo;

# to normalize names
use Texinfo::Convert::NodeNameNormalization;

# to complete indices translations.
use Texinfo::Translations;

require Exporter;

our $module_loaded = 0;
sub import {
  if (!$module_loaded) {
    Texinfo::XSLoader::override ("Texinfo::Parser::_parse_texi_regex",
      "Texinfo::MiscXS::parse_texi_regex");
    Texinfo::XSLoader::override ("Texinfo::Parser::_parse_command_name",
      "Texinfo::MiscXS::parse_command_name");
    $module_loaded = 1;
  }
  # The usual import method
  goto &Exporter::import;
}

our $VERSION = '7.2';


# Document information set in the parser.  The initialization is done by
# Texinfo::Document::new_document and afterwards the Texinfo::Document
# document is available in the 'document' key in the parser and
# document hash keys are directly accessed in the parser for efficiency
  #'commands_info' => {},     # keys are @-commands names (without @) and
                              # values are arrays for global multiple
                              # @-commands and a value for non multiple
                              # global @-commands.
  #'listoffloats_list' => {}, # key is the normalized float type, value is
                              # an array reference holding all the floats
                              # of that type.
  #'identifiers_target' => {}, # keys are normalized label names, as described
                              # in the `HTML Xref' node.  Value should be
                              # a node/anchor or float in the tree.
  #'internal_references' => [], # list of elements source of cross-references,
                               # commands like @ref without books or external
                               # manual files, and menu entries without
                               # external manual.
  #'labels_list' => [],        # array of elements associated with labels.
                              # information on document
  #'global_info' => {'input_encoding_name' => 'utf-8',
  #                  'included_files' => [],},
# indices             a structure holding the link between index
#                     names and merged indices;
#                     initial value is %index_names in Texinfo::Commands.


# these are the default values for the parsing state of a document.
# Some could become configurable if moved to Texinfo::Common
# %parser_document_state_configuration,
# but they are not configurable/implemented in the XS parser, so they are
# best left internal.  Could be relevant to reuse for diverse sources
# of input associated to the same document.
my %parser_document_state_initialization = (
  # parsed document parsing information still relevant after parsing
  'aliases' => {},            # key is a command name value is the alias
  'macros' => {},             # the key is the user-defined macro name.  The
                              # value is the reference on a macro element
                              # as obtained by parsing the @macro
  'definfoenclose' => {},     # key is the command name, value is an array
                              # reference with 2 values, beginning and ending.

  # parsing information still relevant at the end of the parsing
  'clickstyle' => 'arrow',        #
  'kbdinputstyle' => 'distinct',  #
  'source_mark_counters' => {},   #
  'current_node'    => undef,     # last seen node.
  'current_section' => undef,     # last seen section.
  'current_part'    => undef,     # last seen part.
  'internal_space_holder' => undef,
   # the element associated with the last internal spaces element added.
   # We know that there can only be one at a time as a non space
   # character should always lead to abort_empty_line or another
   # function being called and the internal space element being
   # removed or put in the internal_space_holder info.

   # NOTE internal_space_holder is already unset in abort_empty_line
   # if the internal space element is put in the internal_space_holder.
   # It would be cleaner to unset internal_space_holder in all the
   # cases where the internal space element is removed too, such that
   # when internal_space_holder is set the previous value is undef and not
   # the previous internal_space_holder, which is now irrelevant as
   # its associated space has disappeared.

  'sections_level_modifier' => 0, # modified by raise/lowersections

  'input_file_encoding' => 'utf-8', # encoding name used for the input file
);

my %parsing_state_initialization = (
  # parsing information only relevant during an input source parsing
  'input' => [],       # a stack, with last at bottom.  Holds the opened files
                       # or text.  Pending macro expansion or text expansion
                       # is also in that structure.
  'conditional_stack' => [],  # a stack of conditional commands that are
                              # expanded.
  'macro_block_stack' => [],  # a stack of *macro block commands that are nested.
  'macro_expansion_nr' => 0,  # number of macros being expanded
  'value_expansion_nr' => 0,  # number of values being expanded
  'nesting_context'    => {
                         # key is the context name, value is the
                         # depth of the context.
                           'basic_inline_stack' => [],
                           'basic_inline_stack_on_line' => [],
                           'basic_inline_stack_block' => [],
                           'regions_stack' => [],
                           'footnote' => 0,
                           'caption' => 0,
                          },
  'context_stack'      => [],
                         # stack of the contexts, more recent on top.
                         # 'ct_line' is added when on a line or
                         # block @-command line,
                         # 'ct_def' is added instead if on a definition line.
                         # 'ct_preformatted' is added in block commands
                         # where there is no paragraphs and spaces are kept
                         # (format, example, display and menu commands...)
                         # 'ct_math' is added in math block commands
                         # (displaymath) and @math brace commands
                         # 'ct_rawpreformatted' is added in raw block commands
                         # (html, xml, docbook...)
                         # 'ct_inlineraw' is added when in inlineraw
                         # 'ct_base' is (re-)added when in footnote,
                         # caption, or shortcaption (context brace_commands
                         # that does not already start another context, ie not
                         # math).
                         # 'ct_paragraph' is added in paragraph.
  'context_command_stack' => [],
                         # the stack of @-commands. An @-command name can
                         # be added each time a context is pushed on
                         # 'context_stack'.  Could be undef if there
                         # is no @-command associated with the context.
);

my %parser_state_initialization = (%parser_document_state_initialization,
                                   %parsing_state_initialization);

# other possible keys for the parser state initialized based
# on customization variables:
# parsing information still relevant at the end of the parsing
# line_commands           the same as %line_commands, but with index entry
#                         commands dynamically added.
# brace_commands          the same as %brace_commands, but with definfoenclose
#                         commands dynamically added.
# valid_nestings          direct command valid nesting information, with
#                         index entry commands dynamically added.
# no_paragraph_commands   the same as %no_paragraph_commands,
#                         with new index entry commands dynamically added.
# basic_inline_commands   the same as %contain_basic_inline_commands below, but
#                         with new index entry commands dynamically added
# command_index           associate a command name with an index name.
# index_entry_commands    index entry commands, including added index commands.

# parser keys related to customization
# expanded_formats_hash   each key comes from EXPANDED_FORMATS, value is 1
# set                     points to the value set when initializing, for
#                         configuration items that are not to be overriden
#                         by @-commands.  For example documentlanguage.
# conf                    Customization and document state configuration
#                         based on defaults and parser argument.

# other keys for the parser state initialized at parser creation
# registrar          # Texinfo::Report object used for error
#                    # reporting.

# A source information is an hash reference with the keys:
# line_nr        the line number.
# file_name      the file name, a binary string.
# macro          if in a macro expansion, the name of the macro.

# The input structure is an array, the first is the most recently included
# file.  The last element may correspond to a file if the parsing is done
# on a file, with parse_texi_file, or hold pending text, if called on text.
# each element of the array is a hash reference.
#
# The keys are:
# for both text and file:
#  source_info         source information corresponding to the current file.
#  input_source_mark   source mark associated with the input (include file,
#                      macro or value expansion).
#
# for text:
#  th                  handle for text given in input or expansion text
#                      of value or macro.
#  value_flag          set if the text corresponds to a @value command
#                      expansion.
#  macro_name          set if the text corresponds to a new macro expansion.
#
# for a file:
#  fh                  filehandle for the file.
#  input_file_path     file path.

# The commands in initialization_overrides are not set in the document if
# set at the parser initialization.
my %initialization_overrides = (
  'documentlanguage' => 1,
);

my %nobrace_commands          = %Texinfo::Commands::nobrace_commands;
my %line_commands             = %Texinfo::Commands::line_commands;
my %brace_commands            = %Texinfo::Commands::brace_commands;
my %commands_args_number      = %Texinfo::Commands::commands_args_number;
my %accent_commands           = %Texinfo::Commands::accent_commands;
my %contain_plain_text_commands = %Texinfo::Commands::contain_plain_text_commands;
my %contain_basic_inline_commands = %Texinfo::Commands::contain_basic_inline_commands;
my %block_commands            = %Texinfo::Commands::block_commands;
my %blockitem_commands        = %Texinfo::Commands::blockitem_commands;
my %close_paragraph_commands  = %Texinfo::Commands::close_paragraph_commands;
my %def_commands              = %Texinfo::Commands::def_commands;
my %def_alias_commands        = %Texinfo::Commands::def_alias_commands;
my %preformatted_commands     = %Texinfo::Commands::preformatted_commands;
my %math_commands             = %Texinfo::Commands::math_commands;
my %deprecated_commands       = %Texinfo::Commands::deprecated_commands;
my %root_commands             = %Texinfo::Commands::root_commands;
my %sectioning_heading_commands     = %Texinfo::Commands::sectioning_heading_commands;
my %ref_commands              = %Texinfo::Commands::ref_commands;
my %heading_spec_commands     = %Texinfo::Commands::heading_spec_commands;
my %in_heading_spec_commands  = %Texinfo::Commands::in_heading_spec_commands;
my %variadic_commands         = %Texinfo::Commands::variadic_commands;
my %default_index_commands    = %Texinfo::Commands::default_index_commands;
my %global_multiple_commands  = %Texinfo::Commands::global_commands;
my %global_unique_commands    = %Texinfo::Commands::global_unique_commands;
my %in_index_commands         = %Texinfo::Commands::in_index_commands;
my %explained_commands        = %Texinfo::Commands::explained_commands;
my %inline_format_commands    = %Texinfo::Commands::inline_format_commands;
my %index_entry_command_commands    = %Texinfo::Commands::index_entry_command_commands;

my %def_map                   = %Texinfo::Common::def_map;
my %def_aliases               = %Texinfo::Common::def_aliases;
my %all_commands              = %Texinfo::Common::all_commands;

my %encoding_name_conversion_map
                              = %Texinfo::Common::encoding_name_conversion_map;

# Keys are commmands, values are names of indices.  User-defined
# index commands are added dynamically.
my %command_index;

$command_index{'vtable'} = 'vr';
$command_index{'ftable'} = 'fn';

foreach my $index_command (keys(%default_index_commands)) {
  $command_index{$index_command} = $default_index_commands{$index_command};
}

# the type of index, fn: function, vr: variable, tp: type
my %index_type_def = (
 'fn' => ['deffn', 'deftypefn', 'deftypeop', 'defop'],
 'vr' => ['defvr', 'deftypevr', 'defcv', 'deftypecv' ],
 'tp' => ['deftp']
);

foreach my $index_type (keys %index_type_def) {
  foreach my $def (@{$index_type_def{$index_type}}) {
    $command_index{$def} = $index_type;
  }
}

foreach my $def_command(keys %def_map) {
  if (ref($def_map{$def_command}) eq 'HASH') {
    my ($real_command) = keys (%{$def_map{$def_command}});
    $command_index{$def_command} = $command_index{$real_command};
  }
  $command_index{$def_command.'x'} = $command_index{$def_command};
}


# equivalence between a @set flag and an @@-command
my %set_flag_command_equivalent = (
  'txicodequoteundirected' => 'codequoteundirected',
  'txicodequotebacktick'   => 'codequotebacktick',
#  'txideftypefnnl'         => 'deftypefnnewline',
);

# could be moved to Texinfo::Common if needed more generally
# same order as in XS parser
my @set_flag_index_char_ignore = (
   ['txiindexbackslashignore', '\\'],
   ['txiindexhyphenignore', '-'],
   ['txiindexlessthanignore', '<'],
   ['txiindexatsignignore', '@'],
);

# after checking that the context is in begin_paragraph_contexts, the list
# of types in which paragraphs are not started.
my %type_without_paragraph;
foreach my $type ('brace_arg', 'brace_container') {
  $type_without_paragraph{$type} = 1;
};

# To keep in sync with XS main/element_types.txt leading_space flag
my %leading_space_types;
foreach my $type ('empty_line', 'ignorable_spaces_after_command',
        'internal_spaces_after_command', 'internal_spaces_before_argument',
        'internal_spaces_before_context_argument',
        'spaces_after_close_brace') {
  $leading_space_types{$type} = 1;
}

my %command_ignore_space_after;
foreach my $command ('anchor', 'hyphenation', 'caption', 'shortcaption',
                     'sortas', 'seeentry', 'seealso') {
  $command_ignore_space_after{$command} = 1;
}

# @-commands that should be at the beginning of a line
my %begin_line_commands;

foreach my $command ('node', 'end') {
  $begin_line_commands{$command} = $command;
}

foreach my $begin_line_command (keys(%line_commands)) {
  $begin_line_commands{$begin_line_command} = 1;
}

foreach my $not_begin_line_command ('comment', 'c', 'columnfractions',
                                    'item', 'subentry') {
  delete $begin_line_commands{$not_begin_line_command};
}

# default indices
my %index_names = %Texinfo::Commands::index_names;

# @-commands that do not start a paragraph
my %no_paragraph_commands = %Texinfo::Commands::no_paragraph_commands;

# does not include index commands
my %close_preformatted_commands = %close_paragraph_commands;
my %close_paragraph_not_preformatted = ('sp' => 1);
foreach my $no_close_preformatted(keys(%close_paragraph_not_preformatted)) {
  delete $close_preformatted_commands{$no_close_preformatted};
}

foreach my $block_command (keys(%block_commands)) {
  $begin_line_commands{$block_command} = 1;
}

# commands that may appear in commands containing plain text only
my %in_plain_text_commands = %accent_commands;
foreach my $brace_command(keys(%brace_commands)) {
  $in_plain_text_commands{$brace_command} = 1
     if ($brace_commands{$brace_command} eq 'noarg');
}
my %symbol_nobrace_commands;
foreach my $no_brace_command (keys(%nobrace_commands)) {
  if ($nobrace_commands{$no_brace_command} eq 'symbol'
      and !$in_heading_spec_commands{$no_brace_command}) {
    $symbol_nobrace_commands{$no_brace_command} = 1;
    $in_plain_text_commands{$no_brace_command} = 1;
  }
}
$in_plain_text_commands{'c'} = 1;
$in_plain_text_commands{'comment'} = 1;

# commands that may appear in any text argument, similar constraints
# as in paragraphs.
my %in_full_text_commands;
# start from all the brace commands
foreach my $command (keys(%brace_commands), keys(%symbol_nobrace_commands)) {
  $in_full_text_commands{$command} = 1;
}
# selected line and nobrace commands
foreach my $in_full_text_command ('c', 'comment', 'refill', 'subentry',
                         'columnfractions', 'set', 'clear', 'end') {
  $in_full_text_commands{$in_full_text_command} = 1;
}
# selected block commands
foreach my $block_command (keys(%block_commands)) {
  $in_full_text_commands{$block_command} = 1
    if ($block_commands{$block_command} eq 'conditional'
        or $block_commands{$block_command} eq 'format_raw');
}

# sort out brace commmands and setup command list appearing in more
# restricted context.

# those two commands are not allowed in any command except for @float */
delete $in_full_text_commands{'caption'};
delete $in_full_text_commands{'shortcaption'};

# commands that accept full text, but no block or top-level commands
my %contain_full_text_commands;
foreach my $brace_command (keys (%brace_commands)) {
  next if (exists($contain_plain_text_commands{$brace_command}));
  if ($brace_commands{$brace_command} eq 'style_code'
      or $brace_commands{$brace_command} eq 'style_other'
      or $brace_commands{$brace_command} eq 'style_no_code') {
    $contain_full_text_commands{$brace_command} = 1;
  }
}
foreach my $line_command ('center', 'exdent', 'item', 'itemx',
                          'nodedescription') {
  $contain_full_text_commands{$line_command} = 1;
}

# Fill the valid nestings hash.  The keys are the containing commands and
# the values arrays of commands that are allowed to occur inside those
# commands. All commands not in this hash are considered to accept anything.
# There are additional context tests, to make sure, for instance that we are
# testing @-commands on the block, line or node @-command line and not
# in the content.
my %default_valid_nestings;

foreach my $command (keys(%contain_plain_text_commands)) {
  $default_valid_nestings{$command} = \%in_plain_text_commands;
}

foreach my $command (keys(%contain_full_text_commands)) {
  $default_valid_nestings{$command} = \%in_full_text_commands;
}

# @this* commands should not appear in any line command except for
# page heading specification commands and can also appear in brace @-commands,
# on heading specification commands lines, such as indicatric @-commands.

foreach my $brace_command (keys (%brace_commands)) {
  if ($brace_commands{$brace_command} eq 'style_code'
      or $brace_commands{$brace_command} eq 'style_other'
      or $brace_commands{$brace_command} eq 'style_no_code') {

    # duplicate hash to avoid modifying shared structure
    $default_valid_nestings{$brace_command}
     = { %{$default_valid_nestings{$brace_command}} };

    foreach my $in_heading_spec (keys(%in_heading_spec_commands)) {
      $default_valid_nestings{$brace_command}->{$in_heading_spec} = 1;
    }
  }
}

# For _check_valid_nesting_context

my %in_basic_inline_commands = %in_full_text_commands;
foreach my $not_in_basic_inline_commands
                               ('xref', 'ref', 'pxref', 'inforef',
                                'titlefont', 'anchor', 'footnote', 'verb') {
  delete $in_basic_inline_commands{$not_in_basic_inline_commands};
}

foreach my $in_heading_spec (keys(%in_heading_spec_commands)) {
  $in_basic_inline_commands{$in_heading_spec} = 1;
}

my %contain_basic_inline_with_refs_commands = (%sectioning_heading_commands,
                                      %def_commands);
my %ok_in_basic_inline_with_refs_commands;
foreach my $permitted_command ('xref', 'ref', 'pxref', 'inforef') {
  $ok_in_basic_inline_with_refs_commands{$permitted_command} = 1;
}

my %not_in_region_commands;
foreach my $block_command (keys(%block_commands)) {
  $not_in_region_commands{$block_command} = 1
    if ($block_commands{$block_command} eq 'region');
}


# index names that cannot be set by the user.
my %forbidden_index_name = ();

foreach my $name (keys(%index_names)) {
  $forbidden_index_name{$name} = 1;
  if ($name =~ /^(.).$/) {
    $forbidden_index_name{$1} = 1;
  }
}

foreach my $other_forbidden_index_name ('info','ps','pdf','htm',
   'html', 'log','aux','dvi','texi','txi','texinfo','tex','bib') {
  $forbidden_index_name{$other_forbidden_index_name} = 1;
}

my %canonical_texinfo_encodings;
# Valid encodings as described in the Texinfo manual
foreach my $canonical_encoding ('us-ascii', 'utf-8', 'iso-8859-1',
                  'iso-8859-15', 'iso-8859-2', 'koi8-r', 'koi8-u') {
  $canonical_texinfo_encodings{$canonical_encoding} = 1;
}

my %begin_paragraph_contexts;
foreach my $begin_paragraph_context ('base') {
  $begin_paragraph_contexts{'ct_'.$begin_paragraph_context} = 1;
}



# Interface and internal functions for input management

# initialization entry point.  Set up a parser.
# The last argument, optional, is a hash provided by the user to change
# the default values for what is present in %parser_document_parsing_options.
sub parser(;$)
{
  my $conf = shift;

  # In Texinfo::Common because all the
  # customization options information is gathered here, and also
  # because it is used in other codes, in particular the XS parser.
  # Note that it also contains inner options like accept_internalvalue
  # and customizable document parser state values in addition to
  # regular customization options.
  my $parser_conf = dclone(\%Texinfo::Common::parser_document_parsing_options);
  my $parser = {};
  bless $parser;

  # Reset conf from argument, restricting to parser_document_parsing_options
  $parser->{'set'} = {};
  if (defined($conf)) {
    foreach my $key (keys(%$conf)) {
      if (exists($Texinfo::Common::parser_document_parsing_options{$key})) {
        if (ref($conf->{$key})) {
          $parser_conf->{$key} = dclone($conf->{$key});
        } else {
          $parser_conf->{$key} = $conf->{$key};
        }
        if ($initialization_overrides{$key}) {
          $parser->{'set'}->{$key} = $parser_conf->{$key};
        }
      } else {
        warn "ignoring parser configuration value \"$key\"\n";
      }
    }
  }

  # This is not very useful in perl, but mimics the XS parser
  print STDERR "!!!!!!!!!!!!!!!! RESETTING THE PARSER !!!!!!!!!!!!!!!!!!!!!\n"
    if ($parser_conf->{'DEBUG'});

  # turn the array to a hash for speed.  Not sure it really matters for such
  # a small array.
  $parser->{'expanded_formats_hash'} = {};
  foreach my $expanded_format(@{$parser_conf->{'EXPANDED_FORMATS'}}) {
    $parser->{'expanded_formats_hash'}->{$expanded_format} = 1;
  }

  $parser->{'registrar'} = Texinfo::Report::new();

  # variables set to the parser initialization values only.  What is
  # found in the document has no effect.  Also used to initialize some
  # parsing state.
  $parser->{'conf'} = $parser_conf;

  return $parser;
}

sub _initialize_parsing($$)
{
  my $parser = shift;
  my $context = shift;

  my $index_names;
  if (!$parser->{'conf'}->{'NO_INDEX'}) {
    $index_names = dclone(\%index_names);
  } else {
    # not needed, but not undef because it is exported to document
    $index_names = {};
  }

  my $document = Texinfo::Document::new_document($index_names);

  my $parser_state = dclone(\%parser_state_initialization);
  _push_context($parser_state, $context, undef);

  # initialize from conf.
  if ($parser->{'conf'}->{'values'}) {
    $parser_state->{'values'} = dclone($parser->{'conf'}->{'values'});
  }
  if (defined($parser->{'conf'}->{'documentlanguage'})) {
    $parser_state->{'documentlanguage'}
      = $parser->{'conf'}->{'documentlanguage'};
  }

  $parser_state->{'document'} = $document;

  # In gdt(), both NO_INDEX and NO_USER_COMMANDS are set and this has a sizable
  # effect on performance.

  if (!$parser->{'conf'}->{'NO_INDEX'}) {
    # Initialize command hash that are dynamically modified for index
    # commands.
    $parser_state->{'command_index'} = {%command_index};
    $parser_state->{'index_entry_commands'} = {%index_entry_command_commands};
  } else {
    # with NO_INDEX index entries are not set and most indices information
    # is not needed at all.
    # not needed
    #$parser_state->{'command_index'} = {};
    $parser_state->{'index_entry_commands'} = \%index_entry_command_commands;
  }

  if (!$parser->{'conf'}->{'NO_USER_COMMANDS'}) {
    # Initialize command hash that are dynamically modified for
    # definfoenclose, based on defaults.
    $parser_state->{'brace_commands'} = dclone(\%brace_commands);
    $parser_state->{'valid_nestings'} = dclone(\%default_valid_nestings);
  } else {
    # with NO_USER_COMMANDS, new commands are not defined (no user-defined
    # macros, alias, no new index commands).  Therefore, the default data can
    # be used as it won't be modified.
    $parser_state->{'brace_commands'} = \%brace_commands;
    $parser_state->{'valid_nestings'} = \%default_valid_nestings;
  }

  if ($parser->{'conf'}->{'NO_USER_COMMANDS'}
      or $parser->{'conf'}->{'NO_INDEX'}) {
    # with NO_USER_COMMANDS or NO_INDEX, new index commands are not defined.
    # Therefore, the default data can be used as it won't be modified.
    $parser_state->{'line_commands'} = \%line_commands;
    $parser_state->{'no_paragraph_commands'} = \%no_paragraph_commands;
    $parser_state->{'basic_inline_commands'} = \%contain_basic_inline_commands;
  } else {
    # Initialize command hash that are dynamically modified for index commands,
    # based on defaults.
    $parser_state->{'line_commands'} = dclone(\%line_commands);
    $parser_state->{'no_paragraph_commands'} = {%no_paragraph_commands};
    $parser_state->{'basic_inline_commands'} = {%contain_basic_inline_commands};
  }

  # We rely on parser state overriding the previous state infomation
  # in self, as documented in perldata:
  #   If a key appears more than once in the initializer list of a hash, the last occurrence wins
  %$parser = (%$parser, %$parser_state);
  return $document;
}

sub _new_text_input($$)
{
  my $text = shift;
  my $input_source_info = shift;

  my $texthandle = do { local *FH };
  # In-memory scalar strings are considered a stream of bytes, so need
  # to encode/decode.
  $text = Encode::encode('utf-8', $text);
  # Could fail with error like
  # Strings with code points over 0xFF may not be mapped into in-memory file handles
  if (!open($texthandle, '<', \$text)) {
    my $error_message = $!;
    # Better die now than later reading on a closed filehandle.
    die "BUG? open on a reference failed: $error_message\n";
  }
  return {'th' => $texthandle,
          'input_source_info' => $input_source_info};
}

# Store $TEXT as a source for Texinfo content.
# $MACRO_name is the name of the macro expanded as text.  It should only
# be given if this is the text corresponds to a new macro expansion.
# If already within a macro expansion, but not from a macro expansion
# (from a value expansion, for instance), the macro name will be taken
# from the input stack.
# $VALUE_FLAG is the name of the value flag expanded as text.
sub _input_push_text($$$;$$)
{
  my ($self, $text, $line_nr, $macro_name, $value_name) = @_;

  my $input_source_info = {'line_nr' => $line_nr};
  if (scalar(@{$self->{'input'}})) {
    if (exists($self->{'input'}->[0]->{'input_source_info'}->{'file_name'})) {
      $input_source_info->{'file_name'}
        = $self->{'input'}->[0]->{'input_source_info'}->{'file_name'};
    }
    # context macro expansion
    if (exists($self->{'input'}->[0]->{'input_source_info'}->{'macro'})) {
      $input_source_info->{'macro'}
        = $self->{'input'}->[0]->{'input_source_info'}->{'macro'};
    }
  }
  if (defined($macro_name) and $macro_name ne '') {
    # new macro expansion
    $input_source_info->{'macro'} = $macro_name;
  }
  if (not defined($value_name) and not defined($input_source_info->{'macro'})) {
    # this counteracts the increment that would follow from the next
    # call to _next_text.
    $input_source_info->{'line_nr'} -= 1;
  }
  my $text_input = _new_text_input($text, $input_source_info);
  $text_input->{'value_flag'} = $value_name if (defined($value_name));
  # only set for new macro expansion
  $text_input->{'macro_name'} = $macro_name if (defined($macro_name));
  unshift @{$self->{'input'}}, $text_input;
}

# push text sharing the same input_source_info as current top input
sub _input_pushback_text($$;$)
{
  my ($self, $text, $line_nr) = @_;

  if (defined($text) and $text ne '') {
    my $text_input = _new_text_input($text,
                          $self->{'input'}->[0]->{'input_source_info'});
    unshift @{$self->{'input'}}, $text_input;
    $text_input->{'input_source_info'}->{'line_nr'} -= 1
      unless(defined($text_input->{'input_source_info'}->{'macro'}));
  }
}

# entry point for text fragments.
# Used in some tests.
sub parse_texi_piece($$;$)
{
  my ($self, $text, $line_nr) = @_;

  return undef if (!defined($text) or !defined($self));

  $line_nr = 1 if (not defined($line_nr));

  my $document = $self->_initialize_parsing('ct_base');

  _input_push_text($self, $text, $line_nr);

  my ($document_root, $before_node_section)
     = _setup_document_root_and_before_node_section();
  $self->_parse_texi($document_root, $before_node_section);

  get_parser_info($self);

  return $document;
}

sub parse_texi_line($$;$)
{
  my ($self, $text, $line_nr) = @_;

  return undef if (!defined($text) or !defined($self));

  $line_nr = 1 if (not defined($line_nr));

  my $document = $self->_initialize_parsing('ct_line');

  _input_push_text($self, $text, $line_nr);

  my $root = {'type' => 'root_line'};
  $self->_parse_texi($root, $root);
  get_parser_info($self);

  # add the errors to the Parser registrar as there is no document
  # returned to get the errors from.
  push @{$self->{'registrar'}->{'errors_warnings'}},
      @{$document->{'parser_registrar'}->{'errors_warnings'}};
  $self->{'registrar'}->{'error_nrs'}
     += $document->{'parser_registrar'}->{'error_nrs'};

  return $document->tree();
}

sub parse_texi_text($$;$)
{
  my ($self, $text, $line_nr) = @_;

  return undef if (!defined($text) or !defined($self));

  $line_nr = 1 if (not defined($line_nr));

  my $document = $self->_initialize_parsing('ct_base');

  _input_push_text($self, $text, $line_nr);

  $self->_parse_texi_document();

  get_parser_info($self);
  return $document;
}


# $INPUT_FILE_PATH the name of the opened file should be a binary string.
# Returns binary strings too.
sub _input_push_file
{
  my ($self, $input_file_path, $file_name_encoding) = @_;

  my ($file_name, $directories, $suffix) = fileparse($input_file_path);

  my $filehandle = do { local *FH };
  if (!open($filehandle, $input_file_path)) {
    return 0, $file_name, $directories, $!;
  }

  # to be able to change the encoding in the midst of reading a file,
  # the file is opened in binary mode, no decoding is done on the file
  # descriptor, but decoding is done after reading.
  #
  # The reason why it must be done so is that there is no possibility
  # to avoid buffering for the input.  Therefore some of the input file
  # is always read in advance.  Decoding using layers on the input file
  # descriptor by setting, each time @documentencoding is seen
  #   binmode($filehandle, ":encoding($encoding)")
  # will fail, as the input file has already been read and the previous
  # layer has already been used to decode when the encoding is changed.
  # This is tested in the formats_encodings multiple_include_encodings
  # test.
  binmode($filehandle);

  my $file_input = {
       'input_source_info' => {
          # binary
          'file_name' => $file_name,
          'line_nr' => 0,
       },
       'fh' => $filehandle,
       'input_file_path' => $input_file_path,
    };
  $file_input->{'file_input_encoding'} = $self->{'input_file_encoding'}
    if (defined($self->{'input_file_encoding'}));

  $file_input->{'file_name_encoding'} = $file_name_encoding
       if (defined($file_name_encoding));
  unshift @{$self->{'input'}}, $file_input;

  return 1, $file_name, $directories, undef;
}

sub get_parser_info($)
{
  my $self = shift;

  my $document = $self->{'document'};

  my $global_commands = $document->{'commands_info'};

  # information based on commands commonly needed.
  if ($global_commands->{'novalidate'}) {
    $document->{'global_info'}->{'novalidate'} = 1;
  }

  if ($global_commands->{'setfilename'}
      and $global_commands->{'setfilename'}->{'extra'}
      and defined($global_commands->{'setfilename'}->{'extra'}->{'text_arg'})) {
    $document->{'global_info'}->{'setfilename'}
      = $global_commands->{'setfilename'}->{'extra'}->{'text_arg'};
  }

  my $document_language
    = Texinfo::Common::get_global_document_command($global_commands,
                                                   'documentlanguage',
                                                   'preamble');
  if ($document_language) {
    $document->{'global_info'}->{'documentlanguage'}
      = Texinfo::Common::informative_command_value($document_language);
  }
}

# parse a texi file
# $INPUT_FILE_PATH is the name of the parsed file and should be a binary string.
sub parse_texi_file($$)
{
  my ($self, $input_file_path) = @_;

  return undef if (!defined($self));

  my $document = $self->_initialize_parsing('ct_base');

  my ($status, $file_name, $directories, $error_message)
    = _input_push_file($self, $input_file_path);

  $document->{'global_info'}->{'input_file_name'} = $file_name;
  $document->{'global_info'}->{'input_directory'} = $directories;

  if (!$status) {
    my $decoded_input_file_path = $input_file_path;
    my $encoding = $self->{'conf'}->{'COMMAND_LINE_ENCODING'};
    if (defined($encoding)) {
      $decoded_input_file_path = decode($encoding, $input_file_path);
    }
    $document->{'parser_registrar'}->document_error(
                 sprintf(__("could not open %s: %s"),
                                  $decoded_input_file_path, $error_message));
    return $document;
  }

  $self->_parse_texi_document();
  get_parser_info($self);

  return $document;
}

sub _parse_texi_document($)
{
  my $self = shift;

  my ($document_root, $before_node_section)
     = _setup_document_root_and_before_node_section();

  my $source_info;

  # put the empty lines and the \input line in a container at the beginning
  my $preamble_before_beginning;
  while (1) {
    my $line;
    ($line, $source_info) = _next_text($self);
    last if (!defined($line));
    # non ascii spaces do not start content
    if ($line =~ /^ *\\input/ or $line =~ /^\s*$/) {
      if (not defined($preamble_before_beginning)) {
        $preamble_before_beginning = {'type' => 'preamble_before_beginning',
                        'contents' => [], 'parent' => $before_node_section };
        push @{$before_node_section->{'contents'}}, $preamble_before_beginning;
      }
      push @{$preamble_before_beginning->{'contents'}},
                               { 'text' => $line,
                                 'type' => 'text_before_beginning',
                                 'parent' => $preamble_before_beginning };
    } else {
      # This line is not part of the preamble_before_beginning.
      # Shove back into input stream.
      _input_pushback_text($self, $line);
      last;
    }
  }

  my $document = $self->_parse_texi($document_root, $before_node_section);

  Texinfo::Common::rearrange_tree_beginning($document, $before_node_section);

  return $document;
}

sub errors($)
{
  my $self = shift;
  my $registrar = $self->{'registrar'};
  if (!$registrar) {
    return undef;
  }
  my ($error_warnings_list, $error_count) = $registrar->errors();

  $registrar->clear();

  return $error_warnings_list, $error_count;
}

# Following are the internal parsing subroutines.  The most important are
#
# _parse_texi:                main entry point, loop on input lines.
# _process_remaining_on_line: the main parser loop.
# _end_line:                  called at an end of line.  Handling of
#                             @include lines is done here.
# _next_text:                 present the next text fragment, from
#                             pending text or line.

# context stack functions
sub _push_context($$$)
{
  my ($self, $context, $command) = @_;

  push @{$self->{'context_stack'}}, $context;
  push @{$self->{'context_command_stack'}}, $command;
}

# if needed it could be possible to guard against removing first 'ct_base'
# context.
sub _pop_context($$$$;$)
{
  my ($self, $expected_contexts, $source_info, $current, $message) = @_;

  my $popped_context = pop @{$self->{'context_stack'}};
  if (not grep {$_ eq $popped_context} @$expected_contexts) {
    my $error_message = "context $popped_context instead of "
         .join(" or ", @$expected_contexts);
    $error_message .= "; $message" if (defined($message));
    $self->_bug_message($error_message, $source_info, $current);
    cluck;
    die;
  }
  my $popped_command = pop @{$self->{'context_command_stack'}};
}

sub _get_context_stack($)
{
  my $self = shift;
  my @context_stack = @{$self->{'context_stack'}};
  return @context_stack;
}

sub _top_context($)
{
  my $self = shift;
  return $self->{'context_stack'}->[-1];
}

# find first non undef command
sub _current_context_command($)
{
  my $self = shift;
  for (my $i = scalar(@{$self->{'context_command_stack'}}) -1; $i > 0; $i--) {
    if (defined($self->{'context_command_stack'}->[$i])) {
      return $self->{'context_command_stack'}->[$i];
    }
  }
  return undef;
}

# register warnings and errors
sub _line_warn
{
  my $self = shift;
  my $text = shift;
  my $error_location_info = shift;
  my $continuation = shift;
  my $debug = shift;
  my $registrar = $self->{'document'}->{'parser_registrar'};
  $registrar->line_warn($text, $error_location_info, $continuation,
                        $self->{'conf'}->{'DEBUG'});
}

sub _line_error
{
  my $self = shift;
  my $text = shift;
  my $error_location_info = shift;
  my $continuation = shift;

  my $registrar = $self->{'document'}->{'parser_registrar'};
  $registrar->line_error($text, $error_location_info, $continuation,
                         $self->{'conf'}->{'DEBUG'});
}

# Format a bug message
sub _bug_message($$;$$)
{
  my ($self, $message, $source_info, $current) = @_;

  my $line_message = '';
  if ($source_info) {
    my $file_name;
    if (defined($source_info->{'file_name'})) {
      $file_name = $source_info->{'file_name'};
    } else {
      $file_name = '';
    }
    $line_message
      = "last location: $file_name:$source_info->{'line_nr'}";
    if (defined($source_info->{'macro'})) {
      $line_message .= " (possibly involving $source_info->{'macro'})";
    }
    $line_message .= "\n";
  }
  my @context_stack = $self->_get_context_stack;
  my $message_context_stack = "context_stack: (@context_stack)\n";
  my $current_element_message = '';
  if ($current) {
    $current_element_message = "current: "
                    .Texinfo::Common::debug_print_element($current);
  }
  warn "You found a bug: $message\n\n".
       "Additional information:\n".
       $line_message.$message_context_stack.$current_element_message;
}

# for debugging
sub _print_command_args_texi($)
{
  my $current = shift;
  return '' if (!$current->{'cmdname'});
  my $args = '';
  my $with_brace;
  if ($current->{'args'} and @{$current->{'args'}}) {
    $with_brace
        = ($current->{'args'}->[0]->{'type'} eq 'brace_container'
           or $current->{'args'}->[0]->{'type'} eq 'brace_arg'
           or $current->{'args'}->[0]->{'type'} eq 'brace_command_context');
    $args .= '{' if ($with_brace);
    foreach my $arg (@{$current->{'args'}}) {
      $args .= Texinfo::Convert::Texinfo::convert_to_texinfo($arg).', ';
    }
    $args =~ s/, $//;
  }
  chomp($args);
  if ($with_brace) {
    $args .= '}';
  }
  return '@'.$current->{'cmdname'} .$args."\n";
}

sub _register_global_command {
  my ($self, $current, $source_info) = @_;

  my $document = $self->{'document'};

  my $command = $current->{'cmdname'};

  if ($command eq 'summarycontents') {
    $command = 'shortcontents';
  }
  if ($global_multiple_commands{$command}) {
    push @{$document->{'commands_info'}->{$command}}, $current;
    $current->{'source_info'} = $source_info if (!$current->{'source_info'});
    $current->{'extra'} = {} if (!$current->{'extra'});
    $current->{'extra'}->{'global_command_number'}
      = scalar(@{$document->{'commands_info'}->{$command}});
    return 1;
  } elsif ($global_unique_commands{$command}) {
    # setfilename ignored in an included file
    $current->{'source_info'} = $source_info if (!$current->{'source_info'});
    if ($command eq 'setfilename'
        and _in_include($self)) {
    } elsif (exists ($document->{'commands_info'}->{$current->{'cmdname'}})) {
      $self->_line_warn(sprintf(__('multiple @%s'),
                               $current->{'cmdname'}), $source_info);
    } else {
      $document->{'commands_info'}->{$current->{'cmdname'}} = $current;
    }
    return 1;
  }
  return 0;
}

# $ELEMENT should be the parent container.
sub _register_source_mark
{
  my ($self, $element, $source_mark) = @_;

  if (!defined($source_mark->{'counter'})) {
    my $counter_name = $source_mark->{'sourcemark_type'};
    if (!$self->{'source_mark_counters'}->{$counter_name}) {
      $self->{'source_mark_counters'}->{$counter_name} = 0;
    }
    $self->{'source_mark_counters'}->{$counter_name} += 1;
    $source_mark->{'counter'}
      = $self->{'source_mark_counters'}->{$counter_name};
  }
  _place_source_mark($self, $element, $source_mark);
}

sub _debug_show_source_mark
{
  my $source_mark = shift;
  return "$source_mark->{'sourcemark_type'} c: "
   .(defined($source_mark->{'counter'}) ? $source_mark->{'counter'}: 'UNDEF')
    ." p: ".(defined($source_mark->{'position'})
             ? $source_mark->{'position'}: 0)." "
     .(defined($source_mark->{'status'}) ? $source_mark->{'status'}: 'UNDEF');
}

# $ELEMENT should be the parent container.
# The source mark is put in the last content.
sub _place_source_mark
{
  my ($self, $element, $source_mark) = @_;

  # for debug
  my $add_element_string = 'no-add';
  $source_mark->{'position'} = 0;
  # the element that holds the source mark
  my $mark_element;
  if ($element->{'contents'} and scalar(@{$element->{'contents'}}) > 0) {
    my $current = $element->{'contents'}->[-1];
    $mark_element = $current;
    # if there is no text, the source mark is supposed to be
    # at the end of/after the element
    if (defined($current->{'text'}) and $current->{'text'} ne '') {
      $source_mark->{'position'} = length($current->{'text'});
    }
  } else {
    # add an empty element only used for source marks
    # 'text' is here to have merge_text work as expected
    $mark_element = {'parent' => $element, 'text' => ''};
    $element->{'contents'} = [] unless (defined($element->{'contents'}));
    push @{$element->{'contents'}}, $mark_element;
    $add_element_string = 'add';
  }
  if ($source_mark->{'position'} == 0) {
    delete $source_mark->{'position'};
  }

  print STDERR "MARK "._debug_show_source_mark($source_mark)
   ." $add_element_string ".Texinfo::Common::debug_print_element($mark_element)
      .' '.Texinfo::Common::debug_print_element($element)."\n"
        if ($self->{'conf'}->{'DEBUG'});

  if (!$mark_element->{'source_marks'}) {
    $mark_element->{'source_marks'} = [];
  }
  push @{$mark_element->{'source_marks'}}, $source_mark;
}

sub _transfer_source_marks($$)
{
  my $from_e = shift;
  my $element = shift;

  if (!defined($from_e)) {confess()};

  if ($from_e->{'source_marks'}) {
    if (!$element->{'source_marks'}) {
      $element->{'source_marks'} = [];
    }
    push @{$element->{'source_marks'}}, @{$from_e->{'source_marks'}};
    delete $from_e->{'source_marks'};
  }
}

sub _debug_protect_eol($)
{
  my $line = shift;
  $line =~ s/\n/\\n/g;
  return $line;
}

# parse a @macro line
sub _parse_macro_command_line($$$$$;$)
{
  my ($self, $command, $line, $parent, $source_info) = @_;

  my $macro = { 'cmdname' => $command, 'parent' => $parent,
               'info' => {'arg_line' => $line}, 'source_info' => $source_info };
  # REMACRO
  my $macro_name;
  if ($line =~ s/^\s+([[:alnum:]][[:alnum:]_-]*)//) {
    $macro_name = $1;
  } else {
    $self->_line_error(sprintf(
               __("\@%s requires a name"), $command), $source_info);
    $macro->{'extra'} = {'invalid_syntax' => 1};
    return $macro;
  }

  if ($line ne '' and $line !~ /^([{@]|\s)/) {
    $self->_line_error(sprintf(
                    __("bad name for \@%s"), $command), $source_info);
    $macro->{'extra'} = {'invalid_syntax' => 1};
  } else {
    print STDERR "MACRO \@$command $macro_name\n"
                           if ($self->{'conf'}->{'DEBUG'});

    $macro->{'args'} = [
      { 'type' => 'macro_name', 'text' => $macro_name,
          'parent' => $macro } ];

    my $args_def = $line;
    $args_def =~ s/^\s*//;

    my @args;
    if ($args_def =~ s/^{\s*(.*?)\s*}\s*//) {
      @args = split(/\s*,\s*/, $1);
    }

    foreach my $formal_arg (@args) {
      push @{$macro->{'args'}},
        { 'type' => 'macro_arg', 'text' => $formal_arg,
          'parent' => $macro};
      if ($formal_arg !~ /^[\w\-]+$/) {
        $self->_line_error(sprintf(__("bad or empty \@%s formal argument: %s"),
                                   $command, $formal_arg), $source_info);
        $macro->{'extra'} = {'invalid_syntax' => 1};
      }
    }
    # accept an @-command after the arguments in case there is a @c or
    # @comment
    if ($args_def =~ /^\s*[^\@]/) {
      my $no_eol_args = $args_def;
      chomp ($no_eol_args);
      $self->_line_error(sprintf(__("bad syntax for \@%s argument: %s"),
                                 $command, $no_eol_args),
                         $source_info);
      $macro->{'extra'} = {'invalid_syntax' => 1};
    }
  }
  return $macro;
}

# return true if in a context where paragraphs are to be started.
sub _in_begin_paragraph($$)
{
  # we want to avoid
  # brace_container, brace_arg, root_line (ct_line),
  # paragraphs (ct_paragraph), line_arg (ct_line, ct_def), balanced_braces
  # (only in ct_math, ct_rawpreformatted, ct_inlineraw), block_line_arg
  # (ct_line, ct_def), preformatted (ct_preformatted).
  my ($self, $current) = @_;
  return ($begin_paragraph_contexts{$self->_top_context()}
          and not ($current->{'type'}
                   and $type_without_paragraph{$current->{'type'}}));
}

# start a paragraph.
sub _begin_paragraph($$)
{
  my ($self, $current) = @_;

  # find whether an @indent precedes the paragraph
  my $indent;
  if ($current->{'contents'}) {
    my $index = scalar(@{$current->{'contents'}}) -1;
    while ($index >= 0
          and !($current->{'contents'}->[$index]->{'type'}
            and ($current->{'contents'}->[$index]->{'type'} eq 'empty_line'
                 or $current->{'contents'}->[$index]->{'type'} eq 'paragraph'))
          and !($current->{'contents'}->[$index]->{'cmdname'}
                and $close_paragraph_commands
                         {$current->{'contents'}->[$index]->{'cmdname'}})) {
      if ($current->{'contents'}->[$index]->{'cmdname'}
        and ($current->{'contents'}->[$index]->{'cmdname'} eq 'indent'
            or $current->{'contents'}->[$index]->{'cmdname'} eq 'noindent')) {
        $indent = $current->{'contents'}->[$index]->{'cmdname'};
        last;
      }
      $index--;
    }
  }
  push @{$current->{'contents'}},
          { 'type' => 'paragraph', 'parent' => $current };
  $current = $current->{'contents'}->[-1];
  if ($indent) {
    $current->{'extra'} = {$indent => 1};
  }
  $self->_push_context('ct_paragraph', undef);
  print STDERR "PARAGRAPH\n" if ($self->{'conf'}->{'DEBUG'});
  return $current;
}

sub _begin_preformatted($$)
{
  my ($self, $current) = @_;

  if ($self->_top_context() eq 'ct_preformatted') {
    push @{$current->{'contents'}},
          { 'type' => 'preformatted',
            'parent' => $current };
    $current = $current->{'contents'}->[-1];
    print STDERR "PREFORMATTED\n" if ($self->{'conf'}->{'DEBUG'});
  }
  return $current;
}

# wrapper around line_warn.  Set source_info to be the source_info of
# the command, corresponding to the opening of the command.
# Call line_warn with sprintf if needed.
sub _command_warn($$$;@)
{
  my $self = shift;
  my $current = shift;
  my $message = shift;

  my $source_info;

  if ($current->{'source_info'}) {
    $source_info = $current->{'source_info'};
  }
  if (@_) {
    $self->_line_warn(sprintf($message, @_), $source_info);
  } else {
    $self->_line_warn($message, $source_info);
  }
}

sub _command_error($$$;@)
{
  my $self = shift;
  my $current = shift;
  my $message = shift;

  my $source_info;

  # use the beginning of the @-command for the error message
  # line number if available.
  if ($current->{'source_info'}) {
    $source_info = $current->{'source_info'};
  }
  if (@_) {
    $self->_line_error(sprintf($message, @_), $source_info);
  } else {
    $self->_line_error($message, $source_info);
  }
}

# register error messages, but otherwise doesn't do much more than
# deleting remaining_args and returning $_[1]->{'parent'}
sub _close_brace_command($$$;$$$)
{
  my ($self, $current, $source_info, $closed_block_command,
      $interrupting_command, $missing_brace) = @_;

  delete $current->{'remaining_args'};

  if ($self->{'brace_commands'}->{$current->{'cmdname'}} eq 'context') {
    my $expected_context;
    if ($math_commands{$current->{'cmdname'}}) {
      $expected_context = 'ct_math';
    } else {
      $expected_context = 'ct_base';
    }
    _pop_context($self, [$expected_context], $source_info, $current);

    $self->{'nesting_context'}->{'footnote'} -= 1
      if ($current->{'cmdname'} eq 'footnote');
    $self->{'nesting_context'}->{'caption'} -= 1
      if ($current->{'cmdname'} eq 'caption'
        or $current->{'cmdname'} eq 'shortcaption');
  } elsif ($current->{'cmdname'} eq 'inlineraw') {
    _pop_context($self, ['ct_inlineraw'], $source_info, $current,
                 ' inlineraw');
  }

  # args are always set except in cases of bogus brace @-commands
  # without argument, maybe only at the end of a document.
  #die ("$current->{'cmdname'} no args\n") if (!$current->{'args'});

  if ($self->{'basic_inline_commands'}
      and $self->{'basic_inline_commands'}->{$current->{'cmdname'}}) {
    my $popped = pop @{$self->{'nesting_context'}->{'basic_inline_stack'}};
    if (!defined($popped)) {
      print STDERR "BUG: popped basic_inline_commands command "
                          ."stack empty: $current->{'cmdname'}\n";
    } elsif ($popped ne $current->{'cmdname'}) {
      print STDERR "BUG: popped basic_inline_commands "
                       ."'$popped': $current->{'cmdname'}\n";
    }
  }

  if ($current->{'cmdname'} ne 'verb'
      or $current->{'info'}->{'delimiter'} eq '') {
    if (defined($closed_block_command)) {
      $self->_command_error($current,
        __("\@end %s seen before \@%s closing brace"),
                  $closed_block_command, $current->{'cmdname'});
    } elsif (defined($interrupting_command)) {
      $self->_command_error($current,
        __("\@%s seen before \@%s closing brace"),
                  $interrupting_command, $current->{'cmdname'});
    } elsif ($missing_brace) {
      $self->_command_error($current,
        __("\@%s missing closing brace"), $current->{'cmdname'});
    }
  } elsif ($missing_brace) {
    $self->_command_error($current,
       __("\@%s missing closing delimiter sequence: %s}"),
       $current->{'cmdname'}, $current->{'info'}->{'delimiter'});
  }
  $current = $current->{'parent'};
  return $current;
}

sub _in_preformatted_context_not_menu($)
{
  my $self = shift;

  for (my $i = scalar(@{$self->{'context_command_stack'}}) -1; $i > 0; $i--) {
    my $context = $self->{'context_stack'}->[$i];
    # allow going through line context, for @*table to find the
    # outside context, and also assuming that they are in the same context
    # in term of preformatted.  Maybe def could be traversed too.
    if ($context ne 'ct_line' and $context ne 'ct_preformatted') {
      return 0;
    }
    my $command_name = $self->{'context_command_stack'}->[$i];
    if (defined($command_name)
        and (not $block_commands{$command_name} eq 'menu')
        and $context eq 'ct_preformatted') {
      return 1;
    }
  }
  return 0;
}

sub _kbd_formatted_as_code($$)
{
  my ($self, $current) = @_;

  if ($self->{'kbdinputstyle'} eq 'code') {
    return 1;
  } elsif ($self->{'kbdinputstyle'} eq 'example') {
    if ($self->_in_preformatted_context_not_menu()) {
      return 0;
    } else {
      return 1;
    }
  }
  return 0;
}

sub _in_paragraph($$)
{
  my ($self, $current) = @_;
  while ($current->{'parent'} and $current->{'parent'}->{'cmdname'}
         and exists($self->{'brace_commands'}
                                      ->{$current->{'parent'}->{'cmdname'}})
         and $self->{'brace_commands'}
                           ->{$current->{'parent'}->{'cmdname'}} ne 'context') {
    $current = $current->{'parent'}->{'parent'};
  }
  if ($current->{'type'} and $current->{'type'} eq 'paragraph') {
    return 1;
  } else {
    return 0;
  }
}

# close brace commands that don't set a new context (ie not @caption, @footnote)
sub _close_all_style_commands($$$;$$)
{
  my ($self, $current, $source_info, $closed_block_command,
      $interrupting_command) = @_;

  while ($current->{'parent'} and $current->{'parent'}->{'cmdname'}
          and exists($self->{'brace_commands'}
                                      ->{$current->{'parent'}->{'cmdname'}})
          and $self->{'brace_commands'}
                           ->{$current->{'parent'}->{'cmdname'}} ne 'context') {
    print STDERR "CLOSING(all_style_commands) "
      ."\@$current->{'parent'}->{'cmdname'}\n"
         if ($self->{'conf'}->{'DEBUG'});
    $current = _close_brace_command($self, $current->{'parent'}, $source_info,
                                    $closed_block_command,
                                    $interrupting_command, 1);
  }

  return $current;
}

# close brace commands except for @caption, @footnote then the paragraph
sub _end_paragraph($$$;$$)
{
  my ($self, $current, $source_info, $closed_block_command,
      $interrupting_command) = @_;

  $current = _close_all_style_commands($self, $current, $source_info,
                                       $closed_block_command,
                                       $interrupting_command);
  if ($current->{'type'} and $current->{'type'} eq 'paragraph') {
    print STDERR "CLOSE PARA\n" if ($self->{'conf'}->{'DEBUG'});
    $current = _close_container($self, $current, $source_info);
  }
  return $current;
}

# close brace commands except for @caption, @footnote then the paragraph
# or preformatted
sub _end_paragraph_preformatted($$$;$$)
{
  my ($self, $current, $source_info, $closed_block_command,
      $interrupting_command) = @_;

  $current = _close_all_style_commands($self, $current, $source_info,
                                       $closed_block_command,
                                       $interrupting_command);
  if ($current->{'type'} and $current->{'type'} eq 'paragraph') {
    print STDERR "CLOSE PARA\n" if ($self->{'conf'}->{'DEBUG'});
    $current = _close_container($self, $current, $source_info);
  } elsif ($current->{'type'} and $current->{'type'} eq 'preformatted') {
    print STDERR "CLOSE PREFORMATTED\n" if ($self->{'conf'}->{'DEBUG'});
    $current = _close_container($self, $current, $source_info);
  }
  return $current;
}

sub _is_container_empty($)
{
  my $current = shift;
  if (not $current->{'contents'}
      and not $current->{'args'}
      and (not defined($current->{'text'}) or $current->{'text'} eq '')
      and not $current->{'info'}) {
    return 1;
  }
  return 0;
}

sub _remove_empty_content($$)
{
  my $self = shift;
  my $current = shift;

  # remove an empty content that only holds source marks
  if ($current->{'contents'} and scalar(@{$current->{'contents'}}) == 1) {
    my $child_element = $current->{'contents'}->[0];
    if (not defined($child_element->{'cmdname'})
        and _is_container_empty($child_element)) {
      _transfer_source_marks($child_element, $current);
      print STDERR "REMOVE empty child "
         .Texinfo::Common::debug_print_element($child_element)
          .' from '.Texinfo::Common::debug_print_element($current)."\n"
            if ($self->{'conf'}->{'DEBUG'});
      _pop_element_from_contents($self, $current);
    }
  }
}

sub _close_container($$$)
{
  my $self = shift;
  my $current = shift;
  my $source_info = shift;

  _remove_empty_content($self, $current);

  if ($current->{'type'} and $current->{'type'} eq 'paragraph') {
    _pop_context($self, ['ct_paragraph'], $source_info, $current);
  }

  # remove element without contents nor associated information
  my $element_to_remove;
  if (_is_container_empty($current)) {
    print STDERR "CONTAINER EMPTY "
      .Texinfo::Common::debug_print_element($current, 1)
      .' ('.($current->{'source_marks'}
            ? scalar(@{$current->{'source_marks'}}) : 0)." source marks)\n"
        if ($self->{'conf'}->{'DEBUG'});
    # Keep the element only if there are source marks
    if (!$current->{'source_marks'}) {
      $element_to_remove = $current;
    }
  }
  $current = $current->{'parent'};

  if ($element_to_remove
      # this is to avoid removing empty containers in args,
      # happens with brace commands not closed at the end of
      # a manual
      and $current->{'contents'}
      and scalar(@{$current->{'contents'}})
      and $current->{'contents'}->[-1] eq $element_to_remove) {
    print STDERR "REMOVE empty type "
      .Texinfo::Common::debug_print_element($element_to_remove, 1)."\n"
        if ($self->{'conf'}->{'DEBUG'});
    _pop_element_from_contents($self, $current);
  }
  return $current;
}

# close brace commands except for @caption, @footnote then the preformatted
sub _end_preformatted($$$;$$)
{
  my ($self, $current, $source_info, $closed_block_command,
      $interrupting_command) = @_;

  $current = _close_all_style_commands($self, $current, $source_info,
                                       $closed_block_command,
                                       $interrupting_command);

  if ($current->{'type'} and $current->{'type'} eq 'preformatted') {
    print STDERR "CLOSE PREFORMATTED\n" if ($self->{'conf'}->{'DEBUG'});
    $current = _close_container($self, $current, $source_info);
  }
  return $current;
}

# check that there are no text holding environment (currently
# checking only paragraphs and preformatted) in contents
sub _check_no_text($)
{
  my $current = shift;
  my $after_paragraph = 0;
  foreach my $content (@{$current->{'contents'}}) {
    if ($content->{'type'} and $content->{'type'} eq 'paragraph') {
      $after_paragraph = 1;
      last;
    } elsif ($content->{'type'} and $content->{'type'} eq 'preformatted') {
      foreach my $preformatted_content (@{$content->{'contents'}}) {
        if ((defined($preformatted_content->{'text'})
             and $preformatted_content->{'text'} =~ /\S/)
            or ($preformatted_content->{'cmdname'}
                and ($preformatted_content->{'cmdname'} ne 'c'
                     and $preformatted_content->{'cmdname'} ne 'comment')
                and !($preformatted_content->{'type'}
                      and $preformatted_content->{'type'} eq 'index_entry_command'))) {
          $after_paragraph = 1;
          last;
        }
      }
      last if ($after_paragraph);
    }
  }
  return $after_paragraph;
}

# For @table/@ftable/@vtable.
# Collect recent material into a 'table_entry' element, containing
# 'table_term' and 'table_definition' elements.
# $CURRENT is the @table element.
# $NEXT_COMMAND is the command that follows the entry, usually @item.
# If it is @itemx, gather an 'inter_item' element instead.
sub _gather_previous_item($$;$$)
{
  my ($self, $current, $next_command, $source_info) = @_;

  # nothing to do in this case.
  if ($current->{'contents'}->[-1]->{'type'}
      and $current->{'contents'}->[-1]->{'type'} eq 'before_item') {
    if ($next_command and $next_command eq 'itemx') {
      $self->_line_error(sprintf(__("\@itemx should not begin \@%s"),
                                $current->{'cmdname'}), $source_info);
    }
    return;
  }
  my $type;
  # if before an itemx, the type is different since there should not be
  # real content, so it may be treated differently
  if ($next_command and $next_command eq 'itemx') {
    $type = 'inter_item';
  } else {
    $type = 'table_definition';
  }

  # Starting from the end, collect everything that is not an item or
  # itemx and put it into the $type.
  my $contents_count = scalar(@{$current->{'contents'}});
  my $begin;
  for (my $i = $contents_count - 1; $i >= 0; $i--) {
    if ($current->{'contents'}->[$i]->{'cmdname'}
        and ($current->{'contents'}->[$i]->{'cmdname'} eq 'item'
             or ($current->{'contents'}->[$i]->{'cmdname'} eq 'itemx'))) {
      $begin = $i + 1;
      last;
    }
  }
  $begin = 0 if !defined($begin);

  # Find the end
  my $end;
  if (defined($next_command)) {
    # Don't absorb trailing index entries as they are included with a
    # following @item.
    for (my $i = $contents_count - 1; $i >= $begin; $i--) {
      if (!$current->{'contents'}->[$i]->{'type'}
          or $current->{'contents'}->[$i]->{'type'} ne 'index_entry_command') {
        $end = $i + 1;
        last;
      }
    }
  }
  $end = $contents_count if !defined($end);

  # Move everything from 'begin' to 'end' to be children of
  # table_after_terms.
  my $table_after_terms;
  if ($end - $begin > 0) {
    my $new_contents = [];
    @{$new_contents} = splice @{$current->{'contents'}},
                              $begin, $end - $begin;
    $table_after_terms = {'type' => $type,
                           'contents' => $new_contents};
    foreach my $child (@{$new_contents}) {
      $child->{'parent'} = $table_after_terms;
    }
  }

  if ($type eq 'table_definition') {
    my $before_item;

    # setup a table_entry
    my $table_entry = {'type' => 'table_entry',
                    'parent' => $current,
                    'contents' => []};
    my $table_term = {'type' => 'table_term',
                    'parent' => $table_entry, };
    push @{$table_entry->{'contents'}}, $table_term;

    # We previously collected elements into a table_definition.  Now
    # do the same for a table_term, starting from the beginning of the
    # table_definition going back to the previous table entry or beginning
    # of the table.
    my $contents_count = scalar(@{$current->{'contents'}});
    my $term_begin;
    for (my $i = $begin - 1; $i >= 0; $i--) {
      if ($current->{'contents'}->[$i]->{'type'}
           # reached the beginning of the table
           and ($current->{'contents'}->[$i]->{'type'} eq 'before_item'
                # reached the previous table entry
                or $current->{'contents'}->[$i]->{'type'} eq 'table_entry')) {
        if ($current->{'contents'}->[$i]->{'type'} eq 'before_item') {
          # register the before_item if we reached it in order to
          # reparent some before_item content to the first item
          $before_item = $current->{'contents'}->[$i];
        }
        $term_begin = $i + 1;
        last;
      }
    }
    $term_begin = 0 if !defined($term_begin);

    if ($begin - $term_begin > 0) {
      my $new_contents = [];
      @{$new_contents} = splice @{$current->{'contents'}},
                                $term_begin, $begin - $term_begin;
      $table_term->{'contents'} = $new_contents;
      for my $child (@{$new_contents}) {
        $child->{'parent'} = $table_term;
      }
    }
    if (defined($before_item) and $before_item->{'contents'}
        and scalar(@{$before_item->{'contents'}})) {
      print STDERR "REPARENT before_item content\n"
         if ($self->{'conf'}->{'DEBUG'});
      # reparent any trailing index entries in the before_item to the
      # beginning of table term
      while ($before_item->{'contents'}
             and scalar(@{$before_item->{'contents'}})
             and (($before_item->{'contents'}->[-1]->{'type'}
                   and $before_item->{'contents'}->[-1]->{'type'}
                     eq 'index_entry_command')
                  or ($before_item->{'contents'}->[-1]->{'cmdname'}
                   and ($before_item->{'contents'}->[-1]->{'cmdname'}
                           eq 'c'
                        or $before_item->{'contents'}->[-1]->{'cmdname'}
                           eq 'comment')))) {
        my $element = _pop_element_from_contents($self, $before_item);
        unshift @{$table_term->{'contents'}}, $element;
        $element->{'parent'} = $table_term;
      }
    }
    if ($table_after_terms) {
      # $table_after_terms necessarily with contents if defined
      push @{$table_entry->{'contents'}}, $table_after_terms;
      $table_after_terms->{'parent'} = $table_entry;
    }
    splice @{$current->{'contents'}}, $term_begin, 0, $table_entry;
  } else {
    # Gathering 'inter_item' between @item and @itemx
    if ($table_after_terms) {
      my $after_paragraph = _check_no_text($table_after_terms);
      # Text between @item and @itemx is only allowed in a few cases:
      # comments, empty lines, or index entries.
      if ($after_paragraph) {
        $self->_line_error(__("\@itemx must follow \@item"), $source_info);
      }
      if (scalar(@{$table_after_terms->{'contents'}})) {
        splice @{$current->{'contents'}}, $begin, 0, $table_after_terms;
        $table_after_terms->{'parent'} = $current;
      }
    }
  }
}

# Starting from the end, gather everything util the def_line to put in
# a def_item
sub _gather_def_item($$;$)
{
  my ($self, $current, $next_command) = @_;

  my $type;
  # means that we are between a @def*x and a @def
  if ($next_command
      and $next_command ne 'defline' and $next_command ne 'deftypeline') {
    $type = 'inter_def_item';
  } else {
    $type = 'def_item';
  }

  # This may happen for a construct like
  # @deffnx a b @section
  # but otherwise the end of line will lead to the command closing
  return if (!$current->{'cmdname'} or $current->{'cmdname'} =~ /x$/);

  # For @defline at the beginning of @defblock.
  return if !defined($current->{'contents'});

  my $contents_count = scalar(@{$current->{'contents'}});
  return if $contents_count == 0;

  my $def_item = {'type' => $type,
                  'parent' => $current,
                  'contents' => []};
  # remove everything that is not a def_line to put it in the def_item,
  # starting from the end.
  for (my $i = 0; $i < $contents_count; $i++) {
    if ($current->{'contents'}->[-1]->{'extra'}
        and $current->{'contents'}->[-1]->{'extra'}->{'def_command'}) {
      last;
    } else {
      my $item_content = _pop_element_from_contents($self, $current);
      $item_content->{'parent'} = $def_item;
      unshift @{$def_item->{'contents'}}, $item_content;
    }
  }
  my $gathered_content_count = scalar(@{$def_item->{'contents'}});
  if ($gathered_content_count) {
    if ($current->{'cmdname'} eq 'defblock'
      # all content between @defblock and first @def*line
        and $gathered_content_count == $contents_count) {
      $def_item->{'type'} = 'before_defline';
    }
    push @{$current->{'contents'}}, $def_item;
  }
}

# close formats
sub _close_command_cleanup($$) {
  my ($self, $current) = @_;

  return unless ($current->{'cmdname'});
  # remove the dynamic counters in multitable, they are not of use in the final
  # tree.  Also determine the multitable_body and multitable_head with
  # @item or @headitem rows.
  if ($current->{'cmdname'} eq 'multitable') {
    if ($current->{'contents'}) {
      my $in_head_or_rows;
      my @contents = @{$current->{'contents'}};
      $current->{'contents'} = [];
      foreach my $row (@contents) {
        if ($row->{'type'} and $row->{'type'} eq 'row') {
          delete $row->{'cells_count'};
          if ($row->{'contents'}->[0]->{'cmdname'} eq 'headitem') {
            if (!$in_head_or_rows) {
              push @{$current->{'contents'}}, {'type' => 'multitable_head',
                                               'parent' => $current};
              $in_head_or_rows = 1;
            }
          } elsif ($row->{'contents'}->[0]->{'cmdname'} eq 'item') {
            if (!defined($in_head_or_rows) or $in_head_or_rows) {
              push @{$current->{'contents'}}, {'type' => 'multitable_body',
                                               'parent' => $current};
              $in_head_or_rows = 0;
            }
          }
          push @{$current->{'contents'}->[-1]->{'contents'}}, $row;
          $row->{'parent'} = $current->{'contents'}->[-1];
        } else {
          push @{$current->{'contents'}}, $row;
          $in_head_or_rows = undef;
        }
      }
    }
  } elsif ($block_commands{$current->{'cmdname'}}
           and $block_commands{$current->{'cmdname'}} eq 'item_container') {
    delete $current->{'items_count'};
  }

  # put everything after the last @def*x command in a def_item type container.
  if ($def_commands{$current->{'cmdname'}}
      or $current->{'cmdname'} eq 'defblock') {
    # At this point the end command hasn't been added to the command contents.
    # so checks cannot be done at this point.
    _gather_def_item($self, $current);
  }

  if ($block_commands{$current->{'cmdname'}}
      and $block_commands{$current->{'cmdname'}} eq 'item_line') {
    # At this point the end command hasn't been added to the command contents.
    # so checks cannot be done at this point.
    if ($current->{'contents'} and scalar(@{$current->{'contents'}})) {
      _gather_previous_item($self, $current);
    }
  }

  # Block commands that contain @item's - e.g. @multitable, @table,
  # @itemize.
  # put end out of before_item, and replace it at the end of the parent.
  # remove empty before_item.
  # warn if not empty before_item, but format is empty
  if ($blockitem_commands{$current->{'cmdname'}}) {
    if ($current->{'contents'}
        and $current->{'contents'}->[0]->{'type'}
        and $current->{'contents'}->[0]->{'type'} eq 'before_item') {
      my $before_item = $current->{'contents'}->[0];
      if (_is_container_empty($before_item)
          and not $before_item->{'source_marks'}) {
        # remove empty before_item
        shift @{$current->{'contents'}};
      } else {
        # The elements that can appear right in a block item command
        # besides before_item are either an @*item or are associated
        # with items
        if (scalar(@{$current->{'contents'}}) == 1) {
          # no @*item, only before_item.  Warn if before_item is not empty
          my $empty_before_item = 1;
          if ($before_item->{'contents'}) {
            foreach my $before_item_content (@{$before_item->{'contents'}}) {
              if (!$before_item_content->{'cmdname'}
                 or ($before_item_content->{'cmdname'} ne 'c'
                      and $before_item_content->{'cmdname'} ne 'comment')) {
                $empty_before_item = 0;
                last;
              }
            }
          }
          if (!$empty_before_item) {
            $self->_line_warn(sprintf(__("\@%s has text but no \@item"),
                         $current->{'cmdname'}), $current->{'source_info'});
          }
        }
      }
    }
  }
}

sub _pop_block_command_contexts($$$;$)
{
  my $self = shift;
  my $current = shift;
  my $source_info = shift;
  my $context_string = shift;
  if ($preformatted_commands{$current->{'cmdname'}}
      or $block_commands{$current->{'cmdname'}} eq 'menu') {
    _pop_context($self, ['ct_preformatted'], $source_info, $current,
                        $context_string);
  } elsif ($block_commands{$current->{'cmdname'}} eq 'format_raw') {
    _pop_context($self, ['ct_rawpreformatted'], $source_info, $current,
                        $context_string);
  } elsif ($math_commands{$current->{'cmdname'}}) {
    _pop_context($self, ['ct_math'], $source_info, $current,
                        $context_string);
  } elsif ($block_commands{$current->{'cmdname'}} eq 'region') {
    pop @{$self->{'nesting_context'}->{'regions_stack'}};
  }
}

sub _close_ignored_block_conditional($$)
{
  my $self = shift;
  my $parent = shift;

  my $conditional = _pop_element_from_contents($self, $parent);
  delete $conditional->{'parent'};
  my $source_mark = {'sourcemark_type' => 'ignored_conditional_block',
                     'element' => $conditional};
  _register_source_mark($self, $parent, $source_mark);
}

# close the current command, with error messages and give the parent.
# If the last argument is given it is the command being closed if
# hadn't there be an error, currently only block command, used for a
# better error message.
sub _close_current($$$;$$)
{
  my ($self, $current, $source_info, $closed_block_command,
      $interrupting_command) = @_;
  # Element is a command
  if ($current->{'cmdname'}) {
    my $command = $current->{'cmdname'};
    print STDERR "CLOSING(close_current) \@$command\n"
         if ($self->{'conf'}->{'DEBUG'});
    if (exists($self->{'brace_commands'}->{$command})) {
      $current = _close_brace_command($self, $current, $source_info,
                                      $closed_block_command,
                                      $interrupting_command, 1);
    } elsif (exists($block_commands{$command})) {
      if (defined($closed_block_command)) {
        $self->_line_error(sprintf(__("`\@end' expected `%s', but saw `%s'"),
                                   $command, $closed_block_command),
                           $source_info);
      } elsif ($interrupting_command) {
        $self->_line_error(sprintf(__("\@%s seen before \@end %s"),
                                  $interrupting_command, $command),
                           $source_info);
      } else {
        $self->_line_error(sprintf(__("no matching `\@end %s'"),
                                   $command),
                           $source_info);
      }
      _pop_block_command_contexts($self, $current, $source_info);
      # empty non-closed block commands at the end of the document
      delete $current->{'contents'}
        if ($current->{'contents'} and scalar(@{$current->{'contents'}}) == 0);
      $current = $current->{'parent'};
      if ($block_commands{$command} eq 'conditional') {
        # In ignored conditional.
        _close_ignored_block_conditional($self, $current);
      }
    } else {
      # There @item and @tab commands are closed, and also line commands
      # with invalid content.
      $current = $current->{'parent'};
    }
  } elsif ($current->{'type'}) {
    print STDERR "CLOSING type $current->{'type'}\n"
                             if ($self->{'conf'}->{'DEBUG'});
    if ($current->{'type'} eq 'bracketed_arg') {
      # unclosed bracketed argument
      $self->_command_error($current, __("misplaced {"));
      if ($current->{'contents'}
          and $current->{'contents'}->[0]->{'type'}
          and $current->{'contents'}->[0]->{'type'}
                        eq 'internal_spaces_before_argument') {
        # remove spaces element from tree and update extra values
        _move_last_space_to_element($self, $current);
      }
      $current = $current->{'parent'};
    } elsif ($current->{'type'} eq 'balanced_braces') {
      # unclosed braces in contexts accepting lone braces
      $self->_command_error($current, __("misplaced {"));
      # We prefer adding an element to merging because we may
      # be at the end of the document after an empty line we
      # do not want to modify
      #$current = _merge_text($self, $current, '}');
      my $close_brace = {'text' => '}', 'parent' => $current};
      push @{$current->{'contents'}}, $close_brace;
      $current = $current->{'parent'};
    } elsif ($current->{'type'} eq 'line_arg') {
      $current = _end_line_misc_line($self, $current, $source_info);
    } elsif ($current->{'type'} eq 'block_line_arg') {
      $current = _end_line_starting_block($self, $current, $source_info);
    } else {
      $current = _close_container($self, $current, $source_info);
    }
  } else { # Should never go here.
    $current = $current->{'parent'} if ($current->{'parent'});
    $self->_bug_message("No type nor cmdname when closing",
                        $source_info, $current);
  }
  return $current;
}

# a closed_command arg means closing until that command is found.
# no command arg means closing until the root or a root_command
# is found.
sub _close_commands($$$;$$)
{
  my ($self, $current, $source_info, $closed_block_command,
      $interrupting_command) = @_;

  # should correspond to a bogus brace @-commands without argument
  # followed by spaces only, and not by newline, at the end of the document
  if ($current->{'cmdname'}
      and defined($self->{'brace_commands'}->{$current->{'cmdname'}})) {
    $self->_line_error(sprintf(__("\@%s expected braces"),
                       $current->{'cmdname'}), $source_info);
    if ($current->{'contents'}) {
      _gather_spaces_after_cmd_before_arg($self, $current);
    }
    $current = $current->{'parent'};
  }

  $current = _end_paragraph_preformatted($self, $current, $source_info,
                                         $closed_block_command,
                                         $interrupting_command);

        # stop if the command is found
  while (!($closed_block_command and $current->{'cmdname'}
           and $current->{'cmdname'} eq $closed_block_command)
         # Stop if at the root
         and $current->{'parent'}
         # Stop if at a type at the root
         and not ($current->{'type'}
                  and $current->{'type'} eq 'before_node_section')
     # Stop if in a root command
     # or in a context brace_commands and searching for a specific
     # end block command (with $closed_block_command set).
     # This second condition means that a footnote is not closed when
     # looking for the end of a block command, but is closed when
     # completly closing the stack.
         and !($current->{'cmdname'}
               and ($root_commands{$current->{'cmdname'}}
                    or ($closed_block_command and $current->{'parent'}->{'cmdname'}
                        and exists($brace_commands{$current->{'parent'}->{'cmdname'}})
                        and $brace_commands{
                                $current->{'parent'}->{'cmdname'}} eq 'context')))) {
    _close_command_cleanup($self, $current);
    $current = _close_current($self, $current, $source_info,
                              $closed_block_command,
                              $interrupting_command);
  }

  my $closed_element;
  if ($closed_block_command and $current->{'cmdname'}
      and $current->{'cmdname'} eq $closed_block_command) {

    _pop_block_command_contexts($self, $current, $source_info,
                                "for $closed_block_command");
    $closed_element = $current;
    $current = $current->{'parent'};

    if ($block_commands{$closed_element->{'cmdname'}} eq 'conditional') {
      # In ignored conditional.
      # NOTE since the source mark is registerd at command closing, in
      # case of nested ignored conditionals, the inside conditional will
      # be registered first.  It could probably possible to register
      # the source mark at the opening instead, but it is unclear which is
      # best.
      _close_ignored_block_conditional($self, $current);
    }

  } elsif ($closed_block_command) {
    $self->_line_error(sprintf(__("unmatched `%c%s'"),
                       ord('@'), "end $closed_block_command"), $source_info);
  }
  return ($closed_element, $current);
}

# begin paragraph if needed.  If not try to merge with the previous
# content if it is also some text.
# If $TRANSFER_MARKS_ELEMENT is given, also transfer mark sources
# from that element.
sub _merge_text {
  my ($self, $current, $text, $transfer_marks_element) = @_;

  # paragraphs are only started in empty lines or in context brace
  # commands, if there is nothing in the current element, cannot
  # be in a case where a paragraph is started.
  # Also, elements without anything in them are only brace_container
  # or menu_entry_name, otherwise there is always some kind of element
  # leading added for leading spaces when the element is created
  if (!$current->{'contents'}) {
    my $new_element = { 'text' => $text, 'parent' => $current };
    _transfer_source_marks($transfer_marks_element, $new_element)
      if ($transfer_marks_element);
    $current->{'contents'} = [];
    push @{$current->{'contents'}}, $new_element;
    print STDERR "NEW TEXT (merge): $text|||\n"
                         if ($self->{'conf'}->{'DEBUG'});
    return $current;
  }

  my $last_element = $current->{'contents'}->[-1];

  my $paragraph;

  if ($text =~ /\S/) {
    my $leading_spaces;
    if ($text =~ /^(\s+)/) {
      $leading_spaces = $1;
    }
    if ($last_element->{'type'}) {
      my $last_elt_type = $last_element->{'type'};
      if ($leading_space_types{$last_elt_type}) {
        if ($leading_spaces) {
          print STDERR "MERGE_TEXT ADD leading empty |$leading_spaces|"
                    ." to $last_elt_type\n"
                         if ($self->{'conf'}->{'DEBUG'});

          $last_element->{'text'} .= $leading_spaces;
          $text =~ s/^(\s+)//;
        } elsif ($last_element->{'text'} eq '') {
          # empty special space.  Reuse it as normal text element.
          # This is different from calling do_abort_empty_line and
          # afterwards adding a new element if there are source marks:
          # we avoid an empty element being added by reusing.
          my $popped_element = _pop_element_from_contents($self, $current);
          delete $popped_element->{'type'};
          $popped_element->{'text'} = $text;
          if (_in_begin_paragraph($self, $current)) {
            $current = _begin_paragraph($self, $current);
          }
          # do not jump with a goto as in C, as it is not possible
          # in Perl to use a goto to go further than the calling scope
          _transfer_source_marks($transfer_marks_element, $popped_element)
            if ($transfer_marks_element);
          push @{$current->{'contents'}}, $popped_element;
          $popped_element->{'parent'} = $current;
          print STDERR "NEW TEXT (merge): $text|||\n"
                      if ($self->{'conf'}->{'DEBUG'});
          return $current;
        }

        # following is similar to _abort_empty_line, except
        # for the empty text already handled above, and with
        # paragraph opening mixed in
        if ($last_elt_type eq 'internal_spaces_after_command'
            or $last_elt_type eq 'internal_spaces_before_argument') {
          _move_last_space_to_element($self, $current);
          # we do not merge these special types
          $last_element = undef;
        } elsif ($last_elt_type eq 'empty_line') {
          if (_in_begin_paragraph($self, $current)) {
            $last_element->{'type'} = 'spaces_before_paragraph';
            $paragraph = _begin_paragraph($self, $current);
            $current = $paragraph;
          } else {
            # in that case, we can merge
            delete $last_element->{'type'};
          }
        } else {
          # other special spaces, in general in paragraph begin context
          if ($last_elt_type eq 'internal_spaces_before_context_argument') {
            _move_last_space_to_element($self, $current);
          }
          if (_in_begin_paragraph($self, $current)) {
            $current = _begin_paragraph($self, $current);
          }
          # we do not merge these special types
          $last_element = undef;
        }
      }
    } else {
      if (_in_begin_paragraph($self, $current)) {
        $paragraph = _begin_paragraph($self, $current);
        $current = $paragraph;
      }
    }
  }

  # if a paragraph was started we know that there is no leading
  # text to merge with
  if (!$paragraph
      and $last_element
      and exists($last_element->{'text'})
      and $last_element->{'text'} !~ /\n/) {
    # Transfer source marks
    if ($transfer_marks_element
        and $transfer_marks_element->{'source_marks'}) {
      my $additional_length = length($current->{'contents'}->[-1]->{'text'});
      foreach my $source_mark (@{$transfer_marks_element->{'source_marks'}}) {
        $source_mark->{'position'} += $additional_length;
      }
      _transfer_source_marks($transfer_marks_element, $last_element);
    }
    # Append text
    print STDERR "MERGED TEXT: $text||| in "
      .Texinfo::Common::debug_print_element($last_element)
      ." last of ".Texinfo::Common::debug_print_element($current)."\n"
         if ($self->{'conf'}->{'DEBUG'});
    $last_element->{'text'} .= $text;
  } else {
    my $new_element = { 'text' => $text, 'parent' => $current };
    _transfer_source_marks($transfer_marks_element, $new_element)
      if ($transfer_marks_element);
    if (!defined($current->{'contents'})) {
      $current->{'contents'} = [];
    }
    push @{$current->{'contents'}}, $new_element;
    print STDERR "NEW TEXT (merge): $text|||\n"
                         if ($self->{'conf'}->{'DEBUG'});
  }
  return $current;
}

# return the parent if in a item_container command, itemize or enumerate
sub _item_container_parent($)
{
  my $current = shift;
  if ((($current->{'cmdname'} and $current->{'cmdname'} eq 'item')
       or ($current->{'type'} and $current->{'type'} eq 'before_item'))
      and ($current->{'parent'} and $current->{'parent'}->{'cmdname'}
           and $block_commands{$current->{'parent'}->{'cmdname'}}
           and $block_commands{$current->{'parent'}->{'cmdname'}} eq 'item_container')) {
    return ($current->{'parent'});
  }
  return undef;
}

# return the parent if in a item_line command, @*table
sub _item_line_parent($)
{
  my $current = shift;
  if ($current->{'type'} and $current->{'type'} eq 'before_item'
            and $current->{'parent'}) {
    $current = $current->{'parent'};
  }
  return $current if ($current->{'cmdname'}
                      and $block_commands{$current->{'cmdname'}}
                      and $block_commands{$current->{'cmdname'}} eq 'item_line');
  return undef;
}

# return the parent if in a multitable
sub _item_multitable_parent($)
{
  my $current = shift;
  if (($current->{'cmdname'} and ($current->{'cmdname'} eq 'headitem'
       or $current->{'cmdname'} eq 'item' or $current->{'cmdname'} eq 'tab'))
      and $current->{'parent'} and $current->{'parent'}->{'parent'}) {
    $current = $current->{'parent'}->{'parent'};
  } elsif ($current->{'type'} and $current->{'type'} eq 'before_item'
            and $current->{'parent'}) {
    $current = $current->{'parent'};
  }
  return $current if ($current->{'cmdname'}
                      and $current->{'cmdname'} eq 'multitable');
  return undef;
}

sub _encode_file_name($$)
{
  my ($self, $file_name) = @_;

  my $encoding;
  my $input_file_name_encoding = $self->{'conf'}->{'INPUT_FILE_NAME_ENCODING'};
  if ($input_file_name_encoding) {
    $encoding = $input_file_name_encoding;
  } elsif ($self->{'conf'}->{'DOC_ENCODING_FOR_INPUT_FILE_NAME'}) {
    $encoding = $self->{'input_file_encoding'};
  } else {
    $encoding = $self->{'conf'}->{'LOCALE_ENCODING'};
  }

  return Texinfo::Common::encode_file_name($file_name, $encoding);
}

sub _save_line_directive
{
  my ($self, $line_nr, $file_name) = @_;

  my $input = $self->{'input'}->[0];
  return if !$input;
  $input->{'input_source_info'}->{'line_nr'} = $line_nr if $line_nr;
  # need to convert to bytes for file name
  if (defined($file_name)) {
    my ($encoded_file_name, $file_name_encoding)
       = _encode_file_name($self, $file_name);
    $input->{'input_source_info'}->{'file_name'} = $encoded_file_name;
  }
}

# returns next text fragment with source information, be it
# pending from a macro expansion or pending text, or read from file.
# $CURRENT is the current container that can be used for source marks.
sub _next_text($;$)
{
  my ($self, $current) = @_;

  while (1) {
    my $input = $self->{'input'}->[0];
    if (exists($input->{'th'})) {
      my $texthandle = $input->{'th'};
      my $next_line = <$texthandle>;
      if (defined($next_line)) {
        # need to decode to characters
        $next_line = Encode::decode('utf-8', $next_line);
        $input->{'input_source_info'}->{'line_nr'} += 1
          unless (defined($input->{'input_source_info'}->{'macro'})
                  or defined($input->{'value_flag'}));
        return ($next_line, { %{$input->{'input_source_info'}} });
      }
    } elsif ($input->{'fh'}) {
      my $fh = $input->{'fh'};
      my $input_line = <$fh>;
      # Encode::decode tends to consume the input line, so duplicate it
      my $duplicate_input_line = $input_line;
      # Encode::encode with default check argument does not give a
      # warning on incorrect output, contrary to what the documentation says.
      # This has been seen on perl 5.10.1 and 5.36.0.
      # So we call it with FB_CROAK in an eval to get the message first
      # before calling it again to get the result.
      # This suits us as we try to output the same message as the XS parser
      eval { Encode::decode($input->{'file_input_encoding'},
                            $duplicate_input_line, Encode::FB_CROAK); };
      if ($@) {
        # determine the first problematic byte to show it in the error
        # message, like the XS parser
        $duplicate_input_line = $input_line;
        my $partially_decoded = Encode::decode($input->{'file_input_encoding'},
                                      $duplicate_input_line, Encode::FB_QUIET);
        my $error_byte = substr($duplicate_input_line, 0, 1);
        my $file_name;
        if (defined($input->{'input_source_info'}->{'file_name'})) {
          $file_name = $input->{'input_source_info'}->{'file_name'};
        } else {
          $file_name = '';
        }
        warn("${file_name}:"
            . ($input->{'input_source_info'}->{'line_nr'} + 1).
               sprintf(": encoding error at byte 0x%2x\n", ord($error_byte)));
        # show perl message but only with debugging
        print STDERR "input error: $@\n" if ($self->{'conf'}->{'DEBUG'});
      }
      # do the decoding
      my $line = Encode::decode($input->{'file_input_encoding'}, $input_line);
      if (defined($line)) {
        # add an end of line if there is none at the end of file
        if (eof($fh) and $line !~ /\n/) {
          $line .= "\n";
        }
        # DEL as comment character
        if ($line =~ s/\x{7F}(.*\s*)//) {
          # push empty text to place a source mark
          _input_push_text($self, '',
                           $input->{'input_source_info'}->{'line_nr'});
          my $delcomment_source_mark = {'sourcemark_type' => 'delcomment'};
          $delcomment_source_mark->{'line'} = $1 if ($1 ne '');
          $self->{'input'}->[0]->{'input_source_mark'}
             = $delcomment_source_mark;
        }
        $input->{'input_source_info'}->{'line_nr'}++;
        return ($line, { %{$input->{'input_source_info'}} });
      }
    } else {
      # At the end of the input, when some text is demanded, for instance
      # to get new input in case an @include added more input, but there
      # is nothing, we get here.  Also macro arguments ending on the last
      # line will lead to the consumption of the last text, then macro
      # expansion can readd more text, and the end of input will be reached
      # again.  With numerous macros expansions on the last line, this
      # place can be reached more than twice.
      $input->{'after_end_fetch_nr'}++;
      if ($self->{'conf'}->{'DEBUG'} and $input->{'after_end_fetch_nr'} > 1) {
        print STDERR "AFTER END FETCHED INPUT NR: "
                         .$input->{'after_end_fetch_nr'}."\n";
      }
    }
    # Top input source failed.  Close, pop, and try the next one.
    if (exists($input->{'th'})) {
      # End of text reached.
      if (!close($input->{'th'})) {
        my $error_message = $!;
        warn "BUG? close text reference failed: $error_message\n";
      }
      delete $input->{'th'};
      if (defined($input->{'value_flag'})) {
        $self->{'value_expansion_nr'}--;
      } elsif (defined($input->{'macro_name'})) {
        $self->{'macro_expansion_nr'}--;
      }
    } elsif ($input->{'fh'}) {
      # Don't close STDIN
      if ($input->{'input_source_info'}->{'file_name'} ne '-') {
        if (!close($input->{'fh'})) {
          # decode for the message, to have character strings in perl
          # that will be encoded on output to the locale encoding.
          # Done differently for the file names in source_info
          # which are byte strings and end up unmodified in output error
          # messages.
          my $file_name_encoding;
          # FIXME 'file_name_encoding' should always be defined, as
          # it comes from 'input_file_encoding' which is always
          # defined, possibly to the default value, so the following
          # condition should always be true.
          if (defined($input->{'file_name_encoding'})) {
            $file_name_encoding = $input->{'file_name_encoding'};
          } else {
            $file_name_encoding = $self->{'conf'}->{'COMMAND_LINE_ENCODING'};
          }
          my $decoded_file_name = $input->{'input_file_path'};
          if (defined($file_name_encoding)) {
            $decoded_file_name = decode($file_name_encoding,
                                        $input->{'input_file_path'});
          }
          $self->{'document'}->{'parser_registrar'}->document_warn(
                               sprintf(__("error on closing %s: %s"),
                                       $decoded_file_name, $!),
                                    $self->{'conf'}->{'PROGRAM'});
        }
      }
      delete $input->{'fh'};
    }

    if (defined($input->{'input_source_mark'})) {
      if (defined($current)) {
        my $end_source_mark;
        if ($input->{'input_source_mark'}->{'sourcemark_type'} eq 'delcomment') {
          $end_source_mark = $input->{'input_source_mark'};
        } else {
          $end_source_mark
            = { 'sourcemark_type' =>
                 $input->{'input_source_mark'}->{'sourcemark_type'},
                'counter' =>
                 $input->{'input_source_mark'}->{'counter'},
              };
          $end_source_mark->{'status'} = 'end';
        }
        _register_source_mark($self, $current,
                              $end_source_mark);
      } else {
        if ($self->{'conf'}->{'DEBUG'}) {
          print STDERR "INPUT MARK MISSED: "
            ._debug_show_source_mark($input->{'input_source_mark'})."\n";
          cluck();
        }
      }
      delete $input->{'input_source_mark'};
    }
    # keep the first input level to have a permanent source for
    # source_info, even when nothing is returned and the first input
    # file is closed.
    if (scalar(@{$self->{'input'}}) == 1) {
      print STDERR "INPUT FINISHED\n" if ($self->{'conf'}->{'DEBUG'});
      $input->{'after_end_fetch_nr'} = 0
         if (!defined($input->{'after_end_fetch_nr'}));
      return (undef, { %{$input->{'input_source_info'}} });
    } else {
      shift @{$self->{'input'}};
    }
  }
}

# collect text and line numbers until an end of line is found.
sub _new_line($;$)
{
  my ($self, $current) = @_;

  my $new_line = '';
  my $source_info;

  while (1) {
    my $new_text;
    ($new_text, $source_info) = _next_text($self, $current);
    if (!defined($new_text)) {
      $new_line = undef if ($new_line eq '');
      last;
    }

    $new_line .= $new_text;

    my $chomped_text = $new_text;
    last if chomp($chomped_text);
  }
  return ($new_line, $source_info);
}

# $MACRO is the element in the tree defining the macro.
sub _expand_macro_arguments($$$$$)
{
  my ($self, $macro, $line, $source_info, $current) = @_;

  my $braces_level = 1;

  my $argument = {'type' => 'brace_arg',
                  'contents' => [],
                  'parent' => $current};
  push @{$current->{'args'}}, $argument;
  my $argument_content = {'text' => '',
                          'parent' => $argument};
  push @{$argument->{'contents'}}, $argument_content;

  my $args_total = scalar(@{$macro->{'args'}}) -1;
  my $name = $macro->{'args'}->[0]->{'text'};

  my $source_info_orig = $source_info;

  $line =~ s/^{(\s*)//;
  if ($1 ne '') {
    $argument->{'info'} = {} if (!$argument->{'info'});
    $argument->{'info'}->{'spaces_before_argument'} = {'text' => $1};
  }

  while (1) {
    if ($line =~ s/([^\\{},]*)([\\{},])//) {
      my $separator = $2;
      $argument_content->{'text'} .= $1;
      if ($separator eq '\\') {
        if ($line =~ s/^(.)//) {
          my $protected_char = $1;
          if ($protected_char !~ /[\\{},]/) {
            $argument_content->{'text'} .= '\\';
          }
          $argument_content->{'text'} .= $protected_char;
          if ($protected_char eq ',') {
            $self->_line_warn(sprintf(
                __("use %s instead of %s in macro arg"), '@comma{}', '\\,'),
              $source_info);
          }
        } else {
          $argument_content->{'text'} .= '\\';
        }
      } elsif ($separator eq ',') {
        if ($braces_level > 1) {
          $argument_content->{'text'} .= $separator;
        } else {
          if (scalar(@{$current->{'args'}}) < $args_total) {
            _remove_empty_content($self, $argument);

            $argument = {'type' => 'brace_arg',
                         'contents' => [],
                         'parent' => $current};
            push @{$current->{'args'}}, $argument;
            $argument_content = {'text' => '',
                                 'parent' => $argument};
            push @{$argument->{'contents'}}, $argument_content;
            $line =~ s/^(\s*)//;
            if ($1 ne '') {
              $argument->{'info'}
                = {'spaces_before_argument' => {'text' => $1}};
            }
            print STDERR "MACRO NEW ARG\n" if ($self->{'conf'}->{'DEBUG'});
          } else {
            # implicit quoting when there is one argument.
            if ($args_total != 1) {
              $self->_line_error(sprintf(__(
                                     "macro `%s' called with too many args"),
                                        $name), $source_info);
            }
            $argument_content->{'text'} .= $separator;
          }
        }
      } elsif ($separator eq '}') {
        $braces_level--;
        if ($braces_level == 0) {
          _remove_empty_content($self, $argument);
          last;
        }
        $argument_content->{'text'} .= $separator;
      } elsif ($separator eq '{') {
        $braces_level++;
        $argument_content->{'text'} .= $separator;
      }
    } else {
      print STDERR "MACRO ARG end of line\n" if ($self->{'conf'}->{'DEBUG'});
      $argument_content->{'text'} .= $line;

      ($line, $source_info) = _new_line($self, $argument);
      if (!defined($line)) {
        $self->_line_error(sprintf(__("\@%s missing closing brace"),
           $name), $source_info_orig);
        _remove_empty_content($self, $argument);
        return ("\n", $source_info);
      }
    }
  }
  if ($args_total == 0
      and (scalar(@{$current->{'args'}} > 1)
           or $current->{'args'}->[0]->{'contents'})) {
    $self->_line_error(sprintf(__(
               "macro `%s' declared without argument called with an argument"),
                                $name), $source_info);
  }
  print STDERR "END MACRO ARGS EXPANSION\n" if ($self->{'conf'}->{'DEBUG'});
  return ($line, $source_info);
}

sub _expand_linemacro_arguments($$$$$)
{
  my ($self, $macro, $line, $source_info, $current) = @_;

  my $braces_level = 0;
  my $argument = {'type' => 'line_arg',
                  'contents' => [],
                  'parent' => $current};
  push @{$current->{'args'}}, $argument;
  my $argument_content = {'text' => '',
                          'parent' => $argument};
  push @{$argument->{'contents'}}, $argument_content;
  # based on whitespace_chars_except_newline in XS parser
  if ($line =~ s/^([ \t\cK\f]+)//) {
    $current->{'info'} = {} if (!$current->{'info'});
    $current->{'info'}->{'spaces_before_argument'} = {'text' => $1};
  }
  my $args_total = scalar(@{$macro->{'args'}}) -1;
  my $name = $macro->{'args'}->[0]->{'text'};

  while (1) {
    # spaces based on whitespace_chars_except_newline in XS parser
    if ($line =~ s/([^{}\@ \t\cK\f]*)([{}\@]|[ \t\cK\f]+)//) {
      my $separator = $2;
      $argument_content->{'text'} .= $1;
      if ($separator eq '@') {
        my ($cmdname, $is_single_letter) = _parse_command_name($line);
        if (defined($cmdname)) {
          # a comment is not part of the arguments
          if ($braces_level <= 0
              and ($cmdname eq 'c' or $cmdname eq 'comment')) {
            $line = $separator.$line;
            last;
          }
          $argument_content->{'text'} .= '@';
          $argument_content->{'text'} .= $cmdname;
          substr($line, 0, length($cmdname)) = '';
          if ((defined($self->{'brace_commands'}->{$cmdname})
               and $self->{'conf'}->{'IGNORE_SPACE_AFTER_BRACED_COMMAND_NAME'})
              or $accent_commands{$cmdname}) {
            $line =~ s/^(\s*)//;
            $argument_content->{'text'} .= $1;
          }
        } else {
          $argument_content->{'text'} .= '@';
        }
      } elsif ($separator eq '}') {
        $braces_level--;
        $argument_content->{'text'} .= $separator;
        if ($braces_level == 0) {
          if (! $argument_content->{'extra'}) {
            $argument_content->{'extra'} = {'toplevel_braces_nr' => 0};
          }
          $argument_content->{'extra'}->{'toplevel_braces_nr'}++;
        }
      } elsif ($separator eq '{') {
        $braces_level++;
        $argument_content->{'text'} .= $separator;
      # spaces
      } else {
        if ($braces_level > 0
            or scalar(@{$current->{'args'}}) >= $args_total) {
          $argument_content->{'text'} .= $separator;
        } else {
          $argument = {'type' => 'line_arg',
                       'contents' => [],
                       'parent' => $current};
          push @{$current->{'args'}}, $argument;
          $argument_content = {'text' => '',
                               'parent' => $argument};
          push @{$argument->{'contents'}}, $argument_content;
          $argument->{'info'}
            = {'spaces_before_argument' => {'text' => $separator}};
          print STDERR "LINEMACRO NEW ARG\n" if ($self->{'conf'}->{'DEBUG'});
        }
      }
    } else {
      print STDERR "LINEMACRO ARGS no separator $braces_level '"
              ._debug_protect_eol($line)."'\n" if ($self->{'conf'}->{'DEBUG'});
      if ($braces_level > 0) {
        $argument_content->{'text'} .= $line;

        ($line, $source_info) = _new_line($self, $argument);
        if (!defined($line)) {
          $self->_line_error(sprintf(__("\@%s missing closing brace"),
             $name), $source_info);
          $line = '';
          last;
        }
      } else {
        $line =~ s/(.*)//;
        $argument_content->{'text'} .= $1;
        if ($line =~ /\n/) {
          # end of macro call with an end of line
          last;
        } else {
          # happens when @ protects the end of line, at the very end
          # of a text fragment and probably with macro expansion
          ($line, $source_info) = _new_line($self, $argument);
          if (!defined($line)) {
            print STDERR "LINEMACRO ARGS end no EOL\n"
               if ($self->{'conf'}->{'DEBUG'});
            $line = '';
            last;
          }
        }
      }
    }
  }
  my $arg_idx = 0;
  foreach my $argument (@{$current->{'args'}}) {
    my $argument_content = $argument->{'contents'}->[0];
    if ($argument_content->{'extra'}
        and defined($argument_content->{'extra'}->{'toplevel_braces_nr'})) {
      my $toplevel_braces_nr = $argument_content->{'extra'}->{'toplevel_braces_nr'};
      delete $argument_content->{'extra'};
      # this is not the same as bracketed_arg type, as bracketed_arg type
      # is a container that contains other elements.  The
      # bracketed_linemacro_arg contains text directly.  In
      # bracketed_linemacro_arg, source mark locations are relative to the
      # beginning of the string with an opening brace prepended.
      if ($toplevel_braces_nr == 1 and $argument_content->{'text'} =~ /^\{(.*)\}$/s) {
        print STDERR "TURN to bracketed $arg_idx "
          .Texinfo::Common::debug_print_element($argument_content)."\n"
            if ($self->{'conf'}->{'DEBUG'});
        $argument_content->{'text'} = $1;
        $argument_content->{'type'} = 'bracketed_linemacro_arg';
      # this message could be added to see all the arguments
      #} else {
      #  print STDERR "NOT bracketed with bracket $arg_idx "
      #    .Texinfo::Common::debug_print_element($argument_content)."\n"
      #      if ($self->{'conf'}->{'DEBUG'});
      }
    # this message could be added to see all the arguments
    #} else {
    #  print STDERR "LVL0 no brace $arg_idx "
    #     .Texinfo::Common::debug_print_element($argument_content)."\n"
    #        if ($self->{'conf'}->{'DEBUG'});
    }
    $arg_idx++;
  }
  print STDERR "END LINEMACRO ARGS EXPANSION\n" if ($self->{'conf'}->{'DEBUG'});
  return ($line, $source_info);
}

sub _lookup_macro_parameter($$) {
  my $macro = shift;
  my $name = shift;

  my $args_total = scalar(@{$macro->{'element'}->{'args'}}) -1;
  if ($args_total > 0) {
    my $arg_index;
    # the first argument is the macro name
    for ($arg_index=1; $arg_index<=$args_total; $arg_index++) {
      if (defined($macro->{'element'}->{'args'}->[$arg_index])
          and $macro->{'element'}->{'args'}->[$arg_index]->{'text'} eq $name) {
        return $arg_index - 1;
      }
    }
  }
  return undef
}

# $MACRO is a member of $self->{'macros'}.
sub _expand_macro_body($$$$) {
  my ($self, $macro, $args, $source_info) = @_;

  my $macrobody = $macro->{'macrobody'};

  return undef if (!defined($macrobody));

  my $result = '';
  while ($macrobody ne '') {
    if ($macrobody =~ s/^([^\\]*)\\//) {
      $result .= $1;
      if ($macrobody =~ s/^\\//) {
        $result .= '\\';
      } elsif ($macrobody =~ s/^([^\\]*)\\//) {
        my $arg = $1;
        my $formal_arg_index = _lookup_macro_parameter($macro, $arg);
        if (defined($formal_arg_index)) {
          if ($formal_arg_index < scalar(@$args)
              and scalar(@$args) and $args->[$formal_arg_index]
              and $args->[$formal_arg_index]->{'contents'}) {
            $result .= $args->[$formal_arg_index]->{'contents'}->[0]->{'text'};
          }
        } else {
          $self->_line_error(sprintf(__(
         "\\ in \@%s expansion followed `%s' instead of parameter name or \\"),
             $macro->{'element'}->{'args'}->[0]->{'text'}, $arg), $source_info);
          $result .= '\\' . $arg;
        }
      } else {
        # unpaired backslash
        last;
      }
    } else {
      # End of body.
      last;
    }
  }
  $result .= $macrobody;
  return $result;
}

# turn spaces that are ignored before @-commands like @sortas{} and
# @seeentry{} back to regular spaces if there is content after the @-command
sub _set_non_ignored_space_in_index_before_command($)
{
  my $content = shift;
  my $pending_spaces_element = 0;
  foreach my $element (@{$content->{'contents'}}) {
    if ($element->{'type'}
        and $element->{'type'} eq 'internal_spaces_before_brace_in_index') {
      # set to "spaces_at_end" in case there are only spaces after
      $element->{'type'} = 'spaces_at_end';
      $pending_spaces_element = $element;
    } elsif ($pending_spaces_element
             and not (($element->{'cmdname'}
                       and $in_index_commands{$element->{'cmdname'}}
                       and defined($brace_commands{$element->{'cmdname'}}))
                      or ($element->{'type'}
                   and $element->{'type'} eq 'spaces_after_close_brace'))
             and (! _check_empty_expansion([$element]))) {
      delete $pending_spaces_element->{'type'};
      $pending_spaces_element = 0;
    }
  }
}

sub _pop_element_from_contents($$)
{
  my $self = shift;
  my $parent_element = shift;

  my $popped_element = pop @{$parent_element->{'contents'}};
  delete $parent_element->{'contents'}
    if (scalar(@{$parent_element->{'contents'}}) == 0);

  return $popped_element;
}

sub _move_last_space_to_element($$) {
  my ($self, $current) = @_;

  # Remove element from main tree. It will still be referenced in
  # the 'info' hash as 'spaces_before_argument'.
  my $spaces_before_argument = _pop_element_from_contents($self, $current);
  delete $spaces_before_argument->{'type'};
  delete $spaces_before_argument->{'parent'};
  my $owning_element = $self->{'internal_space_holder'};
  $owning_element->{'info'} = {} if (!exists($owning_element->{'info'}));
  $owning_element->{'info'}->{'spaces_before_argument'}
    = $spaces_before_argument;
  $self->{'internal_space_holder'} = undef;
}

# each time a new line appeared, a container is opened to hold the text
# consisting only of spaces.  This container is removed here, typically
# this is called when non-space happens on a line.
sub _abort_empty_line($$) {
  my ($self, $current) = @_;

  if ($current->{'contents'}) {
    my $last_element = $current->{'contents'}->[-1];
    if ($last_element->{'type'}) {
      my $type = $last_element->{'type'};
      if ($leading_space_types{$type}) {
        if ($self->{'conf'}->{'DEBUG'}) {
          print STDERR "ABORT EMPTY in "
             .Texinfo::Common::debug_print_element($current)
              .": $type; |$last_element->{'text'}|\n";
        }

        # remove empty 'empty*before'.  Happens in many situations.
        if ($last_element->{'text'} eq '') {
          my $popped_element = _pop_element_from_contents($self, $current);
          # if first in parent and with source mark, placing a source mark
          # should lead to readding an element for the source mark.  In that
          # case, the type is not readded, such that it is actually relatively
          # similar to the case of an empty line just below, except that an empty
          # text string is left.
          #
          # Note that an empty text string first in parent does not happen often,
          # as it cannot happen in paragraph, as there is some command or text that
          # started the paragraph before, and being first in the main text out of
          # paragraph does not happen often either.  The situation in which it
          # happens is a macro expansion to an empty string right after an
          # @-command opening (block or brace command).
          foreach my $source_mark (@{$popped_element->{'source_marks'}}) {
            _place_source_mark($self, $current, $source_mark);
          }
          delete $popped_element->{'source_marks'};
        } elsif ($type eq 'empty_line') {
          # exactly the same condition as to begin a paragraph
          if ($begin_paragraph_contexts{$self->_top_context()}
              and not ($current->{'type'}
                      and $type_without_paragraph{$current->{'type'}})) {
            $last_element->{'type'} = 'spaces_before_paragraph';
          } else {
            delete $last_element->{'type'};
          }
        } elsif ($type eq 'internal_spaces_after_command'
                 or $type eq 'internal_spaces_before_argument'
                 or $type eq 'internal_spaces_before_context_argument') {
          _move_last_space_to_element($self, $current);
        }
      }
    }
  }
}

sub _isolate_trailing_spaces_element($)
{
  my $element = shift;
  my $new_space_element;

  if ($element->{'text'} =~ s/(\s+)$//) {
    $new_space_element = {'text' => $1};
    if ($element->{'source_marks'}) {
      my $current_position = length($element->{'text'});
      Texinfo::Common::relocate_source_marks(
                          $element->{'source_marks'}, $new_space_element,
                          $current_position, length($1));
      delete $element->{'source_marks'}
        if (!scalar(@{$element->{'source_marks'}}));
    }
  }
  return $new_space_element;
}

sub _isolate_trailing_space($$)
{
  my $current = shift;
  my $spaces_type = shift;

  if ($current->{'contents'}) {
    my $last_element = $current->{'contents'}->[-1];
    if (defined($last_element->{'text'})
        and $last_element->{'text'} ne '') {
      if ($last_element->{'text'} !~ /\S/) {
        $last_element->{'type'} = $spaces_type;
      } else {
        my $new_space_element = _isolate_trailing_spaces_element($last_element);
        if ($new_space_element) {
          $new_space_element->{'type'} = $spaces_type;
          $new_space_element->{'parent'} = $current;
          push @{$current->{'contents'}}, $new_space_element;
        }
      }
    }
  }
}

# isolate last space in a command to help expansion disregard unuseful spaces.
sub _isolate_last_space
{
  my ($self, $current) = @_;

  return if (!$current->{'contents'});

  # $current->{'type'} is always set, to line_arg, block_line_arg,
  # brace_container, brace_arg, bracketed_arg or menu_entry_node

  # Store a final comment command in the 'info' hash, except for brace
  # commands
  if (not ($current->{'type'}
           and ($current->{'type'} eq 'brace_container'
                or $current->{'type'} eq 'brace_arg'))
      and scalar(@{$current->{'contents'}}) >= 1
      and $current->{'contents'}->[-1]->{'cmdname'}
      and ($current->{'contents'}->[-1]->{'cmdname'} eq 'c'
            or $current->{'contents'}->[-1]->{'cmdname'} eq 'comment')) {
    $current->{'info'} = {} if (!$current->{'info'});
    $current->{'info'}->{'comment_at_end'}
                           = _pop_element_from_contents($self, $current);
    # TODO @c should probably not be allowed inside most brace commands
    # as this would be difficult to implement properly in TeX.
  }

  my $debug_str;
  if ($self->{'conf'}->{'DEBUG'}) {
    $debug_str = 'p '.Texinfo::Common::debug_print_element($current).'; c ';
    if ($current->{'contents'}) {
      $debug_str .=
         Texinfo::Common::debug_print_element($current->{'contents'}->[-1]);
    }
  }

  if ($current->{'contents'}) {
    my $last_element = $current->{'contents'}->[-1];
    if (defined($last_element->{'text'})
        and $last_element->{'text'} ne '') {
      # Store final spaces in 'spaces_after_argument'.
      if ($last_element->{'text'} !~ /\S/) {
        my $spaces_after_argument = _pop_element_from_contents($self, $current);
        delete $spaces_after_argument->{'parent'};
        delete $spaces_after_argument->{'type'};
        $current->{'info'} = {} if (!exists($current->{'info'}));
        $current->{'info'}->{'spaces_after_argument'}
               = $spaces_after_argument;
      } else {
        my $new_space_element = _isolate_trailing_spaces_element($last_element);
        if ($new_space_element) {
          $current->{'info'} = {} if (!exists($current->{'info'}));
          $current->{'info'}->{'spaces_after_argument'} = $new_space_element;
        } else {
          print STDERR "NOT ISOLATING $debug_str\n"
            if ($self->{'conf'}->{'DEBUG'});
          return;
        }
      }
      print STDERR "ISOLATE SPACE $debug_str\n"
        if ($self->{'conf'}->{'DEBUG'});
      return;
    }
  }

  print STDERR "NOT ISOLATING $debug_str\n"
     if ($self->{'conf'}->{'DEBUG'});
}

# split non-space text elements into strings without [ ] ( ) , and single
# character strings with one of them
sub _split_delimiters
{
  my ($self, $root, $current, $source_info) = @_;

  if ($root->{'type'}
      and ($root->{'type'} eq 'spaces' or $root->{'type'} eq 'bracketed_arg')) {
    return $root;
  } elsif (!defined($root->{'text'})) {
    my $new = {'type' => 'def_line_arg', 'parent' => $current,
               'contents' => [$root]};
    $root->{'parent'} = $current;
    return $new;
  } else {
    my @elements;
    my $type;
    my $chars = quotemeta '[](),';
    my $text = $root->{'text'};
    my $remaining_source_marks;
    my $current_position = 0;
    if ($root->{'source_marks'}) {
      $remaining_source_marks = [@{$root->{'source_marks'}}];
      delete $root->{'source_marks'};
    }
    while (1) {
      if ($text =~ s/^([^$chars]+)//) {
        my $new = {'type' => 'def_line_arg', 'parent' => $root->{'parent'}};
        $new->{'contents'} = [{'text' => $1, 'parent' => $new}];
        push @elements, $new;
        $current_position = Texinfo::Common::relocate_source_marks(
                              $remaining_source_marks, $new->{'contents'}->[0],
                              $current_position, length($1));
      } elsif ($text =~ s/^([$chars])//) {
        push @elements, {'text' => $1, 'type' => 'delimiter',
                         'parent' => $root->{'parent'}};
        $current_position = Texinfo::Common::relocate_source_marks(
                                 $remaining_source_marks, $elements[-1],
                                 $current_position, length($1));
      } else {
        last;
      }
    }
    if ($remaining_source_marks and scalar(@$remaining_source_marks)) {
      my $source_marks_str
       = join ('|', map {_debug_show_source_mark($_)} (@$remaining_source_marks));
      $self->_bug_message(
          "Remaining source mark in _split_delimiters: $source_marks_str",
                          $source_info, $current);
    }
    return @elements;
  }
}

# split text elements into whitespace and non-whitespace
sub _split_def_args
{
  my ($self, $root, $current, $source_info) = @_;

  if ($root->{'type'} and $root->{'type'} eq 'spaces'
      and $root->{'info'} and $root->{'info'}->{'inserted'}) {
    return $root;
  } elsif (defined($root->{'text'})) {
    my @elements;
    my $type;
    # FIXME how to handle non ascii space?  As space or in argument?
    my @split_text = split /(?<=\s)(?=\S)|(?<=\S)(?=\s)/, $root->{'text'};
    if ($split_text[0] =~ /^\s*$/) {
      $type = 'spaces';
    }
    my $remaining_source_marks;
    my $current_position = 0;
    if ($root->{'source_marks'}) {
      $remaining_source_marks = [@{$root->{'source_marks'}}];
      $root->{'source_marks'} = undef;
    }
    foreach my $t (@split_text) {
      my $e = {'text' => $t };
      $current_position = Texinfo::Common::relocate_source_marks(
                               $remaining_source_marks, $e,
                               $current_position, length($t));
      if ($type) {
        $e->{'type'} = $type;
        $type = undef;
      } else {
        $type = 'spaces';
      }
      $e->{'parent'} = $root->{'parent'};
      push @elements, $e;
    }
    if ($remaining_source_marks and scalar(@$remaining_source_marks)) {
      my $source_marks_str
       = join ('|', map {_debug_show_source_mark($_)} @$remaining_source_marks);
      $self->_bug_message(
          "Remaining source mark in _split_def_args: $source_marks_str",
                          $source_info, $current);
    }
    return @elements;
  } elsif ($root->{'type'} and $root->{'type'} eq 'bracketed_arg') {
    _isolate_last_space($self, $root);
  }
  return $root;
}

# the index is set past the gathered or aggregated element.
sub _next_bracketed_or_word_agg($$)
{
  my $current = shift;
  my $index_ref = shift;

  my $num = 0;
  while (1) {
    if (!$current->{'contents'}
        or $$index_ref == scalar(@{$current->{'contents'}})) {
      last;
    }
    my $element = $current->{'contents'}->[$$index_ref];
    if ($element->{'type'} and ($element->{'type'} eq 'spaces'
                                or $element->{'type'} eq 'delimiter')) {
      last if ($num > 0);

      $$index_ref++;
    } else {
      # element is a text, a command element or a bracketed argument
      $$index_ref++;
      $num++;
    }
  }

  return undef if ($num == 0);

  if ($num == 1) {
    my $element = $current->{'contents'}->[$$index_ref -1];
    if ($element->{'type'} and ($element->{'type'} eq 'bracketed_arg'
                                or $element->{'type'} eq 'def_line_arg'
                       or $element->{'type'} eq 'untranslated_def_line_arg')) {
      # there is only one bracketed element
      return $element;
    }
  }
  my @gathered_contents
    = splice(@{$current->{'contents'}}, $$index_ref - $num, $num);
  my $new = {'type' => 'def_line_arg', 'parent' => $current,
             'contents' => \@gathered_contents};
  foreach my $content (@gathered_contents) {
    $content->{'parent'} = $new;
  }
  splice (@{$current->{'contents'}}, $$index_ref - $num, 0, ($new));
  $$index_ref = $$index_ref - $num + 1;
  return $new;
}

# definition line parsing
sub _parse_def($$$$)
{
  my ($self, $command, $current, $source_info) = @_;

  return {} if (!$current->{'contents'});
  my $contents = $current->{'contents'};

  my @new_contents;
  my @contents = @$contents;

  my @args;
  my $arg_type;
  my $arg_types_nr;

  my $inserted_category = 0;

  # could have used def_aliases, but use code more similar with the XS parser
  if ($def_alias_commands{$command}) {
    my $real_command = $def_aliases{$command};
    my $category;
    my $translation_context;
    my $category_translation_context = $def_map{$command}->{$real_command};
    # if the translation requires a context, $category_translation_context
    # is an array reference, otherwise it is a string.
    if (ref($category_translation_context) eq '') {
      $category = $category_translation_context;
    } else {
      ($translation_context, $category) = @$category_translation_context;
    }

    $inserted_category = 1;
    my $def_line_arg = {'type' => 'def_line_arg',
                        'parent' => $current};
    my $content = { 'text' => $category, 'parent' => $def_line_arg };
    # the category string is an english string (such as Function).  If
    # documentlanguage is set it needs to be translated during the conversion.
    if (defined($self->{'documentlanguage'})) {
      $def_line_arg->{'type'} = 'untranslated_def_line_arg';
      $content->{'type'} = 'untranslated';
      $def_line_arg->{'extra'}
         = {'documentlanguage' => $self->{'documentlanguage'}};
      if (defined($translation_context)) {
        $def_line_arg->{'extra'}->{'translation_context'}
          = $translation_context;
      }
    }
    @{$def_line_arg->{'contents'}} = ($content);

    unshift @contents, $def_line_arg,
                       { 'text' => ' ', 'type' => 'spaces',
                         'info' => {'inserted' => 1},
                         'parent' => $current,
                       };

    $command = $def_aliases{$command};
  }

  @args = @{$def_map{$command}};
  $arg_type = pop @args if ($args[-1] eq 'arg' or $args[-1] eq 'argtype');
  # If $arg_type is not set (for @def* commands that are not documented
  # to take args), everything happens as if arg_type was set to 'arg'.
  $arg_types_nr = scalar(@args);

  @contents = map (_split_def_args($self, $_, $current, $source_info),
                   @contents );
  @new_contents = @contents;

  $current->{'contents'} = \@new_contents;

  my %result;

  #  Fill in everything up to the args, collecting adjacent non-whitespace
  #  elements into a single element, e.g 'a@i{b}c'.
  my $i;
  my $contents_idx = 0;
  for ($i = 0; $i < $arg_types_nr; $i++) {
    my $element = _next_bracketed_or_word_agg($current, \$contents_idx);
    if ($element) {
      my $new_def_type = {'type' => 'def_'.$args[$i],
                          'parent' => $element->{'parent'}};
      $new_def_type->{'contents'} = [$element];
      $element->{'parent'} = $new_def_type;
      $current->{'contents'}->[$contents_idx - 1] = $new_def_type;

      $result{$args[$i]} = $new_def_type;
    } else {
      last;
    }
  }
  if ($inserted_category) {
    $current->{'contents'}->[0]->{'info'} = {'inserted' => 1};
  }

  my @args_results = map (_split_delimiters($self, $_, $current, $source_info),
                          splice(@{$current->{'contents'}}, $contents_idx,
                                 scalar(@{$current->{'contents'}}) - $contents_idx));

  my $set_type_not_arg = 1;
  # For some commands, alternate between "arg" and "typearg".
  # In that case $set_type_not_arg is both used to set to argtype and
  # to switch sign to switch between arg and argtype
  $set_type_not_arg = -1 if ($arg_type and $arg_type eq 'argtype');

  my $type = $set_type_not_arg;

  for (my $j = 0; $j < scalar(@args_results); $j++) {
    my $content = $args_results[$j];
    my $def_type;
    if ($content->{'type'} and $content->{'type'} eq 'spaces') {
    } elsif ($content->{'type'} and $content->{'type'} eq 'delimiter') {
      $type = $set_type_not_arg;
    } elsif ($content->{'type'} and $content->{'type'} eq 'def_line_arg'
             and $content->{'contents'}
             and scalar(@{$content->{'contents'}}) == 1
             and $content->{'contents'}->[0]->{'cmdname'}
             and $content->{'contents'}->[0]->{'cmdname'} ne 'code') {
      $def_type = 'def_arg';
      $type = $set_type_not_arg;
    } else {
      if ($type == 1) {
        $def_type = 'def_arg';
      } else {
        $def_type = 'def_typearg';
      }
      $type = $type * $set_type_not_arg;
    }
    if (defined($def_type)) {
      my $new_def_type = {'type' => $def_type,
                          'parent' => $content->{'parent'},};
      $new_def_type->{'contents'} = [$content];
      $content->{'parent'} = $new_def_type;
      $args_results[$j] = $new_def_type;
    }
  }
  push @{$current->{'contents'}}, @args_results;

  return \%result;
}

# store an index entry.
# $COMMAND_CONTAINER is the name of the @-command the index entry
# is associated with, for instance 'cindex', 'defivar' or 'vtable'.
# $ELEMENT is the element holding more directly the index entry.
# Can be the same as $COMMAND_CONTAINER, but also be different,
# for instance it is @item or @itemx for @vtable and defline type
# for @defivar.
sub _enter_index_entry($$$$)
{
  my ($self, $command_container, $element, $source_info) = @_;

  return if $self->{'conf'}->{'NO_INDEX'};

  my $document = $self->{'document'};

  my $index_name = $self->{'command_index'}->{$command_container};
  my $index = $document->{'indices'}->{$index_name};

  if (!defined($index->{'index_entries'})) {
    $index->{'index_entries'} = [];
  }

  my $number = scalar(@{$index->{'index_entries'}}) + 1;

  my $index_entry = { 'index_name'           => $index_name,
                      'entry_element'        => $element,
                      'entry_number'         => $number,
                    };

  $element->{'extra'} = {} if (!defined($element->{'extra'}));

  # gather set txiindex*ignore information
  foreach my $set_variable_and_symbol (@set_flag_index_char_ignore) {
    my ($set_variable, $ignored_char) = @{$set_variable_and_symbol};
    if (exists($self->{'values'}->{$set_variable})) {
      $element->{'extra'}->{'index_ignore_chars'} = ''
         if (!defined($element->{'extra'}->{'index_ignore_chars'}));
      $element->{'extra'}->{'index_ignore_chars'} .= $ignored_char;
    }
  }
  if (@{$self->{'nesting_context'}->{'regions_stack'}} > 0) {
    $element->{'extra'}->{'element_region'}
      = $self->{'nesting_context'}->{'regions_stack'}->[-1];
  } elsif ($self->{'current_node'}) {
    $element->{'extra'}->{'element_node'} = $self->{'current_node'};
  } elsif (!$self->{'current_section'}) {
    # NOTE depending on the location, format and presence of @printindex,
    # an index entry out of node and sections may be correctly formatted (or
    # rightfully ignored).  For example if there is no printindex and the index
    # formatting is done by texi2any for HTML or Info output, it does not matter
    # that the entry is outside of nodes, as it does not appear anywhere
    # anyway.  When outputting HTML, in most cases the content before the first
    # node or section is output, such that an index entry there is not
    # problematic either.  It could be possible to remove the warning from here
    # and warn only in the converters.  However, in some cases there won't be
    # any warning, for example when both the index entry and the printindex are
    # before @setfilename, while it is good to warn in that case.  Therefore
    # the warning here is kept -- at least until a relevant use case for
    # index entry outside of node and section is reported.
    $self->_line_warn(sprintf(__("entry for index `%s' outside of any node"),
                             $index_name), $source_info);
  }

  push @{$index->{'index_entries'}}, $index_entry;

  $element->{'extra'}->{'index_entry'} = [$index_name, $number];
}

sub _parse_float_type($)
{
  my $current = shift;

  my $normalized = '';
  if ($current->{'args'} and scalar(@{$current->{'args'}})) {
    $normalized
       = Texinfo::Convert::NodeNameNormalization::convert_to_normalized(
                                                  $current->{'args'}->[0]);
  }
  $current->{'extra'} = {} if (!$current->{'extra'});
  $current->{'extra'}->{'float_type'} = $normalized;
  return $normalized;
}

sub _in_include($)
{
  my $self = shift;

  foreach my $input (@{$self->{'input'}}[0..$#{$self->{'input'}}-1]) {
    if (not $input->{'th'}) {
      return 1;
    }
  }
  return 0;
}

# Convert the contents of $E to plain text.  Suitable for specifying a file
# name containing an at sign or braces, but no other commands nor element
# types.  Returns $SUPERFLUOUS_ARG if the $E contains other commands or element
# types.
sub _text_contents_to_plain_text {
  my $e = shift;

  my ($text, $superfluous_arg) = ('', 0);

  return ($text, $superfluous_arg)
    unless($e->{'contents'});

  for my $c (@{$e->{'contents'}}) {
    # Allow @@, @{ and @} to give a way for @, { and } to appear in
    # filenames (although it's not a good idea to use these characters
    # in filenames).
    if (defined($c->{'text'})) {
      $text .= $c->{'text'};
    } elsif ($c->{'cmdname'}
        and ($c->{'cmdname'} eq '@'
             or $c->{'cmdname'} eq 'atchar')) {
      $text .= '@';
    } elsif ($c->{'cmdname'}
        and ($c->{'cmdname'} eq '{'
             or $c->{'cmdname'} eq 'lbracechar')) {
      $text .= '{';
    } elsif ($c->{'cmdname'}
        and ($c->{'cmdname'} eq '}'
             or $c->{'cmdname'} eq 'rbracechar')) {
      $text .= '}';
    } else {
      $superfluous_arg = 1;
    }
  }
  return ($text, $superfluous_arg);
}

sub _end_line_misc_line($$$)
{
  my $self = shift;
  my $current = shift;
  my $source_info = shift;

  my $document = $self->{'document'};

  my $command = $current->{'parent'}->{'cmdname'};
  my $data_cmdname = $command;

  # we are in a command line context, so the @item command information is
  # associated to CM_item_LINE
  $data_cmdname = 'item_LINE' if ($command eq 'item');

  if ($self->{'basic_inline_commands'}
      and $self->{'basic_inline_commands'}->{$data_cmdname}) {
    pop @{$self->{'nesting_context'}->{'basic_inline_stack_on_line'}};
  }
  _isolate_last_space($self, $current);

  if ($current->{'parent'}->{'extra'}
      and $current->{'parent'}->{'extra'}->{'def_command'}) {
    $current = _end_line_def_line($self, $current, $source_info);
    return $current;
  }

  _pop_context($self, ['ct_line'], $source_info, $current, 'in line_arg');

  $current = $current->{'parent'};
  my $misc_cmd = $current;
  my $end_command;
  my $included_file;
  my $include_source_mark;

  my $arg_spec = $self->{'line_commands'}->{$data_cmdname};

  print STDERR "MISC END $command\n" #: $arg_spec"
    if ($self->{'conf'}->{'DEBUG'});

  if ($arg_spec eq 'specific') {
    my $args = _parse_line_command_args($self, $current, $source_info);
    if (defined($args)) {
      $current->{'extra'} = {} if (!defined($current->{'extra'}));
      $current->{'extra'}->{'misc_args'} = $args;
    }
  } elsif ($arg_spec eq 'text') {
    my ($text, $superfluous_arg)
      = _text_contents_to_plain_text($current->{'args'}->[0]);

    if ($text eq '') {
      if (not $superfluous_arg) {
        $self->_command_warn($current,
                             __("\@%s missing argument"), $command);
      }
      # if there is superfluous arg, a more suitable error is issued below.
    } else {
      $current->{'extra'} = {} if (!$current->{'extra'});
      $current->{'extra'}->{'text_arg'} = $text;
      if ($command eq 'end') {
        # REMACRO
        my $remaining_on_line = $text;
        if ($remaining_on_line =~ s/^([[:alnum:]][[:alnum:]-]*)//) {
          $end_command = $1;

          if (!exists $block_commands{$end_command}) {
            $self->_command_warn($current,
                                 __("unknown \@end %s"), $end_command);
            $end_command = undef;
          } else {
            print STDERR "END BLOCK \@end $end_command\n"
                                     if ($self->{'conf'}->{'DEBUG'});
          }
          # non-ASCII spaces are also superfluous arguments.
          # If there is superfluous text after @end argument, set
          # $superfluous_arg such that the error message triggered by an
          # unexpected @-command on the @end line is issued below.  Note
          # that $superfluous_arg may also be true if it was set above.
          if ($end_command and $remaining_on_line =~ /\S/) {
            $superfluous_arg = 1;
          }
        # if $superfluous_arg is set there is a similar and somewhat
        # better error message below
        } elsif (!$superfluous_arg) {
          $self->_command_error($current,
                            __("bad argument to \@%s: %s"),
                            $command, $remaining_on_line);
        }
      } elsif ($superfluous_arg) {
        # @-command effects are ignored, an error message is issued below.
      } elsif ($command eq 'include') {
        # We want Perl binary strings representing sequences of bytes,
        # not character strings in the internal perl encoding.
        my ($file_path, $file_name_encoding) = _encode_file_name($self, $text);
        my $included_file_path
             = Texinfo::Common::locate_include_file($file_path,
                                  $self->{'conf'}->{'INCLUDE_DIRECTORIES'});
        if (defined($included_file_path)) {
          my ($status, $file_name, $directories, $error_message)
             = _input_push_file($self, $included_file_path, $file_name_encoding);
          if ($status) {
            $included_file = 1;
            print STDERR "Included $included_file_path\n"
                                          if ($self->{'conf'}->{'DEBUG'});
            $include_source_mark = {'sourcemark_type' => $command,
                                    'status' => 'start'};
            $self->{'input'}->[0]->{'input_source_mark'} = $include_source_mark;
            push @{$document->{'global_info'}->{'included_files'}},
                 $included_file_path;
          } else {
            my $decoded_file_path
                = Encode::decode($file_name_encoding, $included_file_path);
            $self->_command_error($current,
                            __("\@%s: could not open %s: %s"),
                            $command, $decoded_file_path, $error_message);
          }
        } else {
          $self->_command_error($current,
                            __("\@%s: could not find %s"),
                           $command, $text);
        }
      } elsif ($command eq 'verbatiminclude') {
        $current->{'extra'}->{'input_encoding_name'}
               = $document->{'global_info'}->{'input_encoding_name'}
          if (defined($document->{'global_info'}->{'input_encoding_name'}));
        # gather included file for 'included_files'.  No errors, they
        # should be output by converters
        my ($file_path, $file_name_encoding) = _encode_file_name($self, $text);
        my $included_file_path
             = Texinfo::Common::locate_include_file($file_path,
                                     $self->{'conf'}->{'INCLUDE_DIRECTORIES'});
        if (defined($included_file_path) and -r $included_file_path) {
          push @{$document->{'global_info'}->{'included_files'}},
                                                  $included_file_path;
        }
      } elsif ($command eq 'documentencoding') {
        # lower case, trim non-ascii characters and keep only alphanumeric
        # characters, - and _.  iconv also seems to trim non alphanumeric
        # non - _ characters
        my $normalized_text = lc($text);
        $normalized_text =~ s/[^[:alnum:]_\-]//;

        if ($normalized_text !~ /[[:alnum:]]/) {
          $self->_command_warn($current,
                               __("bad encoding name `%s'"), $text);
        } else {
          # Warn if the encoding is not one of the encodings supported as an
          # argument to @documentencoding, documented in Texinfo manual
          unless ($canonical_texinfo_encodings{lc($text)}) {
            $self->_command_warn($current,
                     __("encoding `%s' is not a canonical texinfo encoding"),
                                 $text)
          }

          # Set $perl_encoding  -- an encoding name suitable for perl;
          #     $input_encoding -- for output within an HTML file, used
          #                        in most output formats
          my ($perl_encoding, $input_encoding);
          my $conversion_encoding = $normalized_text;
          if (defined($encoding_name_conversion_map{$normalized_text})) {
            $conversion_encoding
                = $encoding_name_conversion_map{$normalized_text};
          }
          my $Encode_encoding_object = find_encoding($conversion_encoding);
          if (defined($Encode_encoding_object)) {
            $perl_encoding = $Encode_encoding_object->name();
            if ($normalized_text ne $conversion_encoding) {
              $Encode_encoding_object = find_encoding($normalized_text);
            }
            # mime_name() is upper-case, our keys are lower case, set to lower case
            $input_encoding = lc($Encode_encoding_object->mime_name());
          }

          if (!$perl_encoding) {
            $self->_command_warn($current,
                 __("unhandled encoding name `%s'"), $text);
          } else {
            if ($input_encoding) {
              $document->{'global_info'}->{'input_encoding_name'} = $input_encoding;
              $current->{'extra'}->{'input_encoding_name'} = $input_encoding;
            }

            $self->{'input_file_encoding'} = $perl_encoding;
            foreach my $input (@{$self->{'input'}}) {
              if ($input->{'fh'}) {
                $input->{'file_input_encoding'} = $perl_encoding;
              }
            }
          }
        }
      } elsif ($command eq 'documentlanguage') {
        my @messages = Texinfo::Common::warn_unknown_language($text);
        foreach my $message(@messages) {
          $self->_command_warn($current, $message);
        }
        if (!$self->{'set'}->{'documentlanguage'}) {
          $self->{'documentlanguage'} = $text;
        }
      }
    }
    if ($superfluous_arg) {
      my $texi_line
        = Texinfo::Convert::Texinfo::convert_to_texinfo($current->{'args'}->[0]);
      $texi_line =~ s/^\s*//;
      $texi_line =~ s/\s*$//;

      $self->_command_error($current,
                     __("bad argument to \@%s: %s"),
                     $command, $texi_line);
    }
  } elsif ($command eq 'node') {
    for (my $i = 1; $i < scalar(@{$current->{'args'}}); $i++) {
      my $arg = $current->{'args'}->[$i];
      my $arg_label_manual_info
        = Texinfo::Common::parse_node_manual($arg, 1);
      if (defined($arg_label_manual_info)) {
        # 'node_content' 'manual_content'
        foreach my $label_info (keys(%$arg_label_manual_info)) {
          $arg->{'extra'} = {} if (!$arg->{'extra'});
          $arg->{'extra'}->{$label_info}
            = $arg_label_manual_info->{$label_info};
        }
        if ($arg->{'extra'}->{'node_content'}) {
          my $normalized
            = Texinfo::Convert::NodeNameNormalization::convert_to_identifier(
              $arg->{'extra'}->{'node_content'});
          $arg->{'extra'}->{'normalized'} = $normalized;
        }
      }
    }
    my $label_element = $current->{'args'}->[0];
    if (not $label_element or not $label_element->{'contents'}) {
      $self->_line_error(
        sprintf(__("empty argument in \@%s"),
          $current->{'cmdname'}), $current->{'source_info'});
    }
    _check_register_target_element_label($self, $label_element,
                                         $current, $source_info);

    if ($self->{'current_part'}) {
      my $part = $self->{'current_part'};
      if (not $part->{'extra'}
         or not $part->{'extra'}->{'part_associated_section'}) {
        # we only associate a part to the following node if the
        # part is not already associate to a sectioning command,
        # but the part can be associated to the sectioning command later
        # if a sectioning command follows the node.
        $current->{'extra'} = {} if (!$current->{'extra'});
        $current->{'extra'}->{'node_preceding_part'} = $part;
        $part->{'extra'} = {} if (!defined($part->{'extra'}));
        $part->{'extra'}->{'part_following_node'} = $current;
      }
    }
    $self->{'current_node'} = $current;
  } elsif ($command eq 'listoffloats') {
    _parse_float_type($current);
  } else {
    if ($self->{'index_entry_commands'}->{$current->{'cmdname'}}) {
      $current->{'type'} = 'index_entry_command';
      $current->{'info'} = {} if (!$current->{'info'});
      $current->{'info'}->{'command_name'} = $current->{'cmdname'};
    }
    # Handle all the other 'line' commands.  Here just check that they
    # have an argument.  Empty @top is allowed
    if (!$current->{'args'}->[0]->{'contents'} and $command ne 'top') {
      $self->_command_warn($current,
             __("\@%s missing argument"), $command);
    } else {
      if (($command eq 'item' or $command eq 'itemx')
          and $current->{'parent'}->{'cmdname'}
          and ($current->{'parent'}->{'cmdname'} eq 'ftable'
               or $current->{'parent'}->{'cmdname'} eq 'vtable')) {
        _enter_index_entry($self, $current->{'parent'}->{'cmdname'},
                           $current, $source_info);
      } elsif ($self->{'index_entry_commands'}->{$current->{'cmdname'}}) {
        _enter_index_entry($self, $current->{'cmdname'},
                           $current, $source_info);
      }
      # if there is a brace command interrupting an index or subentry
      # command, replace the internal internal_spaces_before_brace_in_index
      # text type with its final type depending on whether there is
      # text after the brace command.
      if (_is_index_element($self, $current)) {
        _set_non_ignored_space_in_index_before_command(
                                          $current->{'args'}->[0]);
      }
    }
  }
  $current = $current->{'parent'};
  if ($end_command) { # Set above
    # More processing of @end
    print STDERR "END COMMAND $end_command\n" if ($self->{'conf'}->{'DEBUG'});
    # Reparent the "@end" element to be a child of the block element.
    my $end = _pop_element_from_contents($self, $current);
    if ($block_commands{$end_command} ne 'conditional'
        or ($current->{'cmdname'} and $current->{'cmdname'} eq $end_command)
        or (not @{$self->{'conditional_stack'}}
            or $self->{'conditional_stack'}->[-1]->[0] ne $end_command)) {
      my $closed_command;
      ($closed_command, $current)
         = _close_commands($self, $current, $source_info, $end_command);
      if ($closed_command) {
        _close_command_cleanup($self, $closed_command);
        $end->{'parent'} = $closed_command;
        push @{$closed_command->{'contents'}}, $end;
      } else {
        # block command not found for @end
      }
      # closing a menu command, but still in a menu. Open a menu_comment
      if ($closed_command
          and $block_commands{$closed_command->{'cmdname'}} eq 'menu'
          and defined($self->_current_context_command())
          and $block_commands{$self->_current_context_command()} eq 'menu') {
        print STDERR "CLOSE menu but still in menu context\n"
          if ($self->{'conf'}->{'DEBUG'});
        push @{$current->{'contents'}}, {'type' => 'menu_comment',
                                         'parent' => $current,
                                         'contents' => [] };
        $current = $current->{'contents'}->[-1];
      }

      $current = _begin_preformatted($self, $current)
        if ($close_preformatted_commands{$end_command});
    } else {
      # case of a conditional not ignored
      my $cond_info = pop @{$self->{'conditional_stack'}};
      my ($cond_command, $cond_source_mark) = @$cond_info;
      print STDERR "POP END COND $end_command $cond_command\n"
        if ($self->{'conf'}->{'DEBUG'});
      my $end_source_mark = {'sourcemark_type' =>
                                 $cond_source_mark->{'sourcemark_type'},
                             'counter' =>
                                 $cond_source_mark->{'counter'},
      };
      $end_source_mark->{'status'} = 'end';
      delete $end->{'parent'};
      $end_source_mark->{'element'} = $end;
      _register_source_mark($self, $current, $end_source_mark);
    }
  } else {
    # Ignore @setfilename in included file, as said in the manual.
    if ($included_file
        or ($command eq 'setfilename' and _in_include($self))) {
      my $source_mark;
      if ($included_file) {
        $source_mark = $include_source_mark;
      } else {
        $source_mark = { 'sourcemark_type' => $command };
      }
      # keep the elements, also keeping source marks that are within
      # removed elements.  For the XS parser it is also easier to
      # manage the source mark memory which can stay associated
      # to the element.
      my $removed_element = _pop_element_from_contents($self, $current);
      delete $removed_element->{'parent'};
      $source_mark->{'element'} = $removed_element;
      _register_source_mark($self, $current, $source_mark);
    }
    $current = _begin_preformatted($self, $current)
      if ($close_preformatted_commands{$command});
  }

  if ($command eq 'setfilename'
      and ($self->{'current_node'} or $self->{'current_section'})) {
    $self->_command_warn($misc_cmd,
             __("\@%s after the first element"), $command);
  # columnfractions
  } elsif ($command eq 'columnfractions') {
    # in a multitable, we are in a block_line_arg
    if (!$current->{'parent'} or !$current->{'parent'}->{'cmdname'}
                 or $current->{'parent'}->{'cmdname'} ne 'multitable') {
      $self->_line_error(
          sprintf(__("\@%s only meaningful on a \@multitable line"),
             $command), $source_info);
    } else {
      $current->{'parent'}->{'extra'} = {}
        if (!defined($current->{'parent'}->{'extra'}));
      $current->{'parent'}->{'extra'}->{'columnfractions'} = $misc_cmd;
    }
  } elsif ($root_commands{$data_cmdname}) {
    $current = $current->{'contents'}->[-1];
    delete $current->{'remaining_args'};

    # associate the section (not part) with the current node.
    if ($command ne 'node' and $command ne 'part') {
      if ($self->{'current_node'}
         and (!$self->{'current_node'}->{'extra'}
              or !$self->{'current_node'}->{'extra'}->{'associated_section'})) {
        $self->{'current_node'}->{'extra'} = {}
          if (!$self->{'current_node'}->{'extra'});
        $self->{'current_node'}->{'extra'}->{'associated_section'} = $current;
        $current->{'extra'} = {} if (!$current->{'extra'});
        $current->{'extra'}->{'associated_node'} = $self->{'current_node'};
      }
      if ($self->{'current_part'}) {
        $current->{'extra'} = {} if (!defined($current->{'extra'}));
        $current->{'extra'}->{'associated_part'} = $self->{'current_part'};
        $self->{'current_part'}->{'extra'} = {}
          if (!defined($self->{'current_part'}->{'extra'}));
        $self->{'current_part'}->{'extra'}->{'part_associated_section'}
                                                 = $current;
        if ($current->{'cmdname'} eq 'top') {
          $self->_line_warn("\@part should not be associated with \@top",
                           $self->{'current_part'}->{'source_info'});
        }
        delete $self->{'current_part'};
      }
      $self->{'current_section'} = $current;
    } elsif ($command eq 'part') {
      $self->{'current_part'} = $current;
      if ($self->{'current_node'}
         and (!$self->{'current_node'}->{'extra'}
              or !$self->{'current_node'}->{'extra'}->{'associated_section'})) {
        $self->_line_warn(sprintf(__(
         "\@node precedes \@%s, but parts may not be associated with nodes"),
                                  $command), $source_info);
      }
    }
  }
  return $current;
}

sub _end_line_def_line($$$)
{
  my $self = shift;
  my $current = shift;
  my $source_info = shift;

  my $def_command;
  my $top_context = $self->_top_context();

  my $context_command
   = _pop_context($self, ['ct_def'], $source_info, $current);
  $def_command = $current->{'parent'}->{'extra'}->{'def_command'};

  print STDERR "END DEF LINE $def_command; current "
    .Texinfo::Common::debug_print_element($current, 1)."\n"
      if ($self->{'conf'}->{'DEBUG'});

  my $arguments = _parse_def($self, $def_command, $current, $source_info);

  $current = $current->{'parent'};

  if (scalar(keys(%$arguments)) == 0) {
    $self->_command_warn($current,
                         __('missing category for @%s'),
       $current->{'extra'}->{'original_def_cmdname'});
  } else {
    my $name_element = $arguments->{'name'};
    my $class_element = $arguments->{'class'};

    # do a standard index entry tree
    my $index_entry;
    if (defined($name_element)) {
      my $arg = $name_element->{'contents'}->[0];
      $index_entry = $name_element
       # empty bracketed
        unless ($arg->{'type'}
                and $arg->{'type'} eq 'bracketed_arg'
                and (!$arg->{'contents'}
                     or (!scalar(@{$arg->{'contents'}}))
                     or (scalar(@{$arg->{'contents'}}) == 1
                        and defined($arg->{'contents'}->[0]->{'text'})
                        and $arg->{'contents'}->[0]->{'text'} !~ /\S/)));
    }
    if (defined($index_entry)) {
      if ($class_element) {
        # Delay getting the text until Texinfo::Indices
        # in order to avoid calling gdt.
        # We need to store the language as well in case there are multiple
        # languages in the document.
        if ($def_command eq 'defop'
            or $def_command eq 'deftypeop'
            or $def_command eq 'defmethod'
            or $def_command eq 'deftypemethod'
            or $def_command eq 'defivar'
            or $def_command eq 'deftypeivar'
            or $def_command eq 'deftypecv') {
          undef $index_entry;
          if (defined($self->{'documentlanguage'})) {
            $current->{'extra'}->{'documentlanguage'}
                   = $self->{'documentlanguage'};
          }
        }
      }
      if ($index_entry) {
        my $element_copy
          = Texinfo::ManipulateTree::copy_treeNonXS($index_entry);
        $current->{'extra'}->{'def_index_element'} = $element_copy;
      }

      _enter_index_entry($self,
        $current->{'extra'}->{'def_command'},
        $current, $source_info)
           if $current->{'extra'}->{'def_command'} ne 'defline'
             and $current->{'extra'}->{'def_command'} ne 'deftypeline';
    } else {
      $self->_command_warn($current,
                           __('missing name for @%s'),
         $current->{'extra'}->{'original_def_cmdname'});
    }
  }
  $current = $current->{'parent'};
  $current = _begin_preformatted($self, $current);

  return $current;
}

sub _end_line_starting_block($$$)
{
  my $self = shift;
  my $current = shift;
  my $source_info = shift;

  my $document = $self->{'document'};

  my $command;
  if ($current->{'parent'}->{'extra'}
        and $current->{'parent'}->{'extra'}->{'def_command'}) {
    $command = $current->{'parent'}->{'parent'}->{'cmdname'}
  } else {
    $command = $current->{'parent'}->{'cmdname'};
  }
  $command = '' if !defined($command);

  if ($self->{'basic_inline_commands'}->{$command}) {
    pop @{$self->{'nesting_context'}->{'basic_inline_stack_block'}};
  }
  _isolate_last_space($self, $current);

  if ($current->{'parent'}->{'extra'}
        and $current->{'parent'}->{'extra'}->{'def_command'}) {
    $current = _end_line_def_line($self, $current, $source_info);
    return $current;
  }

  my $empty_text;
  _pop_context($self, ['ct_line'], $source_info, $current,
                      'in block_line_arg');

  print STDERR "END BLOCK LINE: "
     .Texinfo::Common::debug_print_element($current, 1)."\n"
       if ($self->{'conf'}->{'DEBUG'});

  # @multitable args
  if ($command eq 'multitable'
      and $current->{'parent'}->{'extra'}
      and defined($current->{'parent'}->{'extra'}->{'columnfractions'})) {
    my $multitable = $current->{'parent'};
    my $misc_cmd = $current->{'parent'}->{'extra'}->{'columnfractions'};

    $multitable->{'extra'} = {} if (!defined($multitable->{'extra'}));
    if ($misc_cmd->{'extra'}
        and defined($misc_cmd->{'extra'}->{'misc_args'})) {
      $multitable->{'extra'}->{'max_columns'}
          = scalar(@{$misc_cmd->{'extra'}->{'misc_args'}});
    } else {
      $multitable->{'extra'}->{'max_columns'} = 0;
      delete $multitable->{'extra'}->{'columnfractions'};
    }
  } elsif ($command eq 'multitable') {
    # determine max columns based on prototypes
    my $max_columns = 0;
    if ($current->{'contents'}) {
      foreach my $content (@{$current->{'contents'}}) {
        if ($content->{'type'} and $content->{'type'} eq 'bracketed_arg') {
          $max_columns++;
        } elsif ($content->{'text'}) {
          # TODO this should be a warning or an error - all prototypes
          # on a @multitable line should be in braces, as documented in the
          # Texinfo manual.
        } else {
          if (!$content->{'cmdname'}
                or ($content->{'cmdname'} ne 'c'
                    and $content->{'cmdname'} ne 'comment')) {
            $self->_command_warn($current->{'parent'},
                __("unexpected argument on \@%s line: %s"),
                     $command,
                     Texinfo::Convert::Texinfo::convert_to_texinfo($content));
          }
        }
      }
    }
    my $multitable = $current->{'parent'};
    $multitable->{'extra'} = {} if (!$multitable->{'extra'});
    $multitable->{'extra'}->{'max_columns'} = $max_columns;
    if (!$max_columns) {
      $self->_command_warn($multitable,
                           __("empty multitable"));
    }
  }
  $current = $current->{'parent'};
  delete $current->{'remaining_args'};

  # @float args
  if ($command eq 'float') {
    my $float_label_element;
    $float_label_element = $current->{'args'}->[1]
      if ($current->{'args'} and scalar(@{$current->{'args'}}) >= 2);
    _check_register_target_element_label($self, $float_label_element,
                                         $current, $source_info);

    my $float_type = _parse_float_type($current);
    push @{$document->{'listoffloats_list'}->{$float_type}}, $current;

    if (defined($self->{'current_section'})) {
      $current->{'extra'} = {} if (!defined($current->{'extra'}));
      $current->{'extra'}->{'float_section'} = $self->{'current_section'};
    }

    # all the commands with @item
  } elsif ($blockitem_commands{$command}) {
    if ($command eq 'enumerate') {
      my $spec = '1';
      if ($current->{'args'} and $current->{'args'}->[0]
          and $current->{'args'}->[0]->{'contents'}
          and @{$current->{'args'}->[0]->{'contents'}}) {
        if (scalar(@{$current->{'args'}->[0]->{'contents'}}) > 1) {
          $self->_command_error($current,
                      __("superfluous argument to \@%s"), $command);
        }
        my $arg = $current->{'args'}->[0]->{'contents'}->[0];
        if (!defined($arg->{'text'})
            or $arg->{'text'} !~ /^((\d+)|([[:alpha:]]))$/) {
          $self->_command_error($current,
                      __("bad argument to \@%s"), $command);
        } else {
          $spec = $arg->{'text'};
        }
      }
      $current->{'extra'} = {} if (!$current->{'extra'});
      $current->{'extra'}->{'enumerate_specification'} = $spec;
    } elsif ($block_commands{$command} eq 'item_line') {
      if (!$current->{'extra'}
          or !$current->{'extra'}->{'command_as_argument'}) {
        if ($current->{'args'}->[0]->{'contents'}
            and scalar(@{$current->{'args'}->[0]->{'contents'}})) {
          # expand the contents to avoid surrounding spaces
          my $texi_arg
            = Texinfo::Convert::Texinfo::convert_to_texinfo(
                    {'contents' => $current->{'args'}->[0]->{'contents'}});
          $self->_command_error($current,
                                __("bad argument to \@%s: %s"),
                                $command, $texi_arg);
        } else {
          $self->_command_error($current,
                                __("missing \@%s argument"),
                                $command);
        }
      } elsif ($self->{'brace_commands'}->{
    $current->{'extra'}->{'command_as_argument'}->{'cmdname'}} eq 'noarg') {
        $self->_command_error($current,
  __("command \@%s not accepting argument in brace should not be on \@%s line"),
            $current->{'extra'}->{'command_as_argument'}->{'cmdname'},
            $current->{'cmdname'});
        delete $current->{'extra'}->{'command_as_argument'};
        if (scalar(keys(%{$current->{'extra'}})) == 0) {
          delete $current->{'extra'};
        }
      }
    } elsif ($command eq 'itemize'
             and $current->{'extra'}
             and $current->{'extra'}->{'command_as_argument'}) {
      my $command_as_argument = $current->{'extra'}->{'command_as_argument'};
      # This code checks that the command_as_argument of the @itemize
      # is alone on the line, otherwise it is not a command_as_argument.
      my $i;
      my $line_arg = $current->{'args'}->[0];
      my $contents_nr = scalar(@{$line_arg->{'contents'}});
      for ($i = 0; $i < $contents_nr; $i++) {
        if ($line_arg->{'contents'}->[$i] eq $command_as_argument) {
          $i++;
          last;
        }
      }
      for (; $i < $contents_nr; $i++) {
        my $arg = $line_arg->{'contents'}->[$i];
        if (!(($arg->{'cmdname'}
               and ($arg->{'cmdname'} eq 'c'
                    or $arg->{'cmdname'} eq 'comment'))
              or (defined($arg->{'text'}) and $arg->{'text'} !~ /\S/))) {
          delete $current->{'extra'}->{'command_as_argument'};
          if (scalar(keys(%{$current->{'extra'}})) == 0) {
            delete $current->{'extra'};
          }
          $command_as_argument = undef;
          last;
        }
      }
      # if the command as argument does not have braces but it is
      # not a mark (noarg) command, warn
      if (defined($command_as_argument)
          and !$command_as_argument->{'args'}
          and $brace_commands{$command_as_argument->{'cmdname'}} ne 'noarg') {
        my $cmdname = $command_as_argument->{'cmdname'};
        $self->_command_warn($current, __("\@%s expected braces"),
                             $cmdname);
      }
    }
    # Check if command_as_argument isn't an accent command
    if ($current->{'extra'}
        and $current->{'extra'}->{'command_as_argument'}
        and $accent_commands{$current->{'extra'}->{'command_as_argument'}
                                                            ->{'cmdname'}}) {
      # this can only happen to an accent command with brace, if without
      # brace it is not set as command_as_argument to begin with.
      $self->_command_warn($current,
            __("accent command `\@%s' not allowed as \@%s argument"),
            $current->{'extra'}->{'command_as_argument'}->{'cmdname'},
            $command);
      delete $current->{'extra'}->{'command_as_argument'};
      if (scalar(keys(%{$current->{'extra'}})) == 0) {
        delete $current->{'extra'};
      }
    }
    if ($command eq 'itemize') {
      if (!$current->{'args'}
          or !scalar(@{$current->{'args'}})
          or !$current->{'args'}->[0]->{'contents'}) {
        my $block_line_arg;
        if ($current->{'args'} and $current->{'args'}->[-1]
            and $current->{'args'}->[-1]->{'type'}
            and $current->{'args'}->[-1]->{'type'} eq 'block_line_arg') {
          $block_line_arg = $current->{'args'}->[-1];
        } else {
          $block_line_arg = { 'type' => 'block_line_arg',
                              'parent' => $current,
                              'contents' => [] };
          unshift @{$current->{'args'}}, $block_line_arg;
        }
        my $inserted = { 'cmdname' => 'bullet',
                         'info' => {'inserted' => 1},
                         'parent' => $block_line_arg };
        unshift @{$block_line_arg->{'contents'}}, $inserted;
        $current->{'extra'} = {} if (!$current->{'extra'});
        $current->{'extra'}->{'command_as_argument'} = $inserted;
      }
    } elsif ($block_commands{$command} eq 'item_line') {
      $current->{'extra'} = {} if (!$current->{'extra'});
      if (!$current->{'extra'}->{'command_as_argument'}) {
        my $inserted =  { 'cmdname' => 'asis',
                          'info' => {'inserted' => 1},
                          'parent' => $current };
        unshift @{$current->{'args'}}, $inserted;
        $current->{'extra'}->{'command_as_argument'} = $inserted;
      }
    }
    push @{$current->{'contents'}}, { 'type' => 'before_item',
                                      'parent', $current };
    $current = $current->{'contents'}->[-1];
  } elsif (not $commands_args_number{$command}
           and not exists($variadic_commands{$command})
           and $current->{'args'}
           and scalar(@{$current->{'args'}})
           and $current->{'args'}->[0]->{'contents'}
           and scalar(@{$current->{'args'}->[0]->{'contents'}})) {
    # expand the contents to avoid surrounding spaces
    my $texi_arg = Texinfo::Convert::Texinfo::convert_to_texinfo(
                       {'contents' => $current->{'args'}->[0]->{'contents'}});
    $self->_command_warn($current,
                         __("unexpected argument on \@%s line: %s"),
                         $command, $texi_arg);
  }
  if ($block_commands{$command} eq 'conditional') {
    my $ifvalue_true = 0;
    my $bad_line = 1;
    if ($command eq 'ifclear' or $command eq 'ifset'
        or $command eq 'ifcommanddefined'
        or $command eq 'ifcommandnotdefined') {
      if ($current->{'args'} and scalar(@{$current->{'args'}} == 1)
          and $current->{'args'}->[0]->{'contents'}
          and scalar(@{$current->{'args'}->[0]->{'contents'}} == 1)) {
        if (defined($current->{'args'}->[0]->{'contents'}->[0]->{'text'})) {
          my $name = $current->{'args'}->[0]->{'contents'}->[0]->{'text'};
          if ($name !~ /\S/) {
            $self->_line_error(sprintf(
                __("\@%s requires a name"), $command), $source_info);
            $bad_line = 0;
          } else {
            if ($command eq 'ifclear' or $command eq 'ifset') {
              # REVALUE
              if ($name =~ /^[\w\-][^\s{\\}~`\^+"<>|@]*$/) {
                if ((exists($self->{'values'}->{$name}) and $command eq 'ifset')
                     or (!exists($self->{'values'}->{$name})
                         and $command eq 'ifclear')) {
                  $ifvalue_true = 1;
                }
                print STDERR "CONDITIONAL \@$command $name: $ifvalue_true\n"
                                            if ($self->{'conf'}->{'DEBUG'});
                $bad_line = 0;
              }
            } else { # $command eq 'ifcommanddefined' or 'ifcommandnotdefined'
              # REMACRO
              if ($name =~ /^[[:alnum:]][[:alnum:]\-]*$/) {
                my $command_is_defined = (
                  exists($all_commands{$name})
                  or $self->{'macros'}->{$name}
                  or $self->{'definfoenclose'}->{$name}
                  or exists($self->{'aliases'}->{$name})
                  or $self->{'index_entry_commands'}->{$name}
                );
                if (($command_is_defined
                     and $command eq 'ifcommanddefined')
                    or (! $command_is_defined
                         and $command eq 'ifcommandnotdefined')) {
                  $ifvalue_true = 1;
                }
                print STDERR "CONDITIONAL \@$command $name: $ifvalue_true\n"
                                             if ($self->{'conf'}->{'DEBUG'});
                $bad_line = 0;
              }
            }
          }
        }
      } else {
        $self->_line_error(sprintf(
            __("\@%s requires a name"), $command), $source_info);
        $bad_line = 0;
      }
      $self->_line_error(sprintf(
        __("bad name for \@%s"), $command), $source_info)
         if ($bad_line);
    } elsif ($command =~ /^ifnot(.*)/) {
      $ifvalue_true = 1 if !($self->{'expanded_formats_hash'}->{$1}
                     # exception as explained in the texinfo manual
                     or ($1 eq 'info'
                         and $self->{'expanded_formats_hash'}->{'plaintext'}));
      print STDERR "CONDITIONAL \@$command format $1: $ifvalue_true\n"
                                          if ($self->{'conf'}->{'DEBUG'});
    } else {
      die unless ($command =~ /^if(.*)/);
      $ifvalue_true = 1 if ($self->{'expanded_formats_hash'}->{$1}
              or ($1 eq 'info'
                  and $self->{'expanded_formats_hash'}->{'plaintext'}));
      print STDERR "CONDITIONAL \@$command format $1: $ifvalue_true\n"
                                       if ($self->{'conf'}->{'DEBUG'});
    }
    if ($ifvalue_true) {
      my $conditional_element = $current;
      $current = $current->{'parent'};
      my $conditional_command = _pop_element_from_contents($self, $current);
      die "BUG popping\n" if ($conditional_element ne $conditional_command);
      delete $conditional_command->{'parent'};
      my $source_mark = {'sourcemark_type' => 'expanded_conditional_command',
                         'status' => 'start',
                         'element' => $conditional_command};
      _register_source_mark($self, $current, $source_mark);
      print STDERR "PUSH BEGIN COND $command\n"
          if ($self->{'conf'}->{'DEBUG'});
      push @{$self->{'conditional_stack'}}, [$command, $source_mark];
    }
  }
  if ($block_commands{$command} eq 'menu') {
    push @{$current->{'contents'}}, {'type' => 'menu_comment',
                                     'parent' => $current,
                                     'contents' => [] };
    $current = $current->{'contents'}->[-1];
    print STDERR "MENU_COMMENT OPEN\n" if ($self->{'conf'}->{'DEBUG'});
  }
  if ($block_commands{$command} eq 'format_raw'
      and $self->{'expanded_formats_hash'}->{$command}) {
    push @{$current->{'contents'}},
        { 'type' => 'rawpreformatted',
          'parent' => $current };
    $current = $current->{'contents'}->[-1];
  }
  $current = _begin_preformatted($self, $current)
    unless ($block_commands{$command} eq 'raw'
            or $block_commands{$command} eq 'conditional');

  return $current;
}

sub _end_line_menu_entry ($$$)
{
  my $self = shift;
  my $current = shift;
  my $source_info = shift;

  my $empty_menu_entry_node = 0;
  my $end_comment;
  if ($current->{'type'} eq 'menu_entry_node') {
    if ($current->{'contents'}
        and $current->{'contents'}->[-1]->{'cmdname'}
        and ($current->{'contents'}->[-1]->{'cmdname'} eq 'c'
             or $current->{'contents'}->[-1]->{'cmdname'} eq 'comment')) {
      $end_comment = _pop_element_from_contents($self, $current);
    }
    if (not $current->{'contents'}
         # empty if only the end of line or spaces, including non ascii spaces
         or (scalar(@{$current->{'contents'}}) == 1
             and defined($current->{'contents'}->[-1]->{'text'})
             and $current->{'contents'}->[-1]->{'text'} !~ /\S/)) {
      $empty_menu_entry_node = 1;
      push @{$current->{'contents'}}, $end_comment if ($end_comment);
    }
  }
  # we abort the menu entry if there is no node name
  if ($empty_menu_entry_node or $current->{'type'} eq 'menu_entry_name') {
    my $description_or_menu_comment;
    my $menu_type_reopened = 'menu_description';
    print STDERR "FINALLY NOT MENU ENTRY\n" if ($self->{'conf'}->{'DEBUG'});
    my $menu = $current->{'parent'}->{'parent'};
    my $menu_entry = _pop_element_from_contents($self, $menu);
    if ($menu->{'contents'}
        and $menu->{'contents'}->[-1]->{'type'}
        and $menu->{'contents'}->[-1]->{'type'} eq 'menu_entry') {
      my $entry = $menu->{'contents'}->[-1];
      my $description;
      foreach my $entry_element (reverse(@{$entry->{'contents'}})) {
        if ($entry_element->{'type'} eq 'menu_entry_description') {
          $description = $entry_element;
          last;
        }
      }
      if ($description) {
        $description_or_menu_comment = $description;
      } else {
        # Normally this cannot happen
        $self->_bug_message("no description in menu_entry",
                             $source_info, $current);
        push @{$entry->{'contents'}}, {'type' => 'menu_entry_description',
                                   'parent' => $entry, };
        $description_or_menu_comment = $entry->{'contents'}->[-1];
      }
    } elsif ($menu->{'contents'} and scalar(@{$menu->{'contents'}})
             and $menu->{'contents'}->[-1]->{'type'}
             and $menu->{'contents'}->[-1]->{'type'} eq 'menu_comment') {
      $description_or_menu_comment = $menu->{'contents'}->[-1];
      $menu_type_reopened = 'menu_comment';
    }
    if ($description_or_menu_comment) {
      $current = $description_or_menu_comment;
      if ($current->{'contents'}->[-1]
          and $current->{'contents'}->[-1]->{'type'}
          and $current->{'contents'}->[-1]->{'type'} eq 'preformatted') {
        $current = $current->{'contents'}->[-1];
      } else {
        # this should not happen
        $self->_bug_message("description or menu comment not in preformatted",
                            $source_info, $current);
        push @{$current->{'contents'}}, {'type' => 'preformatted',
                                  'parent' => $current, };
        $current = $current->{'contents'}->[-1];
      }
    } else {
      push @{$menu->{'contents'}}, {'type' => 'menu_comment',
                                  'parent' => $menu,
                                  'contents' => [] };
      $current = $menu->{'contents'}->[-1];
      push @{$current->{'contents'}}, {'type' => 'preformatted',
                                'parent' => $current, };
      $current = $current->{'contents'}->[-1];
      print STDERR "THEN MENU_COMMENT OPEN\n" if ($self->{'conf'}->{'DEBUG'});
    }
    # source marks tested in t/*macro.t macro_in_menu_comment_like_entry
    while (@{$menu_entry->{'contents'}}) {
      my $arg = shift @{$menu_entry->{'contents'}};
      if (defined($arg->{'text'})) {
        $current = _merge_text($self, $current, $arg->{'text'}, $arg);
      } elsif ($arg->{'contents'}) {
        while (@{$arg->{'contents'}}) {
          my $content = shift @{$arg->{'contents'}};
          if (defined($content->{'text'})) {
            $current = _merge_text($self, $current, $content->{'text'},
                                   $content);
            $content = undef;
          } else {
            $content->{'parent'} = $current;
            push @{$current->{'contents'}}, $content;
          }
        }
      }
      $arg = undef;
    }
    # MENU_COMMENT open
    $menu_entry = undef;
  } else {
    print STDERR "MENU ENTRY END LINE\n" if ($self->{'conf'}->{'DEBUG'});
    $current = $current->{'parent'};
    $current = _enter_menu_entry_node($self, $current, $source_info);
    if (defined($end_comment)) {
      $end_comment->{'parent'} = $current;
      push @{$current->{'contents'}}, $end_comment;
    }
  }
  return $current;
}

# close constructs and do stuff at end of line (or end of the document)
sub _end_line($$$);
sub _end_line($$$)
{
  my ($self, $current, $source_info) = @_;

  my $current_old = $current;

  my $prev_element_type;
  if ($current->{'contents'}) {
    my $prev_element = $current->{'contents'}->[-1];
    if ($prev_element->{'type'}) {
      $prev_element_type = $prev_element->{'type'};
    }
  }

  # a line consisting only of spaces.
  if (defined($prev_element_type)
      and $prev_element_type eq 'empty_line') {
    print STDERR "END EMPTY LINE in "
        . Texinfo::Common::debug_print_element($current)."\n"
          if ($self->{'conf'}->{'DEBUG'});
    if ($current->{'type'} and $current->{'type'} eq 'paragraph') {
      # Remove empty_line element.
      my $empty_line = _pop_element_from_contents($self, $current);
      print STDERR "CLOSE PARA\n" if ($self->{'conf'}->{'DEBUG'});
      $current = _close_container($self, $current, $source_info);
      push @{$current->{'contents'}}, $empty_line;
      $empty_line->{'parent'} = $current;
    } elsif ($current->{'type'}
             and $current->{'type'} eq 'preformatted'
             and $current->{'parent'}->{'type'}
             and $current->{'parent'}->{'type'} eq 'menu_entry_description')  {
      # happens for an empty line following a menu_description
      my $empty_line = _pop_element_from_contents($self, $current);
      my $preformatted = $current;
      $current = $current->{'parent'};
      if (not $preformatted->{'contents'} or
          not scalar(@{$preformatted->{'contents'}})) {
        my $empty_preformatted = _pop_element_from_contents($self, $current);
        # it should not be possible to have associated source marks
        # as the source marks are either associated to the menu description
        # or to the empty line after the menu description.  Leave a message
        # in case it happens in the future/some unexpected case.
        if ($self->{'conf'}->{'TEST'}
            and $empty_preformatted->{'source_marks'}) {
          print STDERR "BUG: source_marks in menu description preformatted\n";
        }
      }

      # first parent is menu_entry
      $current = $current->{'parent'}->{'parent'};

      push @{$current->{'contents'}}, { 'type' => 'menu_comment',
                                        'parent' => $current,
                                        'contents' => [] };
      $current = $current->{'contents'}->[-1];
      push @{$current->{'contents'}}, { 'type' => 'preformatted',
                                        'parent' => $current,
                                        'contents' => [] };
      $current = $current->{'contents'}->[-1];
      my $after_menu_description_line = {
                                        'type' => 'after_menu_description_line',
                                        'text' => $empty_line->{'text'},
                                        'parent' => $current };
      _transfer_source_marks($empty_line, $after_menu_description_line);
      push @{$current->{'contents'}}, $after_menu_description_line;
      print STDERR "MENU: END DESCRIPTION, OPEN COMMENT\n"
                                   if ($self->{'conf'}->{'DEBUG'});
    } elsif ($self->_top_context() eq 'ct_paragraph') {
      # in a paragraph, but not directly.  For instance an empty line
      # in a style brace @-command
      $current = _end_paragraph($self, $current, $source_info);
    # FIXME not sure about this one, could be better to close
    # brace commands in more contexts.  Should make sure that
    # it is ok before, for instance, it is not sure that CM_inlineraw
    # should be closed that way, as it does not seems that the
    # ct_inlineraw context is popped.
    } elsif ($self->_top_context() eq 'ct_base') {
      # closes no_paragraph brace commands that are not context brace
      # commands but contain a new line, anchor for example
      $current = _close_all_style_commands($self, $current, $source_info);
    }

  # end of a menu line.
  } elsif ($current->{'type'}
    and ($current->{'type'} eq 'menu_entry_name'
     or $current->{'type'} eq 'menu_entry_node')) {
    $current = _end_line_menu_entry($self, $current, $source_info);
  # block command lines
  } elsif ($current->{'type'}
            and $current->{'type'} eq 'block_line_arg') {
    $current = _end_line_starting_block($self, $current, $source_info);

  # misc command line arguments
  # Never go here if lineraw/noarg/...
  } elsif ($current->{'type'} and $current->{'type'} eq 'line_arg') {
    $current = _end_line_misc_line($self, $current, $source_info);
  } elsif (defined($prev_element_type)
           and ($prev_element_type eq 'internal_spaces_before_argument'
                or $prev_element_type
                          eq 'internal_spaces_before_context_argument')) {
    # Empty spaces after brace or comma till the end of line.
    # Remove this element and update 'extra' values.
    _move_last_space_to_element($self, $current);
  }

  # this happens if there is a nesting of @-commands on a line, for
  # instance line commands, but also bogus brace commands
  # without args or not closed.   They are reprocessed here.
  my $top_context = $self->_top_context();
  if (($top_context eq 'ct_line'
       and defined($self->{'context_command_stack'}->[-1]))
      or $top_context eq 'ct_def') {
    print STDERR "Still opened line/block command $top_context: "
      .Texinfo::Common::debug_print_element($current, 1)."\n"
        if ($self->{'conf'}->{'DEBUG'});

    # should correspond to a bogus brace @-commands without argument
    # followed by spaces only, and not by newline, at the end of the document
    # on a line/def command
    if ($current->{'cmdname'}
      and defined($self->{'brace_commands'}->{$current->{'cmdname'}})) {
      $self->_line_error(sprintf(__("\@%s expected braces"),
                         $current->{'cmdname'}), $source_info);
      if ($current->{'contents'}) {
        _gather_spaces_after_cmd_before_arg($self, $current);
      }
      $current = $current->{'parent'};
    }

    if ($top_context eq 'ct_def') {
      while ($current->{'parent'}
            and !($current->{'parent'}->{'extra'}
                  and $current->{'parent'}->{'extra'}->{'def_command'})) {
        $current = _close_current($self, $current, $source_info);
      }
    } else {
      while ($current->{'parent'} and !($current->{'type'}
             and ($current->{'type'} eq 'block_line_arg'
                  or $current->{'type'} eq 'line_arg'))) {
        $current = _close_current($self, $current, $source_info);
      }
    }

    # check for infinite loop bugs...
    if ($current eq $current_old) {
      my $indent_str = '- ';
      my $tree_msg
            = $indent_str . Texinfo::Common::debug_print_element($current);
      while ($current->{'parent'}) {
        $indent_str = '-'.$indent_str;
        $current = $current->{'parent'};
        $tree_msg
            .= $indent_str . Texinfo::Common::debug_print_element($current);
      }
      $self->_bug_message("Nothing closed while a line context remains\n"
                                                                . $tree_msg,
                          $source_info);
      die;
    }

    $current = $self->_end_line($current, $source_info);
  }
  return $current;
}

# Add an "ignorable_spaces_after_command" element containing the
# whitespace at the beginning of the rest of the line after skipspaces
# commands, if COMMAND is undef.  Otherwise add an
# "internal_spaces_after_command" text element, after line commands
# or commands starting a block, that will end up in COMMAND info
# spaces_before_argument.
sub _start_empty_line_after_command($$$$) {
  my ($self, $line, $current, $command) = @_;

  # based on whitespace_chars_except_newline in XS parser
  $line =~ s/^([ \t\cK\f]*)//;
  my $spaces_after_command = { 'type' => 'ignorable_spaces_after_command',
                               'text' => $1,
                               'parent' => $current,
                             };
  push @{$current->{'contents'}}, $spaces_after_command;
  if (defined($command)) {
    $spaces_after_command->{'type'} = 'internal_spaces_after_command';
    $self->{'internal_space_holder'} = $command;
  }
  return $line;
}

sub _check_register_target_element_label($$$$)
{
  my ($self, $label_element, $target_element, $source_info) = @_;

  if ($label_element and $label_element->{'contents'}) {
    my ($label_info, $modified_node_content)
      = Texinfo::Common::parse_node_manual($label_element);
    if ($label_info and $label_info->{'manual_content'}) {
      $self->_line_error(sprintf(__("syntax for an external node used for `%s'"),
       # use contents to avoid leading/trailing spaces
       Texinfo::Convert::Texinfo::convert_to_texinfo(
                                    {'contents' => $label_element->{'contents'}})),
                         $source_info);
    }
    my $normalized
         = Texinfo::Convert::NodeNameNormalization::convert_to_identifier(
             $label_element);
    if ($normalized !~ /[^-]/) {
      $self->_line_error(sprintf(__("empty node name after expansion `%s'"),
                         # convert the contents only, to avoid spaces
                              Texinfo::Convert::Texinfo::convert_to_texinfo(
                               {'contents' => $label_element->{'contents'}})),
                                 $target_element->{'source_info'});
    } else {
      $target_element->{'extra'} = {} if (!$target_element->{'extra'});
      $target_element->{'extra'}->{'normalized'} = $normalized;
    }
  }
  push @{$self->{'document'}->{'labels_list'}}, $target_element;
}

# Return 1 if an element is all whitespace.
# Note that this function isn't completely reliable because it
# doesn't look deep into the element tree.
# Consistent with XS parser
sub _check_empty_expansion($)
{
  my $current = shift;

  foreach my $content (@$current) {
    if (!(($content->{'cmdname'}
           and ($content->{'cmdname'} eq ' ' or $content->{'cmdname'} eq "\t"
                or $content->{'cmdname'} eq "\n"
                or $content->{'cmdname'} eq 'c'
                or $content->{'cmdname'} eq 'comment'
                or $content->{'cmdname'} eq ':'))
           or (defined($content->{'text'}) and $content->{'text'} !~ /\S/))) {
      return 0;
    }
  }
  return 1;
}

sub _register_extra_menu_entry_information($$;$)
{
  my ($self, $current, $source_info) = @_;

  my $menu_entry_node;
  foreach my $arg (@{$current->{'contents'}}) {
    if ($arg->{'type'} eq 'menu_entry_name') {
      if (not $arg->{'contents'} or scalar(@{$arg->{'contents'}}) == 0) {
        $self->_line_warn(sprintf(__("empty menu entry name in `%s'"),
                   Texinfo::Convert::Texinfo::convert_to_texinfo($current)),
                          $source_info);
      }
    } elsif ($arg->{'type'} eq 'menu_entry_node') {
      _isolate_trailing_space($arg, 'space_at_end_menu_node');
      if (! $arg->{'contents'}) {
        if ($self->{'conf'}->{'FORMAT_MENU'} eq 'menu') {
          $self->_line_error(__("empty node name in menu entry"), $source_info);
        }
      } else {
        $menu_entry_node = $arg;
        my $parsed_entry_node
          = Texinfo::Common::parse_node_manual($arg, 1);
        if (defined($parsed_entry_node)) {
          foreach my $label_info (keys(%$parsed_entry_node)) {
            $arg->{'extra'} = {} if (!$arg->{'extra'});
            $arg->{'extra'}->{$label_info}
              = $parsed_entry_node->{$label_info};
          }
        } else {
          $self->_bug_message("No label info for menu_entry_node contents",
                              $source_info, $current);
        }
      }
    }
  }
  return $menu_entry_node;
}

sub _enter_menu_entry_node($$$)
{
  my ($self, $current, $source_info) = @_;

  $current->{'source_info'} = {%$source_info};

  my $menu_entry_node
    = _register_extra_menu_entry_information($self, $current, $source_info);
  push @{$self->{'document'}->{'internal_references'}}, $menu_entry_node
     if (defined($menu_entry_node));

  my $description = { 'type' => 'menu_entry_description',
                      'parent' => $current };
  push @{$current->{'contents'}}, $description;

  $current = $description;
  push @{$current->{'contents'}}, {'type' => 'preformatted',
                                   'parent' => $current, };
  $current = $current->{'contents'}->[-1];
  return $current;
}

# If the container can hold a command as an argument, determined as
# parent element taking a command as an argument, like
# @itemize @bullet, and the command as argument being the only content.
sub _parent_of_command_as_argument($)
{
  my $current = shift;
  return ($current and $current->{'type'}
      and $current->{'type'} eq 'block_line_arg'
      and $current->{'parent'}
      and $current->{'parent'}->{'cmdname'}
      and ($current->{'parent'}->{'cmdname'} eq 'itemize'
           or ($block_commands{$current->{'parent'}->{'cmdname'}}
               and $block_commands{$current->{'parent'}->{'cmdname'}} eq 'item_line'))
      and scalar(@{$current->{'contents'}}) == 1);
}

# register a command like @bullet with @itemize, or @asis with @table
sub _register_command_as_argument($$)
{
  my $self = shift;
  my $cmd_as_arg = shift;
  print STDERR "FOR PARENT \@$cmd_as_arg->{'parent'}->{'parent'}->{'cmdname'} ".
         "command_as_argument $cmd_as_arg->{'cmdname'}\n"
              if ($self->{'conf'}->{'DEBUG'});
  $cmd_as_arg->{'parent'}->{'parent'}->{'extra'} = {}
    if (!defined($cmd_as_arg->{'parent'}->{'parent'}->{'extra'}));
  $cmd_as_arg->{'parent'}->{'parent'}->{'extra'}->{'command_as_argument'}
    = $cmd_as_arg;
  if ($cmd_as_arg->{'cmdname'} eq 'kbd'
      and _kbd_formatted_as_code($self, $cmd_as_arg->{'parent'}->{'parent'})) {
    $cmd_as_arg->{'parent'}->{'parent'}->{'extra'}->{'command_as_argument_kbd_code'} = 1;
  }
}

sub _is_index_element {
  my ($self, $element) = @_;

  if (!$element->{'cmdname'}
      or (!$self->{'index_entry_commands'}->{$element->{'cmdname'}}
          and $element->{'cmdname'} ne 'subentry')) {
    return 0;
  }
  return 1;
}

# NOTE - this sub has an XS override
sub _parse_command_name {
  my ($line) = @_;
  # REMACRO
  my ($at_command, $single_letter_command)
   = ($line =~ /^([[:alnum:]][[:alnum:]-]*)
                |^(["'~\@&\}\{,\.!\? \t\n\*\-\^`=:\|\/\\])
                /x);

  my $command;
  my $is_single_letter = 0;
  if ($single_letter_command) {
    $command = $single_letter_command;
    $is_single_letter = 1;
  } elsif (defined($at_command) and $at_command ne '') {
    $command = $at_command;
  }
  return ($command, $is_single_letter);
}

# This combines several regular expressions used in '_parse_texi' to
# look at what is next on the remaining part of the line.
# NOTE - this sub has an XS override
sub _parse_texi_regex {
  my ($line) = @_;

  # REMACRO
  my ($arobase, $open_brace, $close_brace, $comma,
      $asterisk, $form_feed, $menu_only_separator, $misc_text)
    = ($line =~ /^(@)
                |^(\{)
                |^(\})
                |^(,)
                |^(\*)
                |^(\f)
                |^([:\t.])
                |^([^{}@,:\t.\n\f]+)
                /x);

  if ($asterisk) {
    ($misc_text) = ($line =~ /^([^{}@,:\t.\n\f]+)/);
  }

  return ($arobase, $open_brace, $close_brace, $comma,
    $asterisk, $form_feed, $menu_only_separator, $misc_text);
}

sub _check_line_directive {
  my ($self, $line, $source_info) = @_;

  if ($self->{'conf'}->{'CPP_LINE_DIRECTIVES'}
      and defined($source_info->{'file_name'})
      and $source_info->{'file_name'} ne ''
      and !defined($source_info->{'macro'})
      and $line =~ /^\s*#\s*(line)? (\d+)(( "([^"]+)")(\s+\d+)*)?\s*$/) {
    _save_line_directive($self, int($2), $5);
    return 1;
  }
  return 0;
}

# Check whether $COMMAND can appear within $CURRENT->{'parent'}.
sub _check_valid_nesting {
  my ($self, $current, $command, $source_info) = @_;

  my $invalid_parent;
  # error messages for forbidden constructs, like @node in @r,
  # block command on line command, @xref in @anchor or node...
  if ($current->{'parent'}) {
    if ($current->{'parent'}->{'cmdname'}) {
      if (defined($self->{'valid_nestings'}
                                   ->{$current->{'parent'}->{'cmdname'}})
          and !$self->{'valid_nestings'}
                             ->{$current->{'parent'}->{'cmdname'}}->{$command}
          # we make sure that we are on a root @-command line and
          # not in contents
          and (!$root_commands{$current->{'parent'}->{'cmdname'}}
               or ($current->{'type'}
                   and $current->{'type'} eq 'line_arg'))
          # we make sure that we are on a block @-command line and
          # not in contents
          and (!defined($block_commands{$current->{'parent'}->{'cmdname'}})
               or ($current->{'type'}
                   and $current->{'type'} eq 'block_line_arg'))
          # we make sure that we are on an @item/@itemx line and
          # not in an @enumerate, @multitable or @itemize @item.
          and (($current->{'parent'}->{'cmdname'} ne 'itemx'
                and $current->{'parent'}->{'cmdname'} ne 'item')
               or ($current->{'type'}
                        and $current->{'type'} eq 'line_arg'))) {
        $invalid_parent = $current->{'parent'}->{'cmdname'};
      }
    }
  }

  if (defined($invalid_parent)) {
    $self->_line_warn(sprintf(__("\@%s should not appear in \@%s"),
              $command, $invalid_parent), $source_info);
  }
}

sub _check_valid_nesting_context
{
  my ($self, $command, $source_info) = @_;

  if (($command eq 'caption' or $command eq 'shortcaption')
      and $self->{'nesting_context'}->{'caption'}) {
    $self->_line_warn(sprintf(
        __("\@%s should not appear anywhere inside caption"),
          $command), $source_info);
    return;
  }

  my $invalid_context;
  if ($command eq 'footnote' and $self->{'nesting_context'}->{'footnote'}) {
    $invalid_context = 'footnote';
  } elsif (defined($self->{'nesting_context'}->{'basic_inline_stack'})
       and @{$self->{'nesting_context'}->{'basic_inline_stack'}} > 0
       and !$in_basic_inline_commands{$command}) {
    $invalid_context
      = $self->{'nesting_context'}->{'basic_inline_stack'}->[-1];
  }

  if ($invalid_context) {
    $self->_line_warn(sprintf(
          __("\@%s should not appear anywhere inside \@%s"),
              $command, $invalid_context), $source_info);
    return;
  }

  if (defined($self->{'nesting_context'}->{'basic_inline_stack_on_line'})
       and @{$self->{'nesting_context'}->{'basic_inline_stack_on_line'}} > 0
       and !$in_basic_inline_commands{$command}) {
    $invalid_context
      = $self->{'nesting_context'}->{'basic_inline_stack_on_line'}->[-1];
  } elsif (defined($self->{'nesting_context'}->{'basic_inline_stack_block'})
       and @{$self->{'nesting_context'}->{'basic_inline_stack_block'}} > 0
       and !$in_basic_inline_commands{$command}) {
    $invalid_context
      = $self->{'nesting_context'}->{'basic_inline_stack_block'}->[-1];
  }

  if ($invalid_context
        and $contain_basic_inline_with_refs_commands{$invalid_context}) {
    if ($ok_in_basic_inline_with_refs_commands{$command}) {
      undef $invalid_context;
    }
  }

  if ($invalid_context) {
    $self->_line_warn(sprintf(
          __("\@%s should not appear on \@%s line"),
              $command, $invalid_context), $source_info);
    return;
  }

  if (defined($self->{'nesting_context'}->{'regions_stack'})
       and @{$self->{'nesting_context'}->{'regions_stack'}} > 0) {
    if ($not_in_region_commands{$command}) {
      $invalid_context = $self->{'nesting_context'}->{'regions_stack'}->[-1];
    }
  }

  if ($invalid_context) {
    $self->_line_warn(sprintf(
          __("\@%s should not appear in \@%s block"),
              $command, $invalid_context), $source_info);
  }
  return;
}

sub _setup_document_root_and_before_node_section()
{
  my $before_node_section = { 'type' => 'before_node_section' };
  my $document_root = { 'contents' => [$before_node_section],
                        'type' => 'document_root' };
  $before_node_section->{'parent'} = $document_root;
  return ($document_root, $before_node_section);
}

sub _new_value_element($$;$$)
{
  my $command = shift;
  my $flag = shift;
  my $current = shift;
  my $spaces_element = shift;

  my $value_elt = { 'cmdname' => $command,
                      'args' => [] };
  $value_elt->{'parent'} = $current if (defined($current));
  my $brace_container = {'type' => 'brace_container',
                         'contents' => [], 'parent' => $value_elt};
  push @{$value_elt->{'args'}}, $brace_container;
  push @{$brace_container->{'contents'}}, {'text' => $flag,
                                           'parent' => $brace_container};
  if ($spaces_element) {
    $value_elt->{'info'} = {} if (!$value_elt->{'info'});
    $value_elt->{'info'}->{'spaces_after_cmd_before_arg'} = $spaces_element;
  }
  return $value_elt;
}

sub _gather_spaces_after_cmd_before_arg($$)
{
  my $self = shift;
  my $current = shift;
  # it could be possible to check that there is no other content and that
  # the type is the expected type.
  my $spaces_element = _pop_element_from_contents($self, $current);
  delete $spaces_element->{'type'};
  $current->{'info'} = {} if (!$current->{'info'});
  $current->{'info'}->{'spaces_after_cmd_before_arg'} = $spaces_element;
}

sub _handle_macro($$$$$)
{
  my $self = shift;
  my $current = shift;
  my $line = shift;
  my $source_info = shift;
  my $command = shift;

  my $expanded_macro = $self->{'macros'}->{$command}->{'element'};

  # It is important to check for expansion before the expansion and
  # not after, as during the expansion, the text may go past the
  # call.  In particular for user defined linemacro which generally
  # get the final new line from following text.
  $self->{'macro_expansion_nr'}++;
  print STDERR "MACRO EXPANSION NUMBER $self->{'macro_expansion_nr'} $command\n"
    if ($self->{'conf'}->{'DEBUG'});

  my $error;
  # TODO use a different counter for linemacro?
  if ($self->{'conf'}->{'MAX_MACRO_CALL_NESTING'}
      and $self->{'macro_expansion_nr'}
                  > $self->{'conf'}->{'MAX_MACRO_CALL_NESTING'}) {
    $self->_line_warn(sprintf(__(
  "macro call nested too deeply (set MAX_MACRO_CALL_NESTING to override; current value %d)"),
          $self->{'conf'}->{'MAX_MACRO_CALL_NESTING'}), $source_info);
    $error = 1;
  }

  if ($expanded_macro->{'cmdname'} ne 'rmacro') {
    foreach my $input (@{$self->{'input'}}[0..$#{$self->{'input'}}-1]) {
      if (defined($input->{'input_source_info'}->{'macro'})
          and $input->{'input_source_info'}->{'macro'} eq $command) {
        # TODO different message for linemacro?
        $self->_line_error(sprintf(__(
       "recursive call of macro %s is not allowed; use \@rmacro if needed"),
                                   $command), $source_info);
        $error = 1;
        last;
      }
    }
  }

  my $macro_call_element = {'type' => $expanded_macro->{'cmdname'}.'_call',
                            'info' => {'command_name' => $command},
                            'args' => []};


  if ($expanded_macro->{'cmdname'} eq 'linemacro') {
    ($line, $source_info)
     = _expand_linemacro_arguments($self, $expanded_macro, $line, $source_info,
                                   $macro_call_element);
  } else {
    my $args_number = scalar(@{$expanded_macro->{'args'}}) -1;
    if ($line =~ /^\s*{/) { # } macro with args
      if ($line =~ s/^(\s+)//) {
        my $spaces_element = {'text' => $1};
        $macro_call_element->{'info'} = {} if (!$macro_call_element->{'info'});
        $macro_call_element->{'info'}->{'spaces_after_cmd_before_arg'}
          = $spaces_element;
      }
      ($line, $source_info)
       = _expand_macro_arguments($self, $expanded_macro, $line, $source_info,
                                 $macro_call_element);
    } elsif (($args_number >= 2) or ($args_number <1)) {
    # as agreed on the bug-texinfo mailing list, no warn when zero
    # arg and not called with {}.
      $self->_line_warn(sprintf(__(
   "\@%s defined with zero or more than one argument should be invoked with {}"),
                                $command), $source_info)
         if ($args_number >= 2);
    } else {
      $macro_call_element->{'type'} = $expanded_macro->{'cmdname'}.'_call_line';
      my $arg_elt = {'type' => 'line_arg',
                     'parent' => $macro_call_element};
      push @{$macro_call_element->{'args'}}, $arg_elt;
      while (1) {
        if ($line eq '') {
          ($line, $source_info) = _new_line($self, $arg_elt);
          if (!defined($line)) {
            $line = '';
            last;
          }
        } else {
          # based on whitespace_chars_except_newline in XS parser
          if (not $arg_elt->{'contents'} and $line =~ s/^([ \t\cK\f]+)//) {
            my $internal_space = {'text' => $1};
            $macro_call_element->{'info'} = {}
                if (!$macro_call_element->{'info'});
            $macro_call_element->{'info'}->{'spaces_before_argument'}
               = $internal_space;
          } else {
            my $has_end_of_line = chomp $line;
            if (not $arg_elt->{'contents'}) {
              push @{$arg_elt->{'contents'}}, {'text' => $line,
                                               'parent' => $arg_elt};
            } else {
              $arg_elt->{'contents'}->[0]->{'text'} .= $line;
            }
            if ($has_end_of_line) {
              $line = "\n";
              last;
            } else {
              $line = '';
            }
          }
        }
      }
    }
  }

  if ($error) {
    $self->{'macro_expansion_nr'}--;
    # goto funexit in XS parser
    return (undef, $line, $source_info);
  }


  my $expanded = _expand_macro_body($self,
                            $self->{'macros'}->{$command},
                            $macro_call_element->{'args'}, $source_info);

  delete $macro_call_element->{'args'}
     if (scalar(@{$macro_call_element->{'args'}}) == 0);

  my $expanded_macro_text;
  if (defined($expanded)) {
    chomp($expanded);
    $expanded_macro_text = $expanded;
  } else {
    # we want to always have a text for the source mark
    $expanded_macro_text = "";
  }

  print STDERR "MACROBODY: $expanded_macro_text".'||||||'."\n"
    if ($self->{'conf'}->{'DEBUG'});

  my $sourcemark_type;
  if ($expanded_macro->{'cmdname'} eq 'linemacro') {
    $sourcemark_type = 'linemacro_expansion';
  } else {
    $sourcemark_type = 'macro_expansion';
  }
  my $macro_source_mark = {'sourcemark_type' => $sourcemark_type,
                           'status' => 'start'};
  $macro_source_mark->{'element'} = $macro_call_element;
  _register_source_mark($self, $current, $macro_source_mark);

  # first put the line that was interrupted by the macro call
  # on the input pending text stack
  _input_push_text($self, $line, $source_info->{'line_nr'});

  # Put expansion in front of the current line.
  _input_push_text($self, $expanded_macro_text, $source_info->{'line_nr'},
                   $expanded_macro->{'args'}->[0]->{'text'});

  $self->{'input'}->[0]->{'input_source_mark'} = $macro_source_mark;

  # not really important as line is ignored by the caller if there
  # was no macro expansion error
  $line = '';

 #funexit:
  return ($macro_call_element, $line, $source_info);
}

# to have similar code with the XS parser, the only returned information
# is whether some processing was done.  The line and current element are
# passed by reference. For the current element this is achieved by putting
# the element in an array reference which is passed to the function.
sub _handle_menu_entry_separators($$$$$$)
{
  my $self = shift;
  my $current_array_ref = shift;
  my $line_ref = shift;
  my $source_info = shift;
  my $asterisk = shift;
  my $menu_separator = shift;

  my $current = $current_array_ref->[0];

  my $retval = 1;

  my $last_element;
  if ($current->{'contents'}) {
    $last_element = $current->{'contents'}->[-1];
  }

  # maybe a menu entry beginning: a * at the beginning of a menu line
  if ($current->{'type'}
      and $current->{'type'} eq 'preformatted'
      and $current->{'parent'}->{'type'}
      and ($current->{'parent'}->{'type'} eq 'menu_comment'
           or $current->{'parent'}->{'type'} eq 'menu_entry_description')
      and $asterisk
      and $last_element
      and $last_element->{'type'}
      and $last_element->{'type'} eq 'empty_line'
      and $last_element->{'text'} eq '') {
    print STDERR "MENU STAR\n" if ($self->{'conf'}->{'DEBUG'});
    $$line_ref =~ s/^\*//;
    $last_element->{'type'} = 'internal_menu_star';
    $last_element->{'text'} = '*';
  # a space after a * at the beginning of a menu line
  } elsif ($last_element
           and $last_element->{'type'}
           and $last_element->{'type'} eq 'internal_menu_star') {
    if ($$line_ref !~ /^\s+/) {
      print STDERR "ABORT MENU STAR before: "
          ._debug_protect_eol($$line_ref)."\n" if ($self->{'conf'}->{'DEBUG'});
      delete $last_element->{'type'};
    } else {
      print STDERR "MENU ENTRY (certainly)\n" if ($self->{'conf'}->{'DEBUG'});
      # this is the menu star collected previously
      my $menu_star_element = _pop_element_from_contents($self, $current);
      $$line_ref =~ s/^(\s+)//;
      my $star_leading_spaces = '*' . $1;

      if ($current->{'type'} eq 'preformatted'
          and $current->{'parent'}->{'type'}
          and $current->{'parent'}->{'type'} eq 'menu_comment') {
        # close preformatted
        $current = _close_container($self, $current, $source_info);
        # close menu_comment
        $current = _close_container($self, $current, $source_info);
      } else {
        # if in the preceding menu entry description, first parent is preformatted,
        # second is the description, third is the menu_entry
        if ($current->{'type'} ne 'preformatted'
            or $current->{'parent'}->{'type'} ne 'menu_entry_description'
            or $current->{'parent'}->{'parent'}->{'type'} ne 'menu_entry'
            or (not $block_commands{$current->{'parent'}->{'parent'}->{'parent'}
                                                  ->{'cmdname'}} eq 'menu')) {
          $self->_bug_message("Not in menu comment nor description",
                               $source_info, $current);
        }
        # close preformatted
        $current = _close_container($self, $current, $source_info);
        # close menu_description
        $current = _close_container($self, $current, $source_info);
        # close menu_entry (which cannot actually be empty).
        $current = _close_container($self, $current, $source_info);
      }

      my $menu_entry = { 'type' => 'menu_entry',
                         'parent' => $current,
                       };
      my $leading_text = { 'type' => 'menu_entry_leading_text',
                           'text' => $star_leading_spaces,
                           'parent' => $menu_entry };
      # transfer source marks from removed menu star to leading text
      _transfer_source_marks($menu_star_element, $leading_text);
      my $entry_name = { 'type' => 'menu_entry_name',
                         'parent' => $menu_entry };
      push @{$current->{'contents'}}, $menu_entry;
      push @{$menu_entry->{'contents'}}, $leading_text;
      push @{$menu_entry->{'contents'}}, $entry_name;
      $current = $entry_name;
    }
  # After a separator in a menu, end of menu entry node or menu
  # entry name (. must be followed by a space to stop the node).
  } elsif ($menu_separator
           # if menu separator is not ':', it is [,\t.]
           and (($menu_separator ne ':' and $current->{'type'}
                 and $current->{'type'} eq 'menu_entry_node')
                or ($menu_separator eq ':' and $current->{'type'}
                    and $current->{'type'} eq 'menu_entry_name'))) {
    substr($$line_ref, 0, 1) = '';
    $current = $current->{'parent'};
    push @{$current->{'contents'}}, { 'type' => 'menu_entry_separator',
                                      'text' => $menu_separator,
                                      'parent' => $current };
  # after a separator in menu
  } elsif ($last_element
           and $last_element->{'type'}
           and $last_element->{'type'} eq 'menu_entry_separator') {
    my $separator = $last_element->{'text'};
    print STDERR "AFTER menu_entry_separator $separator\n"
       if ($self->{'conf'}->{'DEBUG'});
    # Separator is ::.
    if ($separator eq ':' and $$line_ref =~ s/^(:)//) {
      $last_element->{'text'} .= $1;
      # Whitespace following the :: is subsequently appended to
      # the separator.
    # a . not followed by a space.  Not a separator.
    } elsif ($separator eq '.' and $$line_ref =~ /^\S/) {
      my $popped_element = _pop_element_from_contents($self, $current);
      $current = $current->{'contents'}->[-1];
      $current = _merge_text($self, $current, $separator, $popped_element);
    # here we collect spaces following separators.
    # based on whitespace_chars_except_newline in XS parser
    } elsif ($$line_ref =~ s/^([ \t\cK\f]+)//) {
      # NOTE a trailing end of line could be considered to be part
      # of the separator. Right now it is part of the description,
      # since it is catched (in the next while) as one of the case below
      $last_element->{'text'} .= $1;
    # :: after a menu entry name => change to a menu entry node
    } elsif ($separator =~ /^::/) {
      print STDERR "MENU NODE done (change from menu entry name) $separator\n"
          if ($self->{'conf'}->{'DEBUG'});
      # Change from menu_entry_name (i.e. a label)
      # to a menu entry node
      $current->{'contents'}->[-2]->{'type'} = 'menu_entry_node';
      $current = _enter_menu_entry_node($self, $current, $source_info);
    # a :, but not ::, after a menu entry name => end of menu entry name
    } elsif ($separator =~ /^:/) {
      print STDERR "MENU ENTRY done $separator\n"
                     if ($self->{'conf'}->{'DEBUG'});
      push @{$current->{'contents'}}, { 'type' => 'menu_entry_node',
                                        'parent' => $current };
      $current = $current->{'contents'}->[-1];
    # anything else corresponds to a separator that does not contain
    # : and is after a menu node (itself following a menu_entry_name)
    } else {
      # NOTE $$line_ref can start with an @-command in that case
      print STDERR "MENU NODE done $separator\n"
                                if ($self->{'conf'}->{'DEBUG'});
      $current = _enter_menu_entry_node($self, $current, $source_info);
    }
  } else {
    $retval = 0;
  }

  $current_array_ref->[0] = $current;

  return $retval;
}

# return values:
#     $STILL_MORE_TO_PROCESS: when there is more to process on the line
#     $GET_A_NEW_LINE: when we need to read a new line
#     $FINISHED_TOTALLY: found @bye, end of processing

my $STILL_MORE_TO_PROCESS = 0;
my $GET_A_NEW_LINE = 1;
my $FINISHED_TOTALLY = -1;

sub _handle_other_command($$$$$)
{
  my $self = shift;
  my $current = shift;
  my $command = shift;
  my $line = shift;
  my $source_info = shift;

  my $retval = $STILL_MORE_TO_PROCESS;

  # symbol skipspace other
  my $arg_spec = $nobrace_commands{$command};
  my $command_e;

  if ($arg_spec ne 'skipspace') {
    $command_e = {'cmdname' => $command, 'parent' => $current};
    push @{$current->{'contents'}}, $command_e;

    if ($in_heading_spec_commands{$command}) {
      # We check that in_heading_spec_commands are in heading_spec_commands by
      # using basic_inline_stack_on_line since heading_spec_commands are
      # contain_basic_inline commands.  We do not check that
      # in_heading_spec_commands are not in context nor special brace commands,
      # so there won't be a warning for @thischapter in @footnote for example.
      # However, heading_spec_commands being contain_basic_inline commands,
      # there should be a warning if they contain most context/special brace
      # commands such as @footnote.
      my $line_context;
      if (defined($self->{'nesting_context'}->{'basic_inline_stack_on_line'})
          and @{$self->{'nesting_context'}->{'basic_inline_stack_on_line'}} > 0) {
        $line_context
          = $self->{'nesting_context'}->{'basic_inline_stack_on_line'}->[-1];
      }
      if (!defined($line_context)
          or !$heading_spec_commands{$line_context}) {
        $self->_line_error(
          sprintf(__("\@%s should only appear in heading or footing"),
                $command), $source_info);
      }
    }
    if ($arg_spec eq 'symbol') {
      if ($command eq '\\' and $self->_top_context() ne 'ct_math') {
        $self->_line_warn(sprintf(
                   __("\@%s should only appear in math context"),
                              $command), $source_info);
      }
      if ($command eq "\n") {
        if ($self->_top_context() eq 'ct_line'
            and defined($self->{'context_command_stack'}->[-1])) {
          $self->_line_warn(
            "\@ should not occur at end of argument to line command",
            $source_info);
        }

        $current = _end_line($self, $current, $source_info);
        $retval = $GET_A_NEW_LINE;
      }
    } else { # other
      _register_global_command($self, $command_e, $source_info);
      $current = _begin_preformatted($self, $current)
        if ($close_preformatted_commands{$command});
    }
  } else {
    if ($command eq 'item'
        or $command eq 'headitem' or $command eq 'tab') {
      my $parent;
      # @itemize or @enumerate
      if ($parent = _item_container_parent($current)) {
        if ($command eq 'item') {
          print STDERR "ITEM CONTAINER\n" if ($self->{'conf'}->{'DEBUG'});
          $parent->{'items_count'}++;
          $command_e = { 'cmdname' => $command, 'parent' => $parent,
                         'extra' =>
                          {'item_number' => $parent->{'items_count'}} };
          push @{$parent->{'contents'}}, $command_e;
          $current = $parent->{'contents'}->[-1];
        } else {
          $self->_line_error(sprintf(__(
                        "\@%s not meaningful inside `\@%s' block"),
                           $command, $parent->{'cmdname'}), $source_info);
        }
        $current = _begin_preformatted($self, $current);
      # @*table
      } elsif ($parent = _item_line_parent($current)) {
        # @item and _item_line_parent is explicitly avoided in the if above
        $self->_line_error(sprintf(__(
              "\@%s not meaningful inside `\@%s' block"),
            $command, $parent->{'cmdname'}), $source_info);
        $current = _begin_preformatted($self, $current);
      # @multitable
      } elsif ($parent = _item_multitable_parent($current)) {
        if (!$parent->{'extra'}->{'max_columns'}) {
          $self->_line_warn(
             sprintf(__("\@%s in empty multitable"),
                     $command), $source_info);
        } elsif ($command eq 'tab') {
          my $row = $parent->{'contents'}->[-1];
          die if (!$row->{'type'});
          if ($row->{'type'} eq 'before_item') {
            $self->_line_error(__("\@tab before \@item"), $source_info);
          } elsif ($row->{'cells_count'} >= $parent->{'extra'}->{'max_columns'}) {
            $self->_line_error(sprintf(__(
                    "too many columns in multitable item (max %d)"),
                   $parent->{'extra'}->{'max_columns'}), $source_info);
          } else {
            $row->{'cells_count'}++;
            $command_e = { 'cmdname' => $command,
                           'parent' => $row,
                           'contents' => [],
                           'extra' =>
                              {'cell_number' => $row->{'cells_count'}} };
            push @{$row->{'contents'}}, $command_e;
            $current = $row->{'contents'}->[-1];
            print STDERR "TAB\n" if ($self->{'conf'}->{'DEBUG'});
          }
        } else {
          print STDERR "ROW\n" if ($self->{'conf'}->{'DEBUG'});
          my $row = { 'type' => 'row', 'contents' => [],
                      'cells_count' => 1,
                      'parent' => $parent };
          push @{$parent->{'contents'}}, $row;
          # Note that the "row_number" extra value
          # isn't actually used anywhere at present.
          $row->{'extra'}
              = {'row_number' => scalar(@{$parent->{'contents'}}) - 1};
          $command_e = { 'cmdname' => $command,
                         'parent' => $row,
                         'contents' => [],
                         'extra' => {'cell_number' => 1}};
          push @{$row->{'contents'}}, $command_e;
          $current = $command_e;
        }
        $current = _begin_preformatted($self, $current);
      } elsif ($command eq 'tab') {
        $self->_line_error(__(
                   "ignoring \@tab outside of multitable"), $source_info);
        $current = _begin_preformatted($self, $current);
      } else {
        $self->_line_error(sprintf(__(
           "\@%s outside of table or list"), $command), $source_info);
        $current = _begin_preformatted($self, $current);
      }
      $command_e->{'source_info'} = {%$source_info} if (defined($command_e));
    } else {
      $command_e = { 'cmdname' => $command, 'parent' => $current,
                     'source_info' => {%$source_info} };
      push @{$current->{'contents'}}, $command_e;
      if (($command eq 'indent' or $command eq 'noindent')
           and _in_paragraph($self, $current)) {
        $self->_line_warn(sprintf(__("\@%s is useless inside of a paragraph"),
                                  $command),
                          $source_info);
      }
    }
    $line = _start_empty_line_after_command($self, $line, $current, undef);
  }
  return ($current, $line, $retval, $command_e);
}

sub _handle_line_command($$$$$$)
{
  my $self = shift;
  my $current = shift;
  my $command = shift;
  my $data_cmdname = shift;
  my $line = shift;
  my $source_info = shift;

  my $retval = $STILL_MORE_TO_PROCESS;

  if ($root_commands{$data_cmdname} or $command eq 'bye') {
    $current = _close_commands($self, $current, $source_info, undef,
                               $command);
    # if the root command happens in a Texinfo fragment going through
    # parse_texi_line we are directly in the root_line document
    # root container (in this case _close_commands returned immediately),
    # and there is no parent for $current.
    # In any other situation, _close_command stops at the preceding
    # root command or in before_node_section, both being in the document
    # root container, so that there is a parent for $current, the document
    # root container.
    if (!defined($current->{'parent'})) {
      if ($current->{'type'} ne 'root_line') {
        $self->_bug_message("no parent element", $source_info, $current);
        die;
      } else {
        # TODO do we want to error out if there is a root command in
        # Texinfo fragment processed with parse_texi_line (and therefore
        # here in root_line)?
        # $self->_line_error(sprintf(__(
        #  "\@%s should not appear in Texinfo parsed as a short fragment"),
        #                            $command), $source_info);
      }
    } else {
      # in a root command or before_node_section, get to the document root
      # container.
      $current = $current->{'parent'};
    }
  }

  # text line lineraw special specific
  my $arg_spec = $self->{'line_commands'}->{$data_cmdname};

  my $command_e;

  # all the cases using the raw line
  if ($arg_spec eq 'lineraw') {
    my $ignored = 0;
    if ($command eq 'insertcopying') {
      my $parent = $current;
      while ($parent) {
        if ($parent->{'cmdname'} and $parent->{'cmdname'} eq 'copying') {
          $self->_line_error(
             sprintf(__("\@%s not allowed inside `\@copying' block"),
                     $command), $source_info);
          $ignored = 1;
          last;
        }
        $parent = $parent->{'parent'};
      }
    }

    # Complete the line if there was a user macro expansion.
    # NOTE the source marks (mostly end of macro/value expansion) will
    # be associated to the previous element in $current, as the command being
    # considered has not been added already, although the end of macro
    # expansion is located after the command opening.  Wrongly placed
    # mark sources are unavoidable, as the line is not parsed as usual
    # and macro/value expansion happen here in advance and not while
    # the remaining of the line is parsed.
    # TODO add information on the mark source to communicate that the
    # placement of mark sources is approximate?
    if ($line !~ /\n/) {
      my ($new_line, $new_line_source_info)
                 = _new_line($self, $current);
      $line .= $new_line if (defined($new_line));
    }
    $command_e = {'cmdname' => $command,
                  'parent' => $current};

    my ($args, $has_comment, $special_arg)
      = _parse_rawline_command($self, $line, $command, $source_info);
    $command_e->{'info'} = {'arg_line' => $line}
      if ($special_arg);
    # FIXME add a check that the @clickstyle argument is a glyph command
    # at that point?

    # if using the @set txi* instead of a proper @-command, replace
    # by the tree obtained with the @-command.  Even though
    # _end_line is called below, as $current is not line_arg
    # there should not be anything done in addition than what is
    # done for @clear or @set.
    if (($command eq 'set' or $command eq 'clear')
         and scalar(@$args) >= 1
         and $set_flag_command_equivalent{$args->[0]}) {
      my $arg;
      if ($command eq 'set') {
        $arg = 'on';
      } else {
        $arg = 'off';
      }
      # note that those commands are line 'specific' type.
      $command = $set_flag_command_equivalent{$args->[0]};
      $command_e = {'cmdname' => $command,
                    'parent' => $current,
                    'source_info' => $source_info,
                    'extra' => {'misc_args' => [$arg],},
                    'info' => {'spaces_before_argument' => {'text' => ' '}}};
      my $misc_line_args = {'type' => 'line_arg',
                            'parent' => $command_e,
                            'info' => {'spaces_after_argument'
                                   => {'text' => "\n",}}};
      $command_e->{'args'} = [$misc_line_args];
      $misc_line_args->{'contents'} = [
        { 'text' => $arg,
          'parent' => $misc_line_args, },
      ];
      push @{$current->{'contents'}}, $command_e;
    } else {
      if (!$ignored) {
        push @{$current->{'contents'}}, $command_e;
        if (scalar(@$args)) {
          $command_e->{'args'} = [];
          foreach my $arg (@$args) {
            push @{$command_e->{'args'}},
              { 'type' => 'rawline_arg', 'text' => $arg,
                'parent' => $current->{'contents'}->[-1] };
          }
        }
      } else {
        $command_e = undef;
      }
    }
    if ($command eq 'raisesections') {
      $self->{'sections_level_modifier'}++;
    } elsif ($command eq 'lowersections') {
      $self->{'sections_level_modifier'}--;
    }
    _register_global_command($self, $command_e, $source_info)
      if $command_e;

    # This does nothing for the command being processed, as there is
    # no line context setup nor line_args, but it closes a line or block
    # line @-commands the raw line command is on.  For c/comment
    # this corresponds to legitimate constructs, not for other raw
    # line commands.
    $current = _end_line($self, $current, $source_info);

    if ($command eq 'bye') {
      return ($current, $line, $FINISHED_TOTALLY);
      # goto funexit;  # used in XS code
    }
    # Even if _end_line is called, it is not done since there is
    # no line_arg
    $current = _begin_preformatted($self, $current)
      if ($close_preformatted_commands{$command});
    return ($current, $line, $GET_A_NEW_LINE);
    # goto funexit;  # used in XS code
  } else {
    # $arg_spec is text, line or specific
    # @item or @itemx in @table
    if ($command eq 'item' or $command eq 'itemx') {
      my $parent;
      if ($parent = _item_line_parent($current)) {
        print STDERR "ITEM LINE $command\n" if ($self->{'conf'}->{'DEBUG'});
        $current = $parent;
        _gather_previous_item($self, $current, $command, $source_info);
      } else {
        $self->_line_error(sprintf(__(
           "\@%s outside of table or list"), $command), $source_info);
        $current = _begin_preformatted($self, $current);
      }
      $command_e = { 'cmdname' => $command, 'parent' => $current };
      push @{$current->{'contents'}}, $command_e;
      $command_e->{'source_info'} = {%$source_info};
    } else {
      $command_e = { 'cmdname' => $command, 'source_info' => {%$source_info} };
      if ($command eq 'nodedescription') {
        if ($self->{'current_node'}) {
          $command_e->{'extra'} = {} if (!defined($command_e->{'extra'}));
          $command_e->{'extra'}->{'element_node'} = $self->{'current_node'};
          if ($self->{'current_node'}->{'extra'}
              and $self->{'current_node'}->{'extra'}->{'node_description'}) {
            my $set_description
              = $self->{'current_node'}->{'extra'}->{'node_description'};
            if ($set_description->{'cmdname'} eq $command) {
              $self->_line_warn(__("multiple node \@nodedescription"),
                                $source_info);
            } else {
              # silently replace nodedescriptionblock
              $self->{'current_node'}->{'extra'}->{'node_description'}
                = $command_e;
            }
          } else {
            $self->{'current_node'}->{'extra'} = {}
              if (!$self->{'current_node'}->{'extra'});
            $self->{'current_node'}->{'extra'}->{'node_description'}
              = $command_e;
          }
        } else {
          $self->_line_warn(__("\@nodedescription outside of any node"),
                            $source_info);
        }
      } elsif ($command eq 'subentry') {
        my $parent = $current->{'parent'};
        if (!_is_index_element($self, $parent)) {
          $self->_line_warn(
            sprintf(__("\@%s should only appear in an index entry"),
                    $command), $source_info);
        }
        $parent->{'extra'} = {} if (!defined($parent->{'extra'}));
        $parent->{'extra'}->{'subentry'} = $command_e;
        my $subentry_level = 1;
        if ($parent->{'cmdname'} eq 'subentry') {
          $subentry_level = $parent->{'extra'}->{'subentry_level'} + 1;
        }
        $command_e->{'extra'} = {'subentry_level' => $subentry_level,
                                 'subentry_parent' => $parent};
        if ($subentry_level > 2) {
          $self->_line_error(__(
      "no more than two levels of index subentry are allowed"),
                   $source_info);
        }
        # Do not make the @subentry element a child of the index
        # command.  This means that spaces are preserved properly
        # when converting back to Texinfo.
        $current = _end_line($self, $current, $source_info);
      } elsif ($sectioning_heading_commands{$data_cmdname}) {
        if ($self->{'sections_level_modifier'}) {
          $command_e->{'extra'}
            = {'level_modifier' => $self->{'sections_level_modifier'}};
        }
      }
      push @{$current->{'contents'}}, $command_e;
      $command_e->{'parent'} = $current;
      # def*x
      if ($def_commands{$data_cmdname}) {
        my $base_command = $command;
        $base_command =~ s/x$//;
        my $cmdname = $current->{'cmdname'};
        $cmdname = '' if !defined($cmdname);

        # check that the def*x is first after @def*, no paragraph
        # in-between.
        my $after_paragraph;
        $after_paragraph = _check_no_text($current) if $cmdname ne 'defblock';
        $self->_push_context('ct_def', $command);
        $current->{'contents'}->[-1]->{'extra'}
          = {'def_command' => $base_command,
             'original_def_cmdname' => $command,
            };
        if (defined($self->{'values'}->{'txidefnamenospace'})) {
          $current->{'contents'}->[-1]{'extra'}
                              ->{'omit_def_name_space'} = 1;
        }
        my $appropriate_command = 0;
        if ($cmdname eq $base_command or $cmdname eq 'defblock') {
          $appropriate_command = 1;
        }
        if ($appropriate_command) {
          # popped element should be the same as $command_e
          _pop_element_from_contents($self, $current);
          _gather_def_item($self, $current, $command);
          push @{$current->{'contents'}}, $command_e;
        }
        if (!$appropriate_command or $after_paragraph) {
          $self->_line_error(sprintf(__(
                               "must be after `\@%s' to use `\@%s'"),
                                  $base_command, $command), $source_info);
          $current->{'contents'}->[-1]->{'extra'}->{'not_after_command'} = 1;
        }
      }
    }
    $current = $current->{'contents'}->[-1];
    $current->{'args'} = [{ 'type' => 'line_arg',
                            'parent' => $current }];
    if ($self->{'basic_inline_commands'}
        and $self->{'basic_inline_commands'}->{$data_cmdname}) {
      push @{$self->{'nesting_context'}->{'basic_inline_stack_on_line'}},
           $command;
    }

    # 'specific' commands arguments are handled in a specific way.
    # The only other line commands that have more than one argument is
    # node, so the following condition only applies to node
    if ($arg_spec ne 'specific'
        and $commands_args_number{$command}
        and $commands_args_number{$command} > 1) {
      $current->{'remaining_args'} = $commands_args_number{$command} - 1;
    }
    if ($command eq 'author') {
      my $parent = $current;
      my $found;
      while ($parent->{'parent'}) {
        $parent = $parent->{'parent'};
        last if ($parent->{'type'}
                and $parent->{'type'} eq 'brace_command_context');
        if ($parent->{'cmdname'}) {
          if ($parent->{'cmdname'} eq 'titlepage') {
            $current->{'extra'} = {} if (!$current->{'extra'});
            $current->{'extra'}->{'titlepage'} = $parent;
            $found = 1;
          } elsif ($parent->{'cmdname'} eq 'quotation' or
              $parent->{'cmdname'} eq 'smallquotation') {
            $parent->{'extra'} = {} if (!$parent->{'extra'});
            push @{$parent->{'extra'}->{'authors'}}, $current;
            $current->{'extra'} = {} if (!$current->{'extra'});
            $current->{'extra'}->{'quotation'} = $parent;
            $found = 1;
          }
          last if ($found);
        }
      }
      if (!$found) {
        $self->_line_warn(__(
     "\@author not meaningful outside `\@titlepage' and `\@quotation' environments"),
                           $current->{'source_info'});
      }
    } elsif ($command eq 'dircategory' and $self->{'current_node'}) {
        $self->_line_warn(__("\@dircategory after first node"),
                     $source_info);
    } elsif ($command eq 'printindex') {
      # Record that @printindex occurs in this node so we know it
      # is an index node.
      if ($self->{'current_node'}) {
        $self->{'current_node'}->{'extra'} = {}
           if (!$self->{'current_node'}->{'extra'});
        $self->{'current_node'}->{'extra'}->{'isindex'} = 1;
      }
    }

    $current = $current->{'args'}->[-1];
    $self->_push_context('ct_line', $command)
      unless ($def_commands{$data_cmdname});
    $line = _start_empty_line_after_command($self, $line, $current, $command_e);
  }
  _register_global_command($self, $command_e, $source_info)
    if $command_e;
  if ($command eq 'dircategory') {
    push @{$self->{'document'}->{'commands_info'}->{'dircategory_direntry'}},
         $command_e;
  }
  return ($current, $line, $retval, $command_e);
}

sub _handle_block_command($$$$$)
{
  my $self = shift;
  my $current = shift;
  my $command = shift;
  my $line = shift;
  my $source_info = shift;

  # a menu command closes a menu_comment, but not the other
  # block commands. This won't catch menu commands buried in
  # other formats (that are incorrect anyway).
  if ($block_commands{$command} eq 'menu' and $current->{'type'}
      and ($current->{'type'} eq 'menu_comment'
           or $current->{'type'} eq 'menu_entry_description')) {

    # This is, in general, caused by @detailmenu within @menu
    if ($current->{'type'} eq 'menu_comment') {
      $current = _close_container($self, $current, $source_info);
    } else { # menu_entry_description
      $current = _close_container($self, $current, $source_info);
      if ($current->{'type'} and $current->{'type'} eq 'menu_entry') {
        $current = $current->{'parent'};
      } else {
        $self->_bug_message("menu description parent not a menu_entry",
                            $source_info, $current);
        die;
      }
    }
  }

  my $block;
  my $block_line_e;

  # the def command holds a line_def* which corresponds with the
  # definition line.  This allows to have a treatement similar
  # with def*x.
  if ($def_commands{$command}) {
    $block = { 'parent' => $current,
               'cmdname' => $command,
               'contents' => [] };
    my $def_line = {
                     'type' => 'def_line',
                     'parent' => $block,
                     'source_info' => {%$source_info},
                     'extra' =>
                       {'def_command' => $command,
                        'original_def_cmdname' => $command,
                       },
                    };
    if (defined($self->{'values'}->{'txidefnamenospace'})) {
      $def_line->{'extra'}->{'omit_def_name_space'} = 1;
    }
    push @{$block->{'contents'}}, $def_line;
    $block_line_e = $def_line;
    $self->_push_context('ct_def', $command);
  } else {
    $block = { 'cmdname' => $command,
               'parent' => $current,
             };

    if ($preformatted_commands{$command}) {
      $self->_push_context('ct_preformatted', $command);
    } elsif ($math_commands{$command}) {
      $self->_push_context('ct_math', $command);
    } elsif ($block_commands{$command} eq 'format_raw') {
      $self->_push_context('ct_rawpreformatted', $command);
    } elsif ($block_commands{$command} eq 'region') {
      push @{$self->{'nesting_context'}->{'regions_stack'}}, $command;
    } elsif ($block_commands{$command} eq 'menu') {
      $self->_push_context('ct_preformatted', $command);
      push @{$self->{'document'}->{'commands_info'}->{'dircategory_direntry'}},
           $block if ($command eq 'direntry');
      if ($self->{'current_node'}) {
        if ($command eq 'direntry') {
          if ($self->{'conf'}->{'FORMAT_MENU'} eq 'menu') {
            $self->_line_warn(__("\@direntry after first node"),
                      $source_info);
          }
        } elsif ($command eq 'menu') {
          if (!(defined($current->{'cmdname'}))
              or $root_commands{$current->{'cmdname'}}) {
            $self->{'current_node'}->{'extra'} = {}
              if (!defined($self->{'current_node'}->{'extra'}));
            $self->{'current_node'}->{'extra'}->{'menus'} = []
              if (!defined($self->{'current_node'}->{'extra'}->{'menus'}));
            push @{$self->{'current_node'}->{'extra'}->{'menus'}}, $block;
          } else {
            $self->_line_warn(__("\@menu in invalid context"),
                              $source_info);
          }
        }
      }
    } elsif ($block_commands{$command} eq 'item_container') {
    # cleaner, and more similar to XS parser, but not required, would have
    # been initialized automatically.
      $block->{'items_count'} = 0;
    } elsif ($command eq 'nodedescriptionblock') {
      if ($self->{'current_node'}) {
        $block->{'extra'} = {} if (!defined($block->{'extra'}));
        $block->{'extra'}->{'element_node'} = $self->{'current_node'};
        if ($self->{'current_node'}->{'extra'}
            and $self->{'current_node'}->{'extra'}->{'node_long_description'}) {
          $self->_line_warn(__("multiple node \@nodedescriptionblock"),
                            $source_info);
        } else {
          $self->{'current_node'}->{'extra'} = {}
            if (!$self->{'current_node'}->{'extra'});
          $self->{'current_node'}->{'extra'}->{'node_long_description'}
            = $block;
          if (!$self->{'current_node'}->{'extra'}->{'node_description'}) {
            $self->{'current_node'}->{'extra'}->{'node_description'}
              = $block;
          }
        }
      } else {
        $self->_line_warn(__("\@nodedescriptionblock outside of any node"),
                          $source_info);
      }
    }

    $block_line_e = $block;
    my $remaining_args = 0;
    if ($commands_args_number{$command}) {
      if ($commands_args_number{$command} - 1 > 0) {
        $remaining_args
          = $commands_args_number{$command} - 1;
      }
    } elsif ($variadic_commands{$command}) {
      $remaining_args = -1; # unlimited args
    }
    $block_line_e->{'remaining_args'} = $remaining_args
      if ($remaining_args);

    $self->_push_context('ct_line', $command)
  }
  $block->{'source_info'} = {%$source_info};
  push @{$current->{'contents'}}, $block;

  # bla = block line argument
  my $bla_element = {
                 'type' => 'block_line_arg',
                 'parent' => $block_line_e};

  $block_line_e->{'args'} = [$bla_element];

  if ($self->{'basic_inline_commands'}->{$command}) {
    push @{$self->{'nesting_context'}->{'basic_inline_stack_block'}},
         $command;
  }
  _register_global_command($self, $block, $source_info);
  $line = _start_empty_line_after_command($self, $line, $bla_element, $block);

  return ($bla_element, $line, $block);
}

sub _handle_brace_command($$$$)
{
  my $self = shift;
  my $current = shift;
  my $command = shift;
  my $source_info = shift;

  print STDERR "OPEN BRACE \@$command\n"
     if ($self->{'conf'}->{'DEBUG'});

  my $command_e = { 'cmdname' => $command, 'parent' => $current,};
  $command_e->{'source_info'} = {%{$source_info}};
  push @{$current->{'contents'}}, $command_e;
  # can only be sortas, which cannot be definfoenclose'd
  if ($in_index_commands{$command}
      and !_is_index_element($self, $current->{'parent'})) {
    $self->_line_warn(
      sprintf(__("\@%s should only appear in an index entry"),
              $command), $source_info);
  } elsif ($command eq 'click') { # click cannot be definfoenclose'd
    $command_e->{'extra'} = {} if (!$command_e->{'extra'});
    $command_e->{'extra'}->{'clickstyle'} = $self->{'clickstyle'};
  } else {
    if ($self->{'definfoenclose'}->{$command}) {
      $command_e->{'type'} = 'definfoenclose_command';
      $command_e->{'info'} = {} if (!$command_e->{'info'});
      $command_e->{'info'}->{'command_name'} = $command;
      $command_e->{'extra'} = {} if (!$command_e->{'extra'});
      $command_e->{'extra'}->{'begin'}
        = $self->{'definfoenclose'}->{$command}->[0];
      $command_e->{'extra'}->{'end'}
        = $self->{'definfoenclose'}->{$command}->[1];
    } elsif ($command eq 'kbd'
           and _kbd_formatted_as_code($self, $command_e)) {
      $command_e->{'extra'} = {} if (!$command_e->{'extra'});
      $command_e->{'extra'}->{'code'} = 1;
    }
  }
  $current = $command_e;
  return ($current, $command_e);
}

sub _handle_open_brace($$$$)
{
  my $self = shift;
  my $current = shift;
  my $line = shift;
  my $source_info = shift;

  if ($current->{'cmdname'}
       and defined($self->{'brace_commands'}->{$current->{'cmdname'}})) {
    my $command = $current->{'cmdname'};

    # if there is already content it is for spaces_after_cmd_before_arg
    if ($current->{'contents'}) {
      _gather_spaces_after_cmd_before_arg($self, $current);
    }

    if (defined($commands_args_number{$command})
        and $commands_args_number{$command} > 1) {
      $current->{'remaining_args'}
          = $commands_args_number{$command} - 1;
    }

    my $arg = {'parent' => $current};
    $current->{'args'} = [$arg];
    $current = $arg;
    push @{$self->{'nesting_context'}->{'basic_inline_stack'}}, $command
      if ($self->{'basic_inline_commands'}
          and $self->{'basic_inline_commands'}->{$command});
    if ($command eq 'verb') {
      $current->{'type'} = 'brace_container';
      $current->{'parent'}->{'info'} = {} if (!$current->{'parent'}->{'info'});
      if ($line eq '') {
        # the delimiter may be in macro expansion
        ($line, $source_info) = _new_line($self, $current);
      }
      if ($line =~ /^$/) {
        $current->{'parent'}->{'info'}->{'delimiter'} = '';
        $self->_line_error(
            __("\@verb without associated character"), $source_info);
      } else {
        $line =~ s/^(.)//;
        $current->{'parent'}->{'info'}->{'delimiter'} = $1;
      }
    } elsif ($self->{'brace_commands'}->{$command} eq 'context') {
      $current->{'type'} = 'brace_command_context';
      if ($command eq 'caption' or $command eq 'shortcaption') {
        my $float;
        $self->{'nesting_context'}->{'caption'} += 1;
        if (!$current->{'parent'}->{'parent'}
            or !$current->{'parent'}->{'parent'}->{'cmdname'}
            or $current->{'parent'}->{'parent'}->{'cmdname'} ne 'float') {
          $float = $current->{'parent'};
          while ($float->{'parent'} and !($float->{'cmdname'}
                                          and $float->{'cmdname'} eq 'float')) {
            $float = $float->{'parent'};
          }
          if (!($float->{'cmdname'} and $float->{'cmdname'} eq 'float')) {
            $self->_line_error(sprintf(__(
               "\@%s is not meaningful outside `\@float' environment"),
                                       $command), $source_info);
            $float = undef;
          } else {
            $self->_line_warn(sprintf(__(
                               "\@%s should be right below `\@float'"),
                                       $command), $source_info);
          }
        } else {
          $float = $current->{'parent'}->{'parent'};
        }
        if ($float) {
          if ($float->{'extra'} and $float->{'extra'}->{$command}) {
            $self->_line_warn(sprintf(__("ignoring multiple \@%s"),
                                      $command), $source_info);
          } else {
            $current->{'parent'}->{'extra'} = {}
                if (!$current->{'parent'}->{'extra'});
            $current->{'parent'}->{'extra'}->{'float'} = $float;
            $float->{'extra'} = {} if (!defined($float->{'extra'}));
            $float->{'extra'}->{$command} = $current->{'parent'};
          }
        }
      } elsif ($command eq 'footnote') {
        $self->{'nesting_context'}->{'footnote'} += 1;
      }

      my $spaces_e = {'parent' => $current};
      push @{$current->{'contents'}}, $spaces_e;

      if ($math_commands{$command}) {
        # internal_spaces_before_argument is a transient internal type,
        # which should end up in info spaces_before_argument.
        $spaces_e->{'type'} = 'internal_spaces_before_argument';
        $self->_push_context('ct_math', $command);
      } else {
        $spaces_e->{'type'} = 'internal_spaces_before_context_argument';
        $self->_push_context('ct_base', $command);
      }
      $self->{'internal_space_holder'} = $current->{'parent'};
      # based on whitespace_chars_except_newline in XS parser
      $line =~ s/([ \t\cK\f]*)//;
      $spaces_e->{'text'} = $1;
    } else {
      # Commands that disregard leading whitespace.
      if ($brace_commands{$command}
          and ($brace_commands{$command} eq 'arguments'
               or $brace_commands{$command} eq 'inline')) {
        $current->{'type'} = 'brace_arg';
        # internal_spaces_before_argument is a transient internal type,
        # which should end up in info spaces_before_argument.
        push @{$current->{'contents'}}, {
                    'type' => 'internal_spaces_before_argument',
                    'text' => '',
                    'parent' => $current,
                  };
        $self->{'internal_space_holder'} = $current;
      } else {
        $current->{'type'} = 'brace_container';
      }
      $self->_push_context('ct_inlineraw', $command)
        if ($command eq 'inlineraw');
    }
    print STDERR "OPENED \@$current->{'parent'}->{'cmdname'}, remaining: "
      .(defined($current->{'parent'}->{'remaining_args'})
          ? $current->{'parent'}->{'remaining_args'} : '0')
      .' '.Texinfo::Common::debug_print_element($current)."\n"
       if ($self->{'conf'}->{'DEBUG'});
  } elsif ($current->{'parent'}
            and (($current->{'parent'}->{'cmdname'}
                  and $current->{'parent'}->{'cmdname'} eq 'multitable')
                 or ($current->{'parent'}->{'extra'}
                     and $current->{'parent'}->{'extra'}->{'def_command'}))) {
    _abort_empty_line($self, $current);
    push @{$current->{'contents'}},
         { 'type' => 'bracketed_arg',
           'parent' => $current };
    $current = $current->{'contents'}->[-1];
    # we need the line number here in case @ protects end of line
    # and also for misplaced { errors.
    $current->{'source_info'} = {%$source_info};
    # internal_spaces_before_argument is a transient internal type,
    # which should end up in info spaces_before_argument.
    push @{$current->{'contents'}},
        {'type' => 'internal_spaces_before_argument',
         'text' => '',
         'parent' => $current,
       };
    $self->{'internal_space_holder'} = $current;

    print STDERR "BRACKETED in def/multitable\n"
                             if ($self->{'conf'}->{'DEBUG'});
  # lone braces accepted right in a rawpreformatted
  } elsif ($current->{'type'}
           and $current->{'type'} eq 'rawpreformatted') {
    print STDERR "LONE OPEN BRACE in rawpreformatted\n"
       if ($self->{'conf'}->{'DEBUG'});
    # this can happen in an expanded rawpreformatted
    $current = _merge_text($self, $current, '{');
  # matching braces accepted in a rawpreformatted, inline raw or
  # math.  Note that for rawpreformatted, it can only happen
  # within an @-command as { is simply added as seen just above.
  } elsif ($self->_top_context() eq 'ct_math'
           or $self->_top_context() eq 'ct_rawpreformatted'
           or $self->_top_context() eq 'ct_inlineraw') {
    _abort_empty_line($self, $current);
    my $balanced_braces = {'type' => 'balanced_braces',
                           'contents' => [],
                           'parent' => $current,
                           'source_info' => {%{$source_info}}};
    push @{$current->{'contents'}}, $balanced_braces;
    $current = $balanced_braces;
    my $open_brace = {'text' => '{', 'parent' => $current};
    push @{$current->{'contents'}}, $open_brace;
    print STDERR "BALANCED BRACES in math/rawpreformatted/inlineraw\n"
       if ($self->{'conf'}->{'DEBUG'});
  } else {
    $self->_line_error(sprintf(__("misplaced {")), $source_info); #}
  }

  return ($current, $line);
}

sub _handle_close_brace($$$)
{
  my $self = shift;
  my $current = shift;
  my $source_info = shift;

  print STDERR "CLOSE BRACE\n" if ($self->{'conf'}->{'DEBUG'});
  # For footnote and caption closing, when there is a paragraph inside.
  # This makes the brace command the parent element.
  if ($current->{'parent'} and $current->{'parent'}->{'type'}
      and $current->{'parent'}->{'type'} eq 'brace_command_context'
      and $current->{'type'} eq 'paragraph') {
    _abort_empty_line($self, $current);
    print STDERR "IN BRACE_COMMAND_CONTEXT end paragraph\n"
      if ($self->{'conf'}->{'DEBUG'});
    $current = _close_container($self, $current, $source_info);
  }

  if ($current->{'type'} and $current->{'type'} eq 'balanced_braces') {
    # balanced_braces happens in non paragraph context only, so merge_text
    # should not change $current
    $current = _merge_text($self, $current, '}');
    $current = $current->{'parent'};
  } elsif ($current->{'type'} and $current->{'type'} eq 'bracketed_arg') {
    _abort_empty_line($self, $current);
    $current = $current->{'parent'};
  } elsif ($current->{'parent'}
           and $current->{'parent'}->{'cmdname'}
           and exists($self->{'brace_commands'}
                                 ->{$current->{'parent'}->{'cmdname'}})) {
    _abort_empty_line($self, $current);

    my $brace_command = $current->{'parent'};
    my $closed_cmdname = $brace_command->{'cmdname'};
    my $brace_command_type = $self->{'brace_commands'}->{$closed_cmdname};

    if ($brace_command_type eq 'arguments') {
      _isolate_last_space($self, $current);
    }

    print STDERR "CLOSING(brace) \@$closed_cmdname\n"
      if ($self->{'conf'}->{'DEBUG'});

    if ($closed_cmdname eq 'anchor') {
      $brace_command->{'source_info'} = {%$source_info};
      if (! $current->{'contents'}) {
        $self->_line_error(sprintf(__("empty argument in \@%s"),
                                   $closed_cmdname), $source_info);
      } else {
        _check_register_target_element_label($self, $current,
                                             $brace_command,
                                             $source_info);
        # the @anchor element_region information is not used in converters
        if ($self->{'nesting_context'}
            and $self->{'nesting_context'}->{'regions_stack'}
       and scalar(@{$self->{'nesting_context'}->{'regions_stack'}}) > 0) {
          $current->{'extra'} = {} if (!$current->{'extra'});
          $current->{'extra'}->{'element_region'}
            = $self->{'nesting_context'}->{'regions_stack'}->[-1];
        }
      }
    } elsif ($ref_commands{$closed_cmdname}) {
      my $ref = $brace_command;
      my @args;
      for $a (@{$ref->{'args'}}) {
        if ($a->{'contents'}) {
          push @args, $a->{'contents'};
        } else {
          push @args, undef;
        }
      }
      my $link_or_inforef = ($closed_cmdname eq 'link'
                             or $closed_cmdname eq 'inforef');

      if ($link_or_inforef
           and !defined($args[0]) and !defined($args[2])
          or (!$link_or_inforef
           and !defined($args[0]) and !defined($args[3])
           and !defined($args[4]))) {
        $self->_line_warn(sprintf(__(
           "command \@%s missing a node or external manual argument"),
                              $closed_cmdname), $source_info);
      } else {
        my $arg_label = $ref->{'args'}->[0];
        my $ref_label_info
          = Texinfo::Common::parse_node_manual($arg_label, 1);
        if (defined($ref_label_info)) {
          foreach my $label_info (keys(%$ref_label_info)) {
            $arg_label->{'extra'} = {} if (!$arg_label->{'extra'});
            $arg_label->{'extra'}->{$label_info}
              = $ref_label_info->{$label_info};
          }
          if (!$link_or_inforef
                and !defined($args[3]) and !defined($args[4])
                and !$ref_label_info->{'manual_content'}
              or $link_or_inforef and !defined($args[2])) {
            # we use the @*ref command here and not the label command
            # to have more information for messages
            push @{$self->{'document'}->{'internal_references'}}, $ref;
          }
        }
      }
      if (defined($args[1])) {
        if (_check_empty_expansion($args[1])) {
          $self->_line_warn(sprintf(__(
          "in \@%s empty cross reference name after expansion `%s'"),
                $closed_cmdname,
                Texinfo::Convert::Texinfo::convert_to_texinfo(
                                          {'contents' => $args[1]})),
                  $source_info);
        }
      }
      if (!$link_or_inforef and defined($args[2])) {
        if (_check_empty_expansion($args[2])) {
          $self->_line_warn(sprintf(__(
           "in \@%s empty cross reference title after expansion `%s'"),
                $closed_cmdname,
                Texinfo::Convert::Texinfo::convert_to_texinfo(
                                        {'contents' => $args[2]})),
                  $source_info);
        }
      }
    } elsif ($closed_cmdname eq 'image') {
      my $image = $brace_command;
      if (!$image->{'args'}->[0]->{'contents'}) {
        $self->_line_error(
           __("\@image missing filename argument"), $source_info);
      }
      my $document = $self->{'document'};
      if (defined($document->{'global_info'}->{'input_encoding_name'})) {
        $image->{'extra'} = {} if (!$image->{'extra'});
        $image->{'extra'}->{'input_encoding_name'}
           = $document->{'global_info'}->{'input_encoding_name'};
      }
    } elsif ($closed_cmdname eq 'dotless') {
      my $dotless = $brace_command;
      if ($current->{'contents'}) {
        my $text = $current->{'contents'}->[0]->{'text'};
        if (!defined($text)
          or ($text ne 'i' and $text ne 'j')) {
          $self->_line_error(sprintf(
                __("\@dotless expects `i' or `j' as argument, not `%s'"),
                Texinfo::Convert::Texinfo::convert_to_texinfo($current)),
              $source_info);
        }
      }
    } elsif ($explained_commands{$closed_cmdname}
             or ($brace_commands{$closed_cmdname}
                 and $brace_commands{$closed_cmdname} eq 'inline')) {
      if (!$brace_command->{'args'}->[0]->{'contents'}) {
        $self->_line_warn(
           sprintf(__("\@%s missing first argument"),
                   $closed_cmdname), $source_info);
      }
    } elsif ($closed_cmdname eq 'errormsg') {
      my $arg_text = '';
      if ($current->{'contents'}
          and defined($current->{'contents'}->[0]->{'text'})) {
        $arg_text = $current->{'contents'}->[0]->{'text'};
      }
      $self->_line_error($arg_text, $source_info);
    } elsif ($closed_cmdname eq 'U') {
      my $arg_text;
      if ($current->{'contents'}) {
        $arg_text = $current->{'contents'}->[0]->{'text'};
      }
      if (!defined($arg_text) or $arg_text eq '') {
        $self->_line_warn(__("no argument specified for \@U"), $source_info);
      } elsif ($arg_text !~ /^[0-9A-Fa-f]+$/) {
        $self->_line_error(sprintf(__(
                    "non-hex digits in argument for \@U: %s"), $arg_text),
                           $source_info);
      } elsif (length($arg_text) < 4) {
        # Perl doesn't mind, but too much trouble to do in TeX.
        $self->_line_warn(sprintf(__(
          "fewer than four hex digits in argument for \@U: %s"), $arg_text),
                          $source_info);
      } else {
        # we don't want to call hex at all if the value isn't
        # going to fit; so first use eval to check.
        # Since integer overflow is only a warning, have to make
        # warnings fatal for the eval to be effective.
        eval qq!use warnings FATAL => qw(all); hex("$arg_text")!;
        if ($@) {
          # leave clue in case something else went wrong.
          warn "\@U hex($arg_text) eval failed: $@\n"
                             if ($self->{'conf'}->{'DEBUG'});
          # argument likely exceeds size of integer
        }
        # ok, value can be given to hex(), so try it.
        if ($@ or hex($arg_text) > 0x10FFFF) {
          $self->_line_error(sprintf(__(
             "argument for \@U exceeds Unicode maximum 0x10FFFF: %s"),
             $arg_text),
                             $source_info);
        }
      }
    } elsif (_parent_of_command_as_argument($brace_command->{'parent'})
             and !$current->{'contents'}) {
      _register_command_as_argument($self, $brace_command);
    } elsif ($brace_command_type eq 'noarg') {
      if ($current->{'contents'}) {
        $self->_line_warn(sprintf(__(
                          "command \@%s does not accept arguments"),
                               $closed_cmdname), $source_info);
      }
    } elsif ($in_index_commands{$closed_cmdname}) {

      my $subindex_element = $brace_command->{'parent'}->{'parent'};
      if ($subindex_element
          and _is_index_element($self, $subindex_element)) {
        if ($closed_cmdname eq 'sortas') {
          my ($arg, $superfluous_arg) = _text_contents_to_plain_text($current);
          if (defined($arg)) {
            $subindex_element->{'extra'} = {}
              if (!defined($subindex_element->{'extra'}));
            $subindex_element->{'extra'}->{$closed_cmdname} = $arg;
          }
        } else {
          my $index_element = $subindex_element;
          while ($index_element->{'cmdname'} eq 'subentry'
                 and $index_element->{'extra'}
                 and $index_element->{'extra'}->{'subentry_parent'}) {
            $index_element = $index_element->{'extra'}->{'subentry_parent'};
          }
          $index_element->{'extra'} = {}
            if (!defined($index_element->{'extra'}));
          $index_element->{'extra'}->{$closed_cmdname} = $brace_command;
        }
      }
    }

    _register_global_command($self, $brace_command, $source_info);

    # this should set $current to $brace_command->parent
    $current = _close_brace_command($self, $brace_command,
                                    $source_info);

    if ($command_ignore_space_after{$closed_cmdname}) {
      push @{$current->{'contents'}},
         {'type' => 'spaces_after_close_brace',
          'text' => '',
          'parent' => $current
         };
    }

    $current = _begin_preformatted($self, $current)
       if ($close_preformatted_commands{$closed_cmdname});
  # lone braces accepted right in a rawpreformatted
  } elsif ($current->{'type'}
           and $current->{'type'} eq 'rawpreformatted') {
    $current = _merge_text($self, $current, '}');
  } else {
    $self->_line_error(sprintf(__("misplaced }")), $source_info);
  }
  return $current;
}

sub _handle_comma($$$$)
{
  my $self = shift;
  my $current = shift;
  my $line = shift;
  my $source_info = shift;

  _abort_empty_line($self, $current);
  _isolate_last_space($self, $current);
  # type corresponds to three possible containers: in brace commands,
  # line of block command (float or example) or line (node).
  my $type = $current->{'type'};
  #die ("type: $type\n") if ($type ne 'brace_container'
  #                          and $type ne 'brace_arg'
  #                          and $type ne 'block_line_arg'
  #                          and $type ne 'line_arg');
  my $brace_command = $current->{'parent'};

  $brace_command->{'remaining_args'}--;

  if ($brace_commands{$brace_command->{'cmdname'}}
      and $brace_commands{$brace_command->{'cmdname'}} eq 'inline') {
    my $expandp = 0;
    $brace_command->{'extra'} = {} if (!$brace_command->{'extra'});
    if (! $brace_command->{'extra'}->{'format'}) {
      my $inline_type;
      # get the first argument, which is also $current, which was before the comma
      # and put it in extra format
      if ($current->{'contents'}) {
        $inline_type = $current->{'contents'}->[0]->{'text'};
      }

      if (!defined($inline_type) or $inline_type eq '') {
        # condition is missing for some reason
        print STDERR "INLINE COND MISSING\n"
          if ($self->{'conf'}->{'DEBUG'});
      } else {
        print STDERR "INLINE: $inline_type\n" if ($self->{'conf'}->{'DEBUG'});
        if ($inline_format_commands{$brace_command->{'cmdname'}}) {
          if ($self->{'expanded_formats_hash'}->{$inline_type}) {
            $expandp = 1;
            $brace_command->{'extra'}->{'expand_index'} = 1;
          } else {
            $expandp = 0;
          }
        } elsif (($brace_command->{'cmdname'} eq 'inlineifset'
                  and exists($self->{'values'}->{$inline_type}))
                 or ($brace_command->{'cmdname'} eq 'inlineifclear'
                     and ! exists($self->{'values'}->{$inline_type}))) {
          $expandp = 1;
          $brace_command->{'extra'}->{'expand_index'} = 1;
        } else {
          $expandp = 0;
        }
      }
      $brace_command->{'extra'}->{'format'} = $inline_type;

      # Skip first argument for a false @inlinefmtifelse
      if (!$expandp and $brace_command->{'cmdname'} eq 'inlinefmtifelse') {
        $brace_command->{'extra'}->{'expand_index'} = 2;

        my $elided_arg_elt = {'type' => 'elided_brace_command_arg',
                              'contents' => [],
                              'parent' => $brace_command,};
        push @{$brace_command->{'args'}}, $elided_arg_elt;
        my $arg_text_e = {'type' => 'raw', 'text' => '',
                          'parent' => $elided_arg_elt};
        push @{$elided_arg_elt->{'contents'}}, $arg_text_e;

        # Scan forward to get the next argument.
        my $brace_count = 1;
        while ($brace_count > 0) {
          # Forward to next comma or brace
          if ($line =~ s/([^{,}]*)([,{}])//) {
            $arg_text_e->{'text'} .= $1;
            my $delimiter = $2;
            if ($delimiter eq ',') {
              if ($brace_count == 1) {
                $brace_command->{'remaining_args'}--;
                last;
              }
              $arg_text_e->{'text'} .= $delimiter;
            } elsif ($delimiter eq '{') {
              $brace_count++;
              $arg_text_e->{'text'} .= $delimiter;
            } elsif ($delimiter eq '}') {
              $brace_count--;
              $arg_text_e->{'text'} .= $delimiter if ($brace_count);
            }
          } else {
            $arg_text_e->{'text'} .= $line;
            ($line, $source_info)
            # there is a test a situation with macro call closing in ignored
            # @inlinefmtifelse first part (not counting the format):
            # t/*macro.t macro_end_call_in_ignored_inlinefmtifelse.
               = _next_text($self, $elided_arg_elt);
            if (not defined($line)) {
              # error - unbalanced brace
              return ($elided_arg_elt, $line, $source_info, $GET_A_NEW_LINE);
              # goto funexit;  # used in XS code
            }
          }
        }
        if ($brace_count == 0) {
          # Second part (not counting the format) is missing.
          $line = '}' . $line;
          return ($elided_arg_elt, $line, $source_info);
          # goto funexit;  # used in XS code
        }
        # start of the second @inlinefmtifelse part (not counting the format)
        # when condition is false.  Keep it.
        $expandp = 1;
      }
    } elsif ($brace_command->{'cmdname'} eq 'inlinefmtifelse') {
      # Second part of @inlinefmtifelse (not counting the format) when
      # condition is true. Discard second part.
      $expandp = 0;
    }
    # If this command is not being expanded, add an elided argument,
    # and scan forward to the closing brace.
    if (!$expandp) {
      my $elided_arg_elt = {'type' => 'elided_brace_command_arg',
                            'contents' => [],
                            'parent' => $brace_command,};
      push @{$brace_command->{'args'}}, $elided_arg_elt;
      my $arg_text_e = {'type' => 'raw', 'text' => '',
                        'parent' => $elided_arg_elt};
      push @{$elided_arg_elt->{'contents'}}, $arg_text_e;

      my $brace_count = 1;
      while ($brace_count > 0) {
        if ($line =~ s/([^{}]*)([{}])//) {
          $arg_text_e->{'text'} .= $1;
          my $delimiter = $2;
          if ($delimiter eq '{') {
            $brace_count++;
            $arg_text_e->{'text'} .= $delimiter;
          } else {
            $brace_count--;
            $arg_text_e->{'text'} .= $delimiter if ($brace_count);
          }
        } else {
          $arg_text_e->{'text'} .= $line;
          # test for a situation with macro call end in ignored
          # @inline* last arg are in
          # t/*macro.t macro_end_call_in_ignored_inlinefmt
          # t/*macro.t macro_end_call_in_ignored_inlineraw
          # t/*macro.t macro_end_call_in_ignored_inlinefmtifelse_else
          ($line, $source_info)
             = _next_text($self, $elided_arg_elt);
          if (not defined($line)) {
            # error - unbalanced brace
            return ($elided_arg_elt, $line, $source_info, $GET_A_NEW_LINE);
            # goto funexit;  # used in XS code
          }
        }
      }
      $line = '}' . $line;
      return ($elided_arg_elt, $line, $source_info);
      # goto funexit;  # used in XS code
    }
  }
  my $new_arg = {'type' => $type, 'parent' => $brace_command, 'contents' => []};
  push @{$brace_command->{'args'}}, $new_arg;
  # internal_spaces_before_argument is a transient internal type,
  # which should end up in info spaces_before_argument.
  my $space_before = {'type' => 'internal_spaces_before_argument',
                      'text' => '', 'parent' => $new_arg,
                     };
  $self->{'internal_space_holder'} = $new_arg;
  push @{$new_arg->{'contents'}}, $space_before;

  return ($new_arg, $line, $source_info);
}

sub _new_macro($$$)
{
  my $self = shift;
  my $name = shift;
  my $current = shift;

  return if $self->{'conf'}->{'NO_USER_COMMANDS'};

  my $macrobody;
  if (defined($current->{'contents'})) {
    $macrobody =
       Texinfo::Convert::Texinfo::convert_to_texinfo(
                    { 'contents' => $current->{'contents'} });
  }
  $self->{'macros'}->{$name} = {
    'element' => $current,
    'macrobody' => $macrobody
  };
  delete $self->{'aliases'}->{$name};
  # could be cleaner to delete definfoenclose'd too, but macros
  # are expanded earlier
}

sub _process_macro_block_contents($$)
{
  my $self = shift;
  my $current = shift;

  my ($line, $source_info) = _next_text($self, $current);

  while (1) {
    if (!defined($line)) {
      # unclosed block
      # Error for unclosed raw block commands (except for the first level)
      while (@{$self->{'macro_block_stack'}}) {
        my $end_macro_block = pop @{$self->{'macro_block_stack'}};
        $self->_line_error(sprintf(__("expected \@end %s"), $end_macro_block),
                           $source_info);
      }
      return (undef, $source_info);
    }
    # r?macro may be nested
    if ($line =~ /^\s*\@((line|r)?macro)\s+/) {
      push @{$self->{'macro_block_stack'}}, $1;
      print STDERR "RAW SECOND LEVEL $1 in \@$current->{'cmdname'}\n"
        if ($self->{'conf'}->{'DEBUG'});
    } elsif ($line =~ /^(\s*?)\@end\s+([a-zA-Z][\w-]*)/
             and ((scalar(@{$self->{'macro_block_stack'}}) > 0
                   and $2 eq $self->{'macro_block_stack'}->[-1])
                  or (scalar(@{$self->{'macro_block_stack'}}) == 0
                      and $2 eq $current->{'cmdname'}))) {
      if (scalar(@{$self->{'macro_block_stack'}}) == 0) {
        if ($line =~ s/^(\s+)//) {
          push @{$current->{'contents'}},
            { 'text' => $1,
              'type' => 'raw', 'parent' => $current };
          $self->_line_warn(sprintf(
                __("\@end %s should only appear at the beginning of a line"),
                                   $current->{'cmdname'}), $source_info);
        }
        if ($current->{'args'} and $current->{'args'}->[0]) {
          my $name = $current->{'args'}->[0]->{'text'};
          if (exists($self->{'macros'}->{$name})) {
            $self->_line_warn(sprintf(__("macro `%s' previously defined"),
                                      $name), $current->{'source_info'});
            $self->_line_warn(sprintf(__(
                               "here is the previous definition of `%s'"),
           $name), $self->{'macros'}->{$name}->{'element'}->{'source_info'});
          }
          if ($all_commands{$name}
              or ($name eq 'txiinternalvalue'
                  and $self->{'conf'}->{'accept_internalvalue'})) {
            $self->_line_warn(sprintf(__(
                              "redefining Texinfo language command: \@%s"),
                                      $name), $current->{'source_info'});
          }
          if (!($current->{'extra'}
                and $current->{'extra'}->{'invalid_syntax'})) {
            _new_macro($self, $name, $current);
          }
        }
        print STDERR "CLOSED user-defined $current->{'cmdname'}\n"
                                     if ($self->{'conf'}->{'DEBUG'});
        # start a new line for the @end line (without the first spaces on
        # the line that have already been put in a raw container).
        # This is normally done at the beginning of a line, but not here,
        # as we directly got the line.  As the @end is processed just below,
        # an empty line will not appear in the output, but it is needed to
        # avoid a duplicate warning on @end not appearing at the beginning
        # of the line
        push @{$current->{'contents'}}, { 'type' => 'empty_line',
                                          'text' => '',
                                          'parent' => $current };
        last;
      } else {
        my $closed_cmdname = pop @{$self->{'macro_block_stack'}};
      }
    }
    push @{$current->{'contents'}},
      { 'text' => $line, 'type' => 'raw', 'parent' => $current };

    ($line, $source_info) = _next_text($self, $current);
  }
  return ($line, $source_info);
}

# get input text to until the @end of raw block command, return the
# @end line.
sub _process_raw_block_contents($$)
{
  my $self = shift;
  my $current = shift;
  my $cmdname = $current->{'cmdname'};

  print STDERR "BLOCK raw or ignored $cmdname\n"
    if ($self->{'DEBUG'});

  my ($line, $source_info) = _next_text($self, $current);

  my $level = 1;

  while (1) {
    if (!defined($line)) {
      # unclosed block
      # no warning for the top-level @-command, there will be one
      # when closing the command
      while ($level > 1) {
        $self->_line_error(sprintf(__("expected \@end %s"), $cmdname),
                           $source_info);
        $level--;
      }
      return (undef, $source_info);
    }
    if ($line =~ /^\s*\@($cmdname)(\@|\s+)/) {
      $level++;
      print STDERR "RAW SECOND LEVEL \@$cmdname\n"
        if ($self->{'conf'}->{'DEBUG'});
    } elsif ($line =~ /^(\s*?)\@end\s+([a-zA-Z][\w-]*)/
             and $2 eq $cmdname) {
      $level--;
      if ($level == 0) {
        if ($line =~ s/^(\s+)//) {
          push @{$current->{'contents'}},
            { 'text' => $1,
              'type' => 'raw', 'parent' => $current };
          $self->_line_warn(sprintf(
                __("\@end %s should only appear at the beginning of a line"),
                                   $cmdname), $source_info);
        }
        print STDERR "CLOSED raw or ignored $cmdname\n"
                                     if ($self->{'conf'}->{'DEBUG'});
        # start a new line for the @end line (without the first spaces on
        # the line that have already been put in a raw container).
        # This is normally done at the beginning of a line, but not here,
        # as we directly got the line.  As the @end is processed just below,
        # an empty line will not appear in the output, but it is needed to
        # avoid a duplicate warning on @end not appearing at the beginning
        # of the line
        push @{$current->{'contents'}}, { 'type' => 'empty_line',
                                          'text' => '',
                                          'parent' => $current };
        last;
      }
    }
    push @{$current->{'contents'}},
      { 'text' => $line, 'type' => 'raw', 'parent' => $current };

    ($line, $source_info) = _next_text($self, $current);
  }
  return ($line, $source_info);
}

sub _process_ignored_raw_format_block_contents($$)
{
  my $self = shift;
  my $current = shift;

  # we proceed with an internal loop here as there cannot be any
  # expansion within an ignored format_raw.  We leave the @end line
  # in line and do not change retval to have the @end line be processed
  # by the following call to process_remaining_on_line
  my ($line, $source_info) = _next_text($self, $current);

  my $e_elided_rawpreformatted = {'type' => 'elided_rawpreformatted',
                                 'parent' => $current };
  push @{$current->{'contents'}}, $e_elided_rawpreformatted;
  while (1) {
  # A source mark here is tested in t/*macro.t macro_end_call_in_ignored_raw
    if (!defined($line)) {
      # unclosed block
      return ($line, $source_info);
    } elsif ($line =~ /^\s*\@end\s+$current->{'cmdname'}/) {
      print STDERR "CLOSED ignored raw preformated $current->{'cmdname'}\n"
        if ($self->{'conf'}->{'DEBUG'});
      last;
    } else {
      my $raw_text = {'type' => 'raw', 'text' => $line,
                      'parent' => $e_elided_rawpreformatted};
      push @{$e_elided_rawpreformatted->{'contents'}}, $raw_text;
    }
    ($line, $source_info) = _new_line($self, $e_elided_rawpreformatted);
  }
  # start a new line for the @end line, this is normally done
  # at the beginning of a line, but not here, as we directly
  # got the line.
  # based on whitespace_chars_except_newline in XS parser
  $line =~ s/^([ \t\cK\f]*)//;
  push @{$current->{'contents'}}, { 'type' => 'empty_line',
                                    'text' => $1,
                                    'parent' => $current };
  return ($line, $source_info);
}

sub _process_remaining_on_line($$$$)
{
  my $self = shift;
  my $current = shift;
  my $line = shift;
  my $source_info = shift;

  my $retval = $STILL_MORE_TO_PROCESS;

  #print STDERR "PROCESS "._debug_protect_eol($line)."\n"
  #    if ($self->{'conf'}->{'DEBUG'});

  # this mostly happens in the following cases:
  #   after expansion of user defined macro that doesn't end with EOL
  #   after a protection of @\n in @def* line
  #   at the end of an expanded Texinfo fragment
  while ($line eq '') {
    print STDERR "EMPTY TEXT in: "
     .Texinfo::Common::debug_print_element($current)."\n"
      if ($self->{'conf'}->{'DEBUG'});
    ($line, $source_info) = _next_text($self, $current);
    if (!defined($line)) {
      # End of the file or of a text fragment.
      print STDERR "NO MORE LINE for empty text\n"
                            if ($self->{'conf'}->{'DEBUG'});
      return ($current, $line, $source_info, $retval);
      # goto funexit;  # used in XS code
    }
    # this shows beginning of lines (right after 'empty_line') with
    # _next_text obtained.  This new text therefore does not
    # go through _parse_texi code that happens at the beginning
    # of lines, mostly checking cpp directives.
    # elsif ($current->{'contents'} and @{$current->{'contents'}}
    #        and $current->{'contents'}->[-1]->{'type'}
    #        and $current->{'contents'}->[-1]->{'type'} eq 'empty_line'
    #        and $line ne '') {
    #  my $macro_name = '';
    #  $macro_name = $source_info->{'macro'}
    #                   if (defined($source_info->{'macro'}));
    #  print STDERR "New text in empty line $source_info->{'line_nr'}.$macro_name !$line!\n";
    #}
  }

  my $command_length;
  my @line_parsing = _parse_texi_regex($line);
  my ($arobase, $open_brace, $close_brace, $comma,
      $asterisk, $form_feed, $menu_only_separator, $misc_text)
        = @line_parsing;
  my $menu_separator = $comma;
  $menu_separator = $menu_only_separator if (!$comma);
  print STDERR "PARSED: "
    .join(', ',map {!defined($_) ? 'UNDEF' : "'$_'"} @line_parsing)."\n"
       if ($self->{'conf'}->{'DEBUG'} and $self->{'conf'}->{'DEBUG'} > 3);

  my $macro_call_element;
  my $command;
  my $at_command;
  my $from_alias;
  if ($arobase) {

    my $is_single_letter;
    my $command_string = $line;
    substr($command_string, 0, 1) = '';
    ($command, $is_single_letter) = _parse_command_name($command_string);

    if (defined($command)) {
      $command_length = length($command) +1;
    } else {
      substr($line, 0, 1) = '';
      # @ was followed by gibberish or by nothing, for instance at the
      # very end of a string/file.
      $self->_line_error(__("unexpected \@"), $source_info);
      return ($current, $line, $source_info, $retval);
      # goto funexit;  # used in XS code
    }

    if (! $is_single_letter) {
      if (exists($self->{'aliases'}->{$command})) {
        $from_alias = $command;
        $command = $self->{'aliases'}->{$from_alias};
      }

      # handle user defined macros before anything else since
      # their expansion may lead to changes in the line
      if ($self->{'macros'}->{$command}) {
        my $arg_line = $line;
        substr($arg_line, 0, $command_length) = '';

        ($macro_call_element, $arg_line, $source_info)
          = _handle_macro($self, $current, $arg_line, $source_info, $command);
        if ($macro_call_element) {
          if ($from_alias) {
            $macro_call_element->{'info'} = {}
               if (!$macro_call_element->{'info'});
            $macro_call_element->{'info'}->{'alias_of'} = $from_alias;
          }
        }
        $line = $arg_line;
        if ($macro_call_element) {
          # directly get the following input (macro expansion text) instead
          # of going through the next call of process_remaining_on_line and
          # the processing of empty text.  No difference in output, more
          # efficient.

          ($line, $source_info) = _next_text($self, $current);

        }
        return ($current, $line, $source_info, $retval);
        # goto funexit;  # used in XS code
      }
      # expand value if it can change the line.  It considered again
      # together with other commands below for all the other cases
      # which may need a well formed tree, which is not needed here, and
      # early value expansion may be needed to provide with an argument.
      if ($command eq 'value') {
        my $remaining_line = $line;
        substr($remaining_line, 0, $command_length) = '';
        my $spaces_element;
        if ($self->{'conf'}->{'IGNORE_SPACE_AFTER_BRACED_COMMAND_NAME'}
            and $remaining_line =~ s/^(\s+)//) {
          $spaces_element = {'text' => $1};
        }
        # REVALUE
        if ($remaining_line =~ s/^{([\w\-][^\s{\\}~`\^+"<>|@]*)}//) {
          my $value = $1;
          if (exists($self->{'values'}->{$value})) {
            if ($self->{'conf'}->{'MAX_MACRO_CALL_NESTING'}
                and $self->{'value_expansion_nr'}
                         >= $self->{'conf'}->{'MAX_MACRO_CALL_NESTING'}) {
              $self->_line_warn(sprintf(__(
 "value call nested too deeply (set MAX_MACRO_CALL_NESTING to override; current value %d)"),
                       $self->{'conf'}->{'MAX_MACRO_CALL_NESTING'}), $source_info);
              $line = $remaining_line;
              return ($current, $line, $source_info, $retval);
              # goto funexit;  # used in XS code
            }
            $self->{'value_expansion_nr'}++;
            _input_push_text($self, $remaining_line, $source_info->{'line_nr'});
            _input_push_text($self, $self->{'values'}->{$value},
                             $source_info->{'line_nr'}, undef, $value);
            my $sm_value_element = _new_value_element($command, $value, undef,
                                                      $spaces_element);
            my $value_source_mark = {'sourcemark_type' => 'value_expansion',
                                     'status' => 'start',
                                     'line' => $self->{'values'}->{$value},
                                     'element' => $sm_value_element};
            _register_source_mark($self, $current, $value_source_mark);
            $self->{'input'}->[0]->{'input_source_mark'} = $value_source_mark;
            $line = '';
            return ($current, $line, $source_info, $retval);
            # goto funexit;  # used in XS code
          }
        }
      }
    }
  }

  # special case for @-command as argument of @itemize or @*table.
  # The normal case for those are to be identifier only, not a true command
  # with argument, so can be followed by anything.  If followed by
  # braces, will be handled as a normal brace command.
  #
  # Need to be done as early as possible such that no other condition
  # prevail and lead to a missed command
  if ($current->{'cmdname'}
      and defined($self->{'brace_commands'}->{$current->{'cmdname'}})
      and not $self->{'brace_commands'}->{$current->{'cmdname'}} eq 'accent'
      and !$open_brace
      and _parent_of_command_as_argument($current->{'parent'})) {
    _register_command_as_argument($self, $current);
    $current = $current->{'parent'};
  }

  # command but before an opening brace, otherwise $current
  # would be an argument type and not the command, and a new
  # @-command was found.  This means that the $current->{'cmdname'}
  # argument (an opening brace, or a character after spaces for
  # accent commands) was not found and there is already a new command.
  #
  # NOTE the last element in the current command contents is an element that
  # is transiently in the tree, and is put in the info hash by
  # _gather_spaces_after_cmd_before_arg.  It could therefore be possible
  # to accept an @comment here and put it in this element.  It would not
  # necessarily be a good idea, as it would mean having an element
  # in the info hash that holds something more complex than text and source
  # marks.
  if ($command
      and $current->{'cmdname'}
      and defined($self->{'brace_commands'}->{$current->{'cmdname'}})) {
    $self->_line_error(sprintf(__("\@%s expected braces"),
                       $current->{'cmdname'}), $source_info);
    if ($current->{'contents'}) {
      _gather_spaces_after_cmd_before_arg($self, $current);
    }
    $current = $current->{'parent'};
  }

  # handle unknown @-command
  if (defined($command) and !$all_commands{$command}
      and !$self->{'definfoenclose'}->{$command}
      and !$self->{'index_entry_commands'}->{$command}
      # @txiinternalvalue is invalid unless accept_internalvalue is set
      and !($command eq 'txiinternalvalue'
            and $self->{'conf'}->{'accept_internalvalue'})
      and !$macro_call_element) {
    $self->_line_error(sprintf(__("unknown command `%s'"),
                                  $command), $source_info);
    substr($line, 0, $command_length) = '';
    return ($current, $line, $source_info, $retval);
    # goto funexit;  # used in XS code
  }

  # this is used to pass $current to a function that can modify
  # it by replacing the array content.
  my @current_array_for_ref = ($current);

  # Brace commands not followed immediately by a brace
  # opening.  In particular cases that may lead to "command closing"
  # or following character association with an @-command, for accent
  # commands.

  # This condition can only happen immediately after the command opening,
  # otherwise the current element is in the 'args' and not right in the
  # command container.
  if ($current->{'cmdname'}
        and defined($self->{'brace_commands'}->{$current->{'cmdname'}})
        and !$open_brace) {

    print STDERR "BRACE CMD: no brace after \@$current->{'cmdname'}"
       ."||| "._debug_protect_eol($line)."\n"
           if ($self->{'conf'}->{'DEBUG'});

    # Note that non ascii spaces do not count as spaces
    if ($line =~ /^(\s+)/
        and ($accent_commands{$current->{'cmdname'}}
             or $self->{'conf'}->{'IGNORE_SPACE_AFTER_BRACED_COMMAND_NAME'})) {
      my $added_space = $1;
      my $additional_newline;
      if ($added_space =~ /\n/) {
        $self->_line_warn(sprintf(
           __("command `\@%s' must not be followed by new line"),
           $current->{'cmdname'}), $source_info);
        my $top_context = $self->_top_context();
        if (($top_context eq 'ct_line'
             and defined($self->{'context_command_stack'}->[-1]))
            or $top_context eq 'ct_def') {
          # do not consider the end of line to be possibly between
          # the @-command and the argument if at the end of a
          # line or block @-command.
          if ($current->{'contents'}) {
            # this can only happen if the spaces gathered after the command
            # before the braces were interrupted before the end of line, which
            # can happen if there is a macro expansion that ends before the end
            # of line.
            # Tested in macro line_end_accent_command_macro_call
            _gather_spaces_after_cmd_before_arg($self, $current);
          }
          $current = $current->{'parent'};
          $current = _merge_text($self, $current, $added_space);
          _isolate_last_space($self, $current);
          $current = _end_line($self, $current, $source_info);
          return ($current, $line, $source_info, $GET_A_NEW_LINE);
          # goto funexit;  # used in XS code
        }
        $additional_newline = 1;
      }
      if (!$current->{'contents'}) {
        $line =~ s/^(\s+)//;
        my $spaces_after_command = $1;
        # The added element is only transiently present, it is removed
        # by calls of gather_spaces_after_cmd_before_arg, which transfer
        # the element to the info hash.  The contents allow to have source
        # marks easily associated.
        # The type name is not used anywhere but can be useful for
        # debugging, in particular to check that the element does not
        # appear anywhere in the tree.
        # Note that contents is transiently set for brace commands, which in
        # general only have args.
        my $e_spaces_after_cmd_before_arg
           = {'type' => 'internal_spaces_after_cmd_before_arg',
              'text' => $spaces_after_command, 'parent' => $current};
        $current->{'contents'} = [$e_spaces_after_cmd_before_arg];
        if ($self->{'conf'}->{'DEBUG'}) {
          my $spaces_after_command_str = $spaces_after_command;
          $spaces_after_command_str =~ s/\n/\\n/g;
          print STDERR "BRACE CMD before brace init spaces ".
                 "'$spaces_after_command_str'\n";
        }
      } else {
        # contents, at this point can only be for spaces_after_cmd_before_arg
        if ($additional_newline
            and $current->{'contents'}->[0]->{'text'} =~ /\n/) {
          # only ignore spaces and one newline, two newlines lead to
          # an empty line before the brace or argument which is incorrect.
          print STDERR "BRACE CMD before brace second newline stops spaces\n"
            if $self->{'conf'}->{'DEBUG'};
          $self->_line_error(sprintf(__("\@%s expected braces"),
                             $current->{'cmdname'}), $source_info);
          _gather_spaces_after_cmd_before_arg($self, $current);
          $current = $current->{'parent'};
        } else {
          $line =~ s/^(\s+)//;
          $current->{'contents'}->[0]->{'text'} .= $added_space;
          print STDERR "BRACE CMD before brace add spaces '$added_space'\n"
            if $self->{'conf'}->{'DEBUG'};
        }
      }
    # special case for accent commands, use following character except @
    # as argument.  Note that since we checked before that there isn't
    # an @-command opening, there should not be an @ anyway.  The line
    # may possibly be empty in some specific case, without end of line.
    } elsif ($accent_commands{$current->{'cmdname'}}
             and $line =~ s/^([^@])//) {
      my $arg_char = $1;
      print STDERR "ACCENT \@$current->{'cmdname'} following_arg: $arg_char\n"
        if ($self->{'conf'}->{'DEBUG'});
      if ($current->{'contents'}) {
        _gather_spaces_after_cmd_before_arg($self, $current);
      }
      my $following_arg = {'type' => 'following_arg',
                           'parent' => $current};
      $current->{'args'} = [ $following_arg ];
      my $accent_arg = { 'text' => $arg_char, 'parent' => $following_arg };
      $following_arg->{'contents'} = [ $accent_arg ];

      if ($current->{'cmdname'} eq 'dotless'
          and $arg_char ne 'i' and $arg_char ne 'j') {
        $self->_line_error(sprintf(
                  __("\@dotless expects `i' or `j' as argument, not `%s'"),
                                   $arg_char),
                           $source_info);
      }
      $current = $current->{'parent'};
    } else {
      $self->_line_error(sprintf(__("\@%s expected braces"),
                         $current->{'cmdname'}), $source_info);
      if ($current->{'contents'}) {
        _gather_spaces_after_cmd_before_arg($self, $current);
      }
      $current = $current->{'parent'};
    }
  } elsif (_handle_menu_entry_separators($self, \@current_array_for_ref,
                                         \$line, $source_info, $asterisk,
                                         $menu_separator)) {
    $current = $current_array_for_ref[0];
  # Any other @-command.
  } elsif (defined($command)) {
    substr($line, 0, $command_length) = '';

    print STDERR "COMMAND \@".Texinfo::Common::debug_command_name($command)
                  ."\n" if ($self->{'conf'}->{'DEBUG'});

    # @value not expanded (expansion is done above), and @txiinternalvalue
    if ($command eq 'value' or $command eq 'txiinternalvalue') {
      my $spaces_element;
      if ($self->{'conf'}->{'IGNORE_SPACE_AFTER_BRACED_COMMAND_NAME'}
          and $line =~ s/^(\s+)//) {
        $spaces_element = {'text' => $1};
      }
      # REVALUE
      if ($line =~ s/^{([\w\-][^\s{\\}~`\^+"<>|@]*)}//) {
        my $value = $1;
        if ($command eq 'value') {
          if (not exists($self->{'values'}->{$value})) {
            _abort_empty_line($self, $current);

            $self->_line_warn(
               sprintf(__("undefined flag: %s"), $value), $source_info);

            # caller should expand something along
            # cdt($self, '@{No value for `{value}\'@}',
            #                            {'value' => ...});
            my $new_element = _new_value_element($command, $value, $current,
                                                 $spaces_element);
            push @{$current->{'contents'}}, $new_element;
          # expansion of value already done above
          #} else {
          }
        } else {
          # txiinternalvalue
          _abort_empty_line($self, $current);
          my $new_element = _new_value_element($command, $value, $current,
                                               $spaces_element);
          push @{$current->{'contents'}}, $new_element;
        }
      } else {
        $self->_line_error(sprintf(__("bad syntax for \@%s"),
                             $command), $source_info);
      }
      return ($current, $line, $source_info, $retval);
      # goto funexit;  # used in XS code
    }

    if (defined($deprecated_commands{$command})) {
      $self->_line_warn(sprintf(__("\@%s is obsolete"),
                                $command), $source_info);
    }

    # special case with @ followed by a newline protecting end of lines
    # in @def*
    if ($self->_top_context() eq 'ct_def' and $command eq "\n") {
      my $line_continuation_source_mark
        = { 'sourcemark_type' => 'defline_continuation' };
      _register_source_mark($self, $current, $line_continuation_source_mark);
      ($line, $source_info) = _next_text($self, $current);
      return ($current, $line, $source_info, $retval);
    }

    # warn on not appearing at line beginning.  Need to do before closing
    # paragraph as it also closes the empty line
    my $last_element;
    if ($current->{'contents'}) {
      $last_element = $current->{'contents'}->[-1];
    }
    if ((!$last_element or !$last_element->{'type'}
         or $last_element->{'type'} ne 'empty_line')
        and $begin_line_commands{$command}) {
      $self->_line_warn(
          sprintf(__("\@%s should only appear at the beginning of a line"),
                  $command), $source_info);
    }

    _abort_empty_line($self, $current);

    if ($close_paragraph_not_preformatted{$command}) {
      $current = _end_paragraph($self, $current, $source_info);
    } elsif ($close_preformatted_commands{$command}) {
      $current = _end_paragraph_preformatted($self, $current, $source_info);
    }

    # command used to get command data.  Needed for the multicategory
    # @item command
    my $data_cmdname = $command;
    # cannot check parent before closing paragraph/preformatted
    $data_cmdname = 'item_LINE'
      if ($command eq 'item' and _item_line_parent($current));

    _check_valid_nesting ($self, $current, $command, $source_info);
    _check_valid_nesting_context ($self, $command, $source_info);

    if ($in_index_commands{$command}
        # it is important to check if in an index command, as otherwise
        # the internal space type is not processed and remains as is in
        # the final tree.
        and _is_index_element($self, $current->{'parent'})) {
      if ($command eq 'subentry') {
        _isolate_trailing_space($current, 'spaces_at_end');
      } else {
        # an internal and temporary space type that is converted to
        # a normal space without type if followed by text or a
        # "spaces_at_end" if followed by spaces only when the
        # index or subentry command is done.
        _isolate_trailing_space($current,
                                'internal_spaces_before_brace_in_index');
      }
    }

    unless ($self->{'no_paragraph_commands'}->{$data_cmdname}) {
      if (_in_begin_paragraph($self, $current)) {
        $current = _begin_paragraph($self, $current);
      }
    }

    my $command_element;

    if (defined($nobrace_commands{$data_cmdname})) {
      ($current, $line, $retval, $command_element)
        = _handle_other_command($self, $current, $command, $line, $source_info);

    } elsif (defined($self->{'line_commands'}->{$data_cmdname})) {
      # line commands
      ($current, $line, $retval, $command_element)
       = _handle_line_command($self, $current, $command, $data_cmdname, $line,
                              $source_info);

      # we can only be in an ignored format_raw if we are directly in
      # the command, as a rawpreformatted container is immediatly added in a non
      # ignored format_raw.  Followed by a comment
      if ($current->{'cmdname'}
          and $block_commands{$current->{'cmdname'}}
          and $block_commands{$current->{'cmdname'}} eq 'format_raw') {
        ($line, $source_info)
           = _process_ignored_raw_format_block_contents($self, $current);
        $retval = $STILL_MORE_TO_PROCESS;
      # in a 'raw' verbatim or ignore or ignored conditional followed by
      # a comment
      } elsif ($retval == $GET_A_NEW_LINE
          and $current->{'cmdname'}
          and $block_commands{$current->{'cmdname'}}
          and ($block_commands{$current->{'cmdname'}} eq 'raw'
               or $block_commands{$current->{'cmdname'}} eq 'conditional')) {
        ($line, $source_info) = _process_raw_block_contents($self, $current);
        $retval = $STILL_MORE_TO_PROCESS;
      }
    } elsif (exists($block_commands{$data_cmdname})) {
      if ($command eq 'macro' or $command eq 'rmacro' or $command eq 'linemacro') {
        $command_element = _parse_macro_command_line($self, $command, $line,
                                                     $current, $source_info);
        push @{$current->{'contents'}}, $command_element;
        $current = $command_element;
        ($line, $source_info) = _process_macro_block_contents($self, $current);
      } else {
        # @-command with matching @end opening
        ($current, $line, $command_element)
          = _handle_block_command($self, $current, $command, $line, $source_info);
      }

    } elsif (defined($self->{'brace_commands'}->{$data_cmdname})) {
      ($current, $command_element)
        = _handle_brace_command($self, $current, $command, $source_info);
    }

    if (defined($from_alias) and $command_element) {
      $command_element->{'info'} = {} if (!$command_element->{'info'});
      $command_element->{'info'}->{'alias_of'} = $from_alias;
    }
  } elsif ($open_brace) {
    substr($line, 0, 1) = '';
    ($current, $line)
       = _handle_open_brace($self, $current, $line, $source_info);
    # in @verb. type should be 'brace_container'
    if ($current->{'parent'} and $current->{'parent'}->{'cmdname'}
        and $current->{'parent'}->{'cmdname'} eq 'verb') {
      my $char = quotemeta($current->{'parent'}->{'info'}->{'delimiter'});
      while (1) {
        if ($line =~ s/^(.*?)$char\}/\}/) {
          push @{$current->{'contents'}},
             { 'text' => $1, 'type' => 'raw', 'parent' => $current }
              if ($1 ne '');
          print STDERR "END VERB\n" if ($self->{'conf'}->{'DEBUG'});
          last;
        }
        push @{$current->{'contents'}},
          { 'text' => $line, 'type' => 'raw', 'parent' => $current };
        print STDERR "LINE VERB: $line" if ($self->{'conf'}->{'DEBUG'});
        ($line, $source_info) = _next_text($self, $current);
        if (!defined($line)) {
          return ($current, $line, $source_info, $retval);
        }
      }
    }
  } elsif ($close_brace) {
    substr($line, 0, 1) = '';
    $current = _handle_close_brace($self, $current, $source_info);

  } elsif ($comma) {
    substr($line, 0, 1) = '';
    if ($current->{'parent'}
        and $current->{'parent'}->{'remaining_args'}) {
      ($current, $line, $source_info)
         = _handle_comma($self, $current, $line, $source_info);
    } elsif ($current->{'type'}
             and $current->{'type'} eq 'line_arg'
             and $current->{'parent'}->{'cmdname'}
             and $current->{'parent'}->{'cmdname'} eq 'node') {
      $self->_line_warn(__("superfluous arguments for node"), $source_info);
    } else {
      $current = _merge_text($self, $current, $comma);
    }
  } elsif ($form_feed) {
    substr($line, 0, 1) = '';
    print STDERR "FORM FEED in "
          .Texinfo::Common::debug_print_element($current, 1).": "
           ._debug_protect_eol($line)."\n"
      if ($self->{'conf'}->{'DEBUG'});
    if ($current->{'type'}
        and $current->{'type'} eq 'paragraph') {
      # A form feed stops and restart a paragraph.
      $current = _close_container($self, $current, $source_info);
      my $line_feed = {'type' => 'empty_line', 'text' => $form_feed,
                       'parent' => $current };
      push @{$current->{'contents'}}, $line_feed;
      my $empty_line = { 'type' => 'empty_line', 'text' => '',
                         'parent' => $current };
      push @{$current->{'contents'}}, $empty_line;
    } else {
      $current = _merge_text($self, $current, $form_feed);
    }
  } elsif ($menu_only_separator) {
    substr($line, 0, 1) = '';
    $current = _merge_text($self, $current, $menu_only_separator);
  # Misc text except end of line
  } elsif (defined($misc_text)) {
    #print STDERR "MISC TEXT: $misc_text\n" if ($self->{'conf'}->{'DEBUG'});
    substr($line, 0, length($misc_text)) = '';
    $current = _merge_text($self, $current, $misc_text);
  # end of line
  } else {
    print STDERR "END LINE "
        .Texinfo::Common::debug_print_element($current, 1)."\n"
          if ($self->{'conf'}->{'DEBUG'});
    if ($line =~ s/^(\n)//) {
      $current = _merge_text($self, $current, $1);
    } elsif ($line =~ s/^\0+//) {
      # NOTE this does not happen with _parse_texi_regex Perl implementation
      # as a NUL byte ends up in misc_text.  The XS override cannot pass
      # NUL as strings and cannot therefore put NUL in misc_text, therefore
      # if there are NUL in string we end up here.
      # Also we could have called _merge_text instead of discarding the NUL
      # to be more like _parse_texi_regex Perl, but it should not matter as
      # NUL in input is invalid.  In addition the XS Parser, in general, does
      # something different with NUL.
      return ($current, $line, $source_info, $retval);
    } else {
      $self->_bug_message("Should be at end of line but have `$line'",
                          $source_info, $current);
      die;
    }
    $current = _end_line($self, $current, $source_info);

    # we can only be in an ignored format_raw if we are directly in
    # the command, as a rawpreformatted container is immediatly added in a non
    # ignored format_raw
    if ($current->{'cmdname'}
        and $block_commands{$current->{'cmdname'}}
        and $block_commands{$current->{'cmdname'}} eq 'format_raw') {
      ($line, $source_info)
         = _process_ignored_raw_format_block_contents($self, $current);
    # in a 'raw' verbatim or ignore or ignored conditional followed by an
    # end of line
    } elsif ($current->{'cmdname'}
             and $block_commands{$current->{'cmdname'}}
             and ($block_commands{$current->{'cmdname'}} eq 'raw'
                  or $block_commands{$current->{'cmdname'}} eq 'conditional')) {
      ($line, $source_info) = _process_raw_block_contents($self, $current);
    } else {
      $retval = $GET_A_NEW_LINE;
    }
  }

 funexit:
  return ($current, $line, $source_info, $retval);
}

# the main subroutine
sub _parse_texi($$$)
{
  my ($self, $root, $current) = @_;

  my $source_info;
  my $status;
  my $line;

  my $document = $self->{'document'};

 NEXT_LINE:
  while (1) {
    #my $line;
    ($line, $source_info) = _next_text($self, $current);
    if (!defined($line)) {
      print STDERR "NEXT_LINE NO MORE\n" if ($self->{'conf'}->{'DEBUG'});
      last;
    }
    #print STDERR "@{$self->{'nesting_context'}->{'basic_inline_stack_on_line'}}|$line"
    #if ($self->{'nesting_context'} and $self->{'nesting_context'}->{'basic_inline_stack_on_line'});

    if ($self->{'conf'}->{'DEBUG'}) {
      my $additional_debug = '';
      if (0) {
        my $source_info_text = '';
        my $macro_name = '';
        $macro_name = $source_info->{'macro'}
                       if (defined($source_info->{'macro'}));
        $source_info_text = "$source_info->{'line_nr'}.$macro_name"
          if ($source_info);
        my @cond_commands = map {$_->[0]} @{$self->{'conditional_stack'}};
        $additional_debug = '('.join('|', $self->_get_context_stack())
          .":@cond_commands:$source_info_text)";
      }
      print STDERR "NEW LINE${additional_debug} $line";
      #print STDERR "  $current: "
      #             .Texinfo::Common::debug_print_element($current)."\n";
    }

    # This almost never happens in the tests, because empty lines are mostly
    # generated within a line.
    #if ($line eq '') {
    #  print STDERR "IGNORE EMPTY LINE\n"
    #     if ($self->{'conf'}->{'DEBUG'})
    #  next;
    #}

    next NEXT_LINE if _check_line_directive ($self, $line, $source_info);

    # based on whitespace_chars_except_newline in XS parser
    $line =~ s/^([ \t\cK\f]*)//;
    push @{$current->{'contents'}}, { 'type' => 'empty_line',
                                      'text' => $1,
                                      'parent' => $current };
    while (1) {
      ($current, $line, $source_info, $status)
         = _process_remaining_on_line($self, $current, $line, $source_info);
      if ($status == $GET_A_NEW_LINE) {
        print STDERR "GET_A_NEW_LINE\n" if ($self->{'conf'}->{'DEBUG'});
        last;
      } elsif ($status == $FINISHED_TOTALLY) {
        print STDERR "FINISHED_TOTALLY\n" if ($self->{'conf'}->{'DEBUG'});
        goto finished_totally;
      }
      # can happen if there is macro expansion at the end of a text fragment
      # or if at the end of a text fragment.
      if (! defined($line)) {
        print STDERR "END LINE in line loop STILL_MORE_TO_PROCESS\n"
                                            if ($self->{'conf'}->{'DEBUG'});
        # If we are in an empty line, we want to end the line as usual.
        # If we are after an opening brace or comma or after an empty
        # string, there won't be any more output to abort those unfinished
        # constructs, so we call abort_empty_line here
        if (not ($current->{'contents'}
                 and $current->{'contents'}->[-1]->{'type'}
                 and $current->{'contents'}->[-1]->{'type'} eq 'empty_line'
                 and $current->{'contents'}->[-1]->{'text'} ne '')) {
          _abort_empty_line($self, $current);
        }
        $current = _end_line($self, $current, $source_info);
        # It may happen that there was an @include file on the line, it
        # was pushed to input in _end_line, its contents will be picked up at
        # NEXT_LINE.  Normally, macro and value expansion cannot be triggered
        # by _end_line, so cannot lead to more input being available after
        # an undefined line.
        # Because there can still be content with an include file expansion,
        # need to go to NEXT_LINE, even though for any other situation
        # there is no input anymore.
        last;
      }
    }
  }
 finished_totally:
  while (@{$self->{'conditional_stack'}}) {
    my $cond_info = pop @{$self->{'conditional_stack'}};
    my ($cond_command, $cond_source_mark) = @$cond_info;
    $self->_line_error(sprintf(__("expected \@end %s"), $cond_command),
                      $source_info);
  }
  $current = _close_commands($self, $current, $source_info);

  _pop_context($self, ['ct_base', 'ct_line'], $source_info, $current);
  my @context_stack = $self->_get_context_stack();
  if (scalar(@context_stack) != 0) {
    die($self->_bug_message("CONTEXT_STACK not empty at _parse_texi end: "
           .join('|', @context_stack)));
  }

  # Gather text after @bye
  if (defined($line) and $status == $FINISHED_TOTALLY) {
    print STDERR "GATHER AFTER BYE\n" if ($self->{'conf'}->{'DEBUG'});
    my $element_after_bye = {'type' => 'postamble_after_end', 'contents' => [],
                             'parent' => $current};
    while (1) {
      my $line;
      ($line, $source_info) = _next_text($self, $element_after_bye);
      last if (!defined($line));
      push @{$element_after_bye->{'contents'}},
             {'text' => $line, 'type' => 'text_after_end',
              'parent' => $element_after_bye};
    }
    if (scalar(@{$element_after_bye->{'contents'}})) {
      push @{$current->{'contents'}}, $element_after_bye;
    }
  }

  # check that there is only one empty input remaining and remove
  # it such that it is not re-used by following parser calls.
  my $empty_last_input = shift(@{$self->{'input'}});
  if ($empty_last_input->{'th'} or $empty_last_input->{'fh'}
      or $empty_last_input->{'source_mark'}
      or scalar(@{$self->{'input'}})) {
    my $msg = '';
    $msg .= 'th set, ' if ($empty_last_input->{'th'});
    $msg .= 'fh set, ' if ($empty_last_input->{'fh'});
    $msg .= 'mark, ' if ($empty_last_input->{'source_mark'});
    $msg .= scalar(@{$self->{'input'}}).' input, '
      if (scalar(@{$self->{'input'}}));

    $self->_bug_message("Non empty last input at the end: $msg\n");
    die;
  }

  # update merged_in for merging hapening after first index merge
  foreach my $index_name (keys (%{$document->{'indices'}})) {
    my $index_info = $document->{'indices'}->{$index_name};
    if ($index_info->{'merged_in'}) {
      my $ultimate_idx
           = Texinfo::Common::ultimate_index($document->{'indices'},
                                                         $index_info);
      $index_info->{'merged_in'} = $ultimate_idx->{'name'};
    }
  }

  # Setup identifier target elements based on 'labels_list'
  Texinfo::Document::set_labels_identifiers_target($document,
           $document->{'parser_registrar'}, $self->{'conf'}->{'DEBUG'});
  Texinfo::Translations::complete_indices($document->{'indices'},
                                          $self->{'conf'}->{'DEBUG'});

  $document->register_tree($root);

  return $document;
}

# parse special rawline @-commands, unmacro, set, clear, clickstyle
# and simply set the line as argument for other commands.
sub _parse_rawline_command($$$$)
{
  my ($self, $line, $command, $source_info) = @_;

  my $args = [];

  my $special_arg = 1;
  my $has_comment = 0;

  if ($command eq 'set') {
    # REVALUE
    if ($line =~ /^\s+([\w\-][^\s{\\}~`\^+"<>|@]*)(\@(comment|c)((\@|\s+).*)?|\s+(.*?))?\s*$/) {
      if ($line =~ s/\@(comment|c)((\@|\s+).*)?$//) {
        $has_comment = 1;
      }
      $line =~ /^\s+([\w\-][^\s{\\}~`\^+"<>|@]*)(\s+(.*?))?\s*$/;
      my $name = $1;
      my $arg = $3;
      $arg = '' if (!defined($arg));
      $args = [$name, $arg];
      $self->{'values'}->{$name} = $arg;
    } elsif ($line !~ /\S/) {
      $self->_line_error(__("\@set requires a name"), $source_info);
    } else {
      $self->_line_error(sprintf(
                    __("bad name for \@%s"), $command), $source_info);
    }
  } elsif ($command eq 'clear') {
    # REVALUE
    if ($line =~ /^\s+([\w\-][^\s{\\}~`\^+"<>|@]*)\s*(\@(comment|c)((\@|\s+).*)?)?$/) {
      $args = [$1];
      delete $self->{'values'}->{$1};
      $has_comment = 1 if (defined($3));
    } elsif ($line !~ /\S/) {
      $self->_line_error(__("\@clear requires a name"), $source_info);
    } else {
      $self->_line_error(sprintf(
                    __("bad name for \@%s"), $command), $source_info);
    }
  } elsif ($command eq 'unmacro') {
    # REMACRO
    if ($line =~ /^\s+([[:alnum:]][[:alnum:]\-]*)\s*(\@(comment|c)((\@|\s+).*)?)?$/) {
      $args = [$1];
      delete $self->{'macros'}->{$1};
      $has_comment = 1 if (defined($3));
      print STDERR "UNMACRO $1\n" if ($self->{'conf'}->{'DEBUG'});
    } elsif ($line !~ /\S/) {
      $self->_line_error(__("\@unmacro requires a name"), $source_info);
    } else {
      $self->_line_error(sprintf(
                    __("bad name for \@%s"), $command), $source_info);
    }
  } elsif ($command eq 'clickstyle') {
    # REMACRO
    if ($line =~ /^\s*@([[:alnum:]][[:alnum:]\-]*)(\{\})?\s*/) {
      $args = ['@'.$1];
      $self->{'clickstyle'} = $1;
      my $remaining = $line;
      $remaining =~ s/^\s*@([[:alnum:]][[:alnum:]\-]*)(\{\})?\s*(\@(comment|c)((\@|\s+).*)?)?//;
      $has_comment = 1 if (defined($4));
      if (defined($remaining)) {
        chomp($remaining);
        if ($remaining ne '') {
          $self->_line_warn(sprintf(__(
                         "remaining argument on \@%s line: %s"),
                           $command, $remaining), $source_info);
        }
      }
    } else {
      $self->_line_error(sprintf(__(
      "\@clickstyle should only accept an \@-command as argument, not `%s'"),
                                 $line), $source_info);
    }
  } else {
    $args = [ $line ];
    $special_arg = 0;
  }
  return ($args, $has_comment, $special_arg);
}

# at the end of an @-command line with arguments, parse the resulting
# text, to collect aliases, definfoenclose and collect errors on
# wrong arguments.
sub _parse_line_command_args($$$)
{
  my ($self, $line_command, $source_info) = @_;

  my $args;

  my $command = $line_command->{'cmdname'};
  my $arg = $line_command->{'args'}->[0];

  # Not in XS parser.  Could be added if deemded interesting, but
  # arguments are already checked below.
  #if ($self->{'conf'}->{'DEBUG'}) {
  #  print STDERR "MISC ARGS \@$command\n";
  #  if ($arg->{'contents'}) {
  #    my $idx = 0;
  #    foreach my $content (@{$arg->{'contents'}}) {
  #      print STDERR "   -> $idx "
  #         .Texinfo::Common::debug_print_element($content, 0)."\n";
  #      $idx++;
  #    }
  #  }
  #}

  if (!$arg->{'contents'}) {
    $self->_command_error($line_command,
               __("\@%s missing argument"), $command);
    return undef;
  }

  if (scalar(@{$arg->{'contents'}}) > 1
         or (!defined($arg->{'contents'}->[0]->{'text'}))) {
    $self->_line_error(sprintf(__("superfluous argument to \@%s"),
       $command), $source_info);
  }
  return undef if (!defined($arg->{'contents'}->[0]->{'text'}));

  my $line = $arg->{'contents'}->[0]->{'text'};

  if ($command eq 'alias') {
    # REMACRO
    if ($self->{'conf'}->{'NO_USER_COMMANDS'}) {
      # do nothing
    } elsif ($line =~ s/^([[:alnum:]][[:alnum:]-]*)(\s*=\s*)([[:alnum:]][[:alnum:]-]*)$//) {
      my $new_command = $1;
      my $existing_command = $3;
      $args = [$1, $3];
      if (exists($block_commands{$existing_command})) {
        $self->_line_warn(sprintf(
                           __("environment command %s as argument to \@alias"),
                           $existing_command), $source_info);
      }

      if (exists($self->{'aliases'}->{$existing_command})) {
        if ($self->{'aliases'}->{$existing_command} ne $new_command) {
          $existing_command = $self->{'aliases'}->{$existing_command};
        } else {
          $self->_line_warn(sprintf(
                __("recursive alias definition of %s through %s ignored"),
                      $new_command, $existing_command), $source_info);
        }
      }
      $self->{'aliases'}->{$new_command} = $existing_command;
      # could be cleaner to unset macro and definfoenclosed, but
      # not needed in practice as alias are substituted the earliest.
    } else {
      $self->_line_error(sprintf(
                          __("bad argument to \@%s"), $command), $source_info);
    }

  } elsif ($command eq 'definfoenclose') {
    # REMACRO
    # FIXME how to handle non ascii space?  As space or in argument?
    if ($self->{'conf'}->{'NO_USER_COMMANDS'}) {
      # do nothing
    } elsif ($line =~ s/^([[:alnum:]][[:alnum:]\-]*)\s*,\s*([^\s,]*)\s*,\s*([^\s,]*)$//) {
      $args = [$1, $2, $3 ];
      my ($cmd_name, $begin, $end) = ($1, $2, $3);
      if ($all_commands{$cmd_name}
          and (!$brace_commands{$cmd_name}
               or ($brace_commands{$cmd_name} ne 'style_code'
                   and $brace_commands{$cmd_name} ne 'style_no_code'
                   and $brace_commands{$cmd_name} ne 'style_other'))) {
        $self->_line_error(sprintf(
                    __("cannot redefine with \@definfoenclose: %s"),
                                   $cmd_name), $source_info);
      } else {
        $self->{'definfoenclose'}->{$cmd_name} = [ $begin, $end ];
        print STDERR "DEFINFOENCLOSE \@$cmd_name: $begin, $end\n"
               if ($self->{'conf'}->{'DEBUG'});
        delete $self->{'macros'}->{$cmd_name};
        delete $self->{'aliases'}->{$cmd_name};
        # unset @def*index effect
        delete $self->{'line_commands'}->{$cmd_name};
        delete $self->{'no_paragraph_commands'}->{$cmd_name};
        delete $self->{'basic_inline_commands'}->{$cmd_name};
        delete $self->{'index_entry_commands'}->{$cmd_name};
        delete $self->{'command_index'}->{$cmd_name};
        # consistent with XS parser, value not actually used anywhere.
        $self->{'brace_commands'}->{$cmd_name} = 'style_other';
        # this allows to obtain the same result as the XS parser which checks
        # dynamically the brace_commands type
        $self->{'valid_nestings'}->{$cmd_name} = \%in_full_text_commands;
        # note that a built-in command previously in a hash classifying the
        # @-command otherwise will remain there, possibly having specific effects.
      }
    } else {
      $self->_line_error(sprintf(__("bad argument to \@definfoenclose")),
                         $source_info);
    }
  } elsif ($command eq 'columnfractions') {
    my @possible_fractions = split (/\s+/, $line);
    if (!@possible_fractions) {
      $self->_line_error(__("empty \@columnfractions"),
                         $source_info);
    } else {
      foreach my $fraction (@possible_fractions) {
        if ($fraction =~ /^\d*\.\d+$|^\d+\.?$/) {
          push @$args, $fraction;
        } else {
          $self->_line_error(sprintf(
                              __("column fraction not a number: %s"),
                              $fraction), $source_info);
        }
      }
    }
  } elsif ($command eq 'sp') {
    if ($line =~ /^(\d+)$/) {
      $args = [$1];
    } else {
      $self->_line_error(sprintf(__("\@sp arg must be numeric, not `%s'"),
                                 $line), $source_info);
    }
  } elsif ($command eq 'defindex' || $command eq 'defcodeindex') {
    # REMACRO
    if ($self->{'conf'}->{'NO_USER_COMMANDS'}
        or $self->{'conf'}->{'NO_INDEX'}) {
      # do nothing
    } elsif ($line =~ /^([[:alnum:]][[:alnum:]\-]*)$/) {
      my $name = $1;
      if ($forbidden_index_name{$name}) {
        $self->_line_error(sprintf(
                             __("reserved index name %s"), $name), $source_info);
      } else {
        my $document = $self->{'document'};
        my $in_code = 0;
        $in_code = 1 if ($command eq 'defcodeindex');
        $args = [$name];
        if (!exists($document->{'indices'}->{$name})) {
          $document->{'indices'}->{$name} = {'in_code' => $in_code};
        }
        if (!exists($document->{'indices'}->{$name}->{'name'})) {
          $document->{'indices'}->{$name}->{'name'} = $name;
        }
        my $index_cmdname = $name.'index';
        delete $self->{'macros'}->{$index_cmdname};
        delete $self->{'aliases'}->{$index_cmdname};
        # unset definfoenclose effect
        delete $self->{'definfoenclose'}->{$index_cmdname};
        delete $self->{'brace_commands'}->{$index_cmdname};
        delete $self->{'valid_nestings'}->{$index_cmdname};
        $self->{'line_commands'}->{$index_cmdname} = 'line';
        $self->{'no_paragraph_commands'}->{$index_cmdname} = 1;
        $self->{'basic_inline_commands'}->{$index_cmdname} = 1;
        $self->{'index_entry_commands'}->{$index_cmdname} = $name;
        $self->{'command_index'}->{$index_cmdname} = $name;
      }
    } else {
      $self->_line_error(sprintf(
                __("bad argument to \@%s: %s"), $command, $line), $source_info);
    }
  } elsif ($command eq 'synindex' || $command eq 'syncodeindex') {
    # REMACRO
    if ($line =~ /^([[:alnum:]][[:alnum:]\-]*)\s+([[:alnum:]][[:alnum:]\-]*)$/) {
      if ($self->{'conf'}->{'NO_INDEX'}) {
        # do nothing
      } else {
        my $document = $self->{'document'};
        my $index_name_from = $1;
        my $index_name_to = $2;
        my $index_from = $document->{'indices'}->{$index_name_from};
        my $index_to = $document->{'indices'}->{$index_name_to};
        $self->_line_error(sprintf(__("unknown source index in \@%s: %s"),
                                   $command, $index_name_from), $source_info)
          unless $index_from;
        $self->_line_error(sprintf(__("unknown destination index in \@%s: %s"),
                                   $command, $index_name_to), $source_info)
          unless $index_to;
        if ($index_from and $index_to) {
          my $current_to
               = Texinfo::Common::ultimate_index($document->{'indices'},
                                                         $index_to);
          # find the merged indices recursively avoiding loops
          if ($current_to->{'name'} ne $index_name_from) {
            my $in_code = 0;
            $in_code = 1 if ($command eq 'syncodeindex');
            $index_from->{'in_code'} = $in_code;
            $index_from->{'merged_in'} = $current_to->{'name'};
            $args = [$index_name_from, $index_name_to];
          } else {
            $self->_line_warn(sprintf(__(
                           "\@%s leads to a merging of %s in itself, ignoring"),
                               $command, $index_name_from), $source_info);
          }
        }
      }
    } else {
      $self->_line_error(sprintf(__("bad argument to \@%s: %s"),
                                $command, $line), $source_info);
    }
  } elsif ($command eq 'printindex') {
    if ($self->{'conf'}->{'NO_INDEX'}) {
      # do nothing
    # REMACRO
    } elsif ($line =~ /^([[:alnum:]][[:alnum:]\-]*)$/) {
      my $document = $self->{'document'};
      my $name = $1;
      if (!exists($document->{'indices'}->{$name})) {
        $self->_line_error(sprintf(__("unknown index `%s' in \@printindex"),
                                    $name), $source_info);
      } else {
        my $idx = $document->{'indices'}->{$name};
        if ($idx->{'merged_in'}) {
          my $ultimate_idx
            = Texinfo::Common::ultimate_index($document->{'indices'}, $idx);
          $self->_line_warn(sprintf(__(
                       "printing an index `%s' merged in another one, `%s'"),
                                   $name, $ultimate_idx->{'name'}),
                           $source_info);
        }
        if (!defined($self->{'current_node'})
            and !defined($self->{'current_section'})
            and !scalar(@{$self->{'nesting_context'}->{'regions_stack'}})) {
          $self->_line_warn(sprintf(__(
                     "printindex before document beginning: \@printindex %s"),
                                    $name), $source_info);
        }
        $args = [$name];
      }
    } else {
      $self->_line_error(sprintf(
               __("bad argument to \@%s: %s"), $command, $line), $source_info);
    }
  } elsif ($command eq 'fonttextsize') {
    if ($line eq '10' or $line eq '11') {
      $args = [$line];
    } else {
      $self->_line_error(sprintf(__(
                        "Only \@fonttextsize 10 or 11 is supported, not `%s'"),
                                 $line), $source_info);
    }
  } elsif ($command eq 'footnotestyle') {
    if ($line eq 'separate' or $line eq 'end') {
      $args = [$line];
    } else {
      $self->_line_error(sprintf(__(
                   "\@footnotestyle arg must be `separate' or `end', not `%s'"),
                                 $line), $source_info);
    }
  } elsif ($command eq 'setchapternewpage') {
    if ($line eq 'on' or $line eq 'off' or $line eq 'odd') {
      $args = [$line];
    } else {
      $self->_line_error(sprintf(__(
              "\@setchapternewpage arg must be `on', `off' or `odd', not `%s'"),
                                 $line), $source_info);
    }
  } elsif ($command eq 'need') { # only a warning
    if (($line =~ /^(\d+(\.\d*)?)$/) or
             ($line =~ /^(\.\d+)$/)) {
      $args = [$1];
    } else {
      $self->_line_error(sprintf(__("bad argument to \@need: %s"),
                                 $line), $source_info);
    }
  } elsif ($command eq 'paragraphindent') {
    if ($line =~ /^([\w\-]+)$/) {
      my $value = $1;
      if ($value =~ /^(\d+)$/ or $value eq 'none' or $value eq 'asis') {
        $args = [$1];
      } else {
        $self->_line_error(sprintf(__(
           "\@paragraphindent arg must be numeric/`none'/`asis', not `%s'"),
                                             $value), $source_info);
      }
    } else {
      $self->_line_error(sprintf(__(
             "\@paragraphindent arg must be numeric/`none'/`asis', not `%s'"),
                                           $line), $source_info);
    }
  } elsif ($command eq 'firstparagraphindent') {
    if ($line eq 'none' or $line eq 'insert') {
      $args = [$line];
    } else {
      $self->_line_error(sprintf(__(
         "\@firstparagraphindent arg must be `none' or `insert', not `%s'"),
                                           $line), $source_info);
    }
  } elsif ($command eq 'exampleindent') {
    if ($line =~ /^(\d+)$/) {
      $args = [$1];
    } elsif ($line =~ /^(asis)$/) {
      $args = [$1];
    } else {
      $self->_line_error(sprintf(__(
           "\@exampleindent arg must be numeric/`asis', not `%s'"),
                                         $line), $source_info);
    }
  } elsif ($command eq 'frenchspacing'
           or $command eq 'xrefautomaticsectiontitle'
           or $command eq 'codequoteundirected'
           or $command eq 'codequotebacktick'
           or $command eq 'deftypefnnewline'
           or $command eq 'microtype') {
    if ($line eq 'on' or $line eq 'off') {
      $args = [$line];
    } else {
      $self->_line_error(sprintf(__("expected \@%s on or off, not `%s'"),
                                         $command, $line), $source_info);
    }
  } elsif ($command eq 'kbdinputstyle') {
    if ($line eq 'code' or $line eq 'example' or $line eq 'distinct') {
      $self->{'kbdinputstyle'} = $line;
      $args = [$line];
    } else {
      $self->_line_error(sprintf(__(
      "\@kbdinputstyle arg must be `code'/`example'/`distinct', not `%s'"),
                                           $line), $source_info);
    }
  } elsif ($command eq 'allowcodebreaks') {
    if ($line eq 'true' or $line eq 'false') {
      $args = [$line];
    } else {
      $self->_line_error(sprintf(__(
               "\@allowcodebreaks arg must be `true' or `false', not `%s'"),
                                           $line), $source_info);
    }
  } elsif ($command eq 'urefbreakstyle') {
    if ($line eq 'after' or $line eq 'before' or $line eq 'none') {
      $args = [$line];
    } else {
      $self->_line_error(sprintf(__(
         "\@urefbreakstyle arg must be `after'/`before'/`none', not `%s'"),
                                           $line), $source_info);
    }
  } elsif ($command eq 'headings') {
    if ($line eq 'off' or $line eq 'on' or $line eq 'single'
       or $line eq 'double' or  $line eq 'singleafter' or $line eq 'doubleafter') {
      $args = [$line];
    } else {
      $self->_line_error(sprintf(__("bad argument to \@%s: %s"),
                                 $command, $line), $source_info);
    }
  } elsif (grep {$_ eq $command} ('everyheadingmarks', 'everyfootingmarks',
                                  'evenheadingmarks', 'oddheadingmarks',
                                  'evenfootingmarks', 'oddfootingmarks')) {
    if ($line eq 'top' or $line eq 'bottom') {
      $args = [$line];
    } else {
      $self->_line_error(sprintf(__(
                      "\@%s arg must be `top' or `bottom', not `%s'"),
                                $command, $line), $source_info);
    }
  }
  return $args;
}

1;
__END__
=head1 NAME

Texinfo::Parser - Parse Texinfo code into a Perl tree

=head1 SYNOPSIS

  use Texinfo::Parser;

  my $parser = Texinfo::Parser::parser();
  my $document = $parser->parse_texi_file("somefile.texi");

  my ($errors, $errors_count) = $document->parser_errors();
  foreach my $error_message (@$errors) {
    warn $error_message->{'error_line'};
  }

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

C<Texinfo::Parser> will parse Texinfo text into a Perl tree.  In one pass
it expands user-defined @-commands, conditionals (C<@ifset>, C<@ifinfo>...)
and C<@value> and constructs the tree.  Some extra information is gathered
while doing the tree: for example, the C<@quotation> associated to an C<@author>
command, the number of columns in a multitable, or the node associated with a
section.

=head1 METHODS

No method is exported in the default case.  The module allows both
an object-oriented syntax, or traditional function, with the parser
as an opaque data structure given as an argument to every function.

=head2 Initialization

The following method is used to construct a new C<Texinfo::Parser> object:

=over

=item $parser = Texinfo::Parser::parser($options)
X<C<Texinfo::Parser::parser>>
X<Parser initialization>

This method creates a new parser.  The options may be provided as a hash
reference.  Most of those options correspond to Texinfo customization options
described in the Texinfo manual.

=over

=item CPP_LINE_DIRECTIVES

Handle cpp like synchronization lines if set. Set in the default case.

=item EXPANDED_FORMATS

An array reference of the output formats for which C<@ifI<FORMAT>>
conditional blocks should be expanded.  Default is empty.

=item FORMAT_MENU

Possible values are C<nomenu>, C<menu> and C<sectiontoc>.  Only report
menu-related errors for C<menu>.

=item INCLUDE_DIRECTORIES

An array reference of directories in which C<@include> files should be
searched for.  Default contains the working directory, F<.>.

=item IGNORE_SPACE_AFTER_BRACED_COMMAND_NAME

If set, spaces after an @-command name that take braces are ignored.
Default on.

=item MAX_MACRO_CALL_NESTING

Maximal number of nested user-defined macro calls.  Default is 100000.

=item documentlanguage

A string corresponding to a document language set by C<@documentlanguage>.
It overrides the document C<@documentlanguage> information, if present.

=item values

A hash reference.  Keys are names, values are the corresponding values.
Same as values set by C<@set>.

=back

=back

=head2 Parsing Texinfo text

Different methods may be called to parse some Texinfo code:
C<parse_texi_line> for a line, C<parse_texi_piece> for a fragment of
Texinfo, C<parse_texi_text> for a string corresponding to a full document
and C<parse_texi_file> for a file.  The first argument of these functions
is a parser.

When C<parse_texi_line> is used, the resulting tree is rooted at
a C<root_line> type container.  Otherwise, the resulting tree should be
rooted at a C<document_root> type container.

=over

=item $tree = $parser->parse_texi_line($text, $first_line_number)
X<C<parse_texi_line>>

This function is used to parse a short fragment of Texinfo code.

I<$text> is the string containing the texinfo line.  I<$first_line_number> is
the line number of the line, if undef, it will be set to 1.

=item $document = $parser->parse_texi_piece($text, $first_line_number)
X<C<parse_texi_piece>>

This function is used to parse Texinfo fragments.

I<$text> is the string containing the texinfo text.  I<$first_line_number> is
the line number of the first text line, if undef, it will be set to 1.

=item $document = $parser->parse_texi_text($text, $first_line_number)
X<C<parse_texi_text>>

This function is used to parse a text as a whole document.

I<$text> is the string containing the texinfo text.  I<$first_line_number> is
the line number of the first text line, if undef, it will be set to 1.

=item $document = $parser->parse_texi_file($file_name)
X<C<parse_texi_file>>

The file with name I<$file_name> is considered to be a Texinfo file and
is parsed into a tree.  I<$file_name> should be a binary string.

=back

The errors collected during the tree parsing are available with
the resulting document C<parser_errors>.  These errors are internally
registered in a C<Texinfo::Report> object.

=over

=item ($error_warnings_list, $error_count) = $document->parser_errors()
X<C<parser_errors>>

This function returns as I<$error_count> the count of parsing errors.
The I<$error_warnings_list> is an array of hash references
one for each error, warning or error line continuation.
They are described in detail in L<Texinfo::Report::errors|Texinfo::Report/($error_warnings_list, $error_count) = errors($registrar)>.

=back

=head1 TEXINFO TREE

X<Texinfo tree elements>

A Texinfo tree element (called element because node is overloaded in
the Texinfo world) is an hash reference.  There are three main categories
of tree element.  Tree elements associated with an @-command have a
C<cmdname> key holding the @-command name.  Tree elements corresponding
to text fragments have a C<text> key holding the corresponding text.
Finally, the last category is other elements, which in most cases have
a C<type> key holding their name.  Text fragments and @-command elements
may also have an associated type when such information is needed.

The children of an @-command or of other container element are in the array
referred to with the C<args> key or with the C<contents> key.  The C<args> key
is for arguments of @-commands, either in braces or on the rest of the line
after the command, depending on the type of command.  The C<contents> key array
holds the contents of the texinfo code appearing within a block @-command,
within a container, or within a C<@node> or sectioning @-command.

Another important key for the elements is the C<extra> key which is
associated to a hash reference and holds all kinds of information that
is gathered during the parsing and may help with the conversion.

You can see examples of the tree structure by running makeinfo like
this:

  makeinfo -c DUMP_TREE=1 -c TEXINFO_OUTPUT_FORMAT=parse document.texi

For a simpler, more regular representation of the tree structure, you
can do:

  makeinfo -c TEXINFO_OUTPUT_FORMAT=debugtree document.texi

=head2 Element keys

X<Texinfo tree element structure>

=over

=item cmdname

The command name of @-command elements.

=item text

The text fragment of text elements.

=item type

The type of element considered, in general a container.  Frequent
types encountered are I<paragraph> for a paragraph container,
I<brace_container> for the container holding a brace @-commands
content, I<line_arg> and I<block_line_arg> contain the arguments
appearing on the line of @-commands.  Text fragments may have a type to
give an information of the kind of text fragment, for example
I<spaces_before_paragraph> is associated to spaces appearing
before a paragraph beginning.  Most @-commands elements do not have
a type associated.

=item args

Arguments in braces or on @-command line.  An array reference.

=item contents

The Texinfo appearing in the element.  For block commands, other
containers, C<@node> and sectioning commands. An array reference.

=item parent

The parent element.

=item source_info

An hash reference corresponding to information on the location of the
element in the Texinfo input manual.  It should mainly be available for
@-command elements, and only for @-commands that are considered to be
complex enough that the location in the document is needed, for example
to prepare an error message.

The keys of the line number hash references are

=over

=item line_nr

The line number of the @-command.

=item file_name

The file name where @-command appeared.

=item macro

The user macro name the @-command is expanded from.

=back

=item info

A hash reference holding any other information that cannot be
obtained otherwise from the tree.
See L</Information available in the C<info> key>.

=item extra

A hash reference holding information that could also be obtained
from the tree, but is directly associated to the element to simplify
downstream code.
See L</Information available in the C<extra> key>.

=back

=head2 Element types

=head3 Types for command elements

Some types can be associated with @-commands (in addition to C<cmdname>),
although usually there will be no type at all.  The following are the
possible values of C<type> for tree elements for @-commands.

=over

=item definfoenclose_command

This type is set for an @-command that is redefined by C<@definfoenclose>.
The beginning is in C<< {'extra'}->{'begin'} >> and the end in
C<< {'extra'}->{'end'} >>.

The command name is the info I<command_name> value.

=item index_entry_command

This is the type of index entry command like C<@cindex>, and, more
importantly user-defined index entry commands.  So for example if there
is:

 @defindex foo
  ...

 @fooindex index entry

the C<@fooindex> @-command element will have the I<index_entry_command>
type.

The command name is the info I<command_name> value.

=back

=head3 Types for text elements

The text elements may have the following types (or may have no type
at all):

=over

=item after_menu_description_line

=item space_at_end_menu_node

Space after a node in the menu entry, when there is no description,
and space appearing after the description line.

=item delimiter

=item spaces

Spaces on definition command line separating the definition command arguments.
Delimiters, such as comma, square brackets and parentheses appearing in
definition command line arguments at the end of the line, separated from
surrounding texts during the parsing phase.

=item empty_line

An empty line (possibly containing whitespace characters only).

=item ignorable_spaces_after_command

spaces appearing after an @-command without braces that does not
take argument on the line, but which is followed by ignorable
spaces, such as C<@item> in C<@itemize> or C<@multitable>, or C<@noindent>.

=item spaces_after_close_brace

Spaces appearing after a closing brace, for some rare commands for which
this space should be ignorable (like C<@caption> or C<@sortas>).

=item spaces_before_paragraph

Space appearing before a paragraph beginning.

=item raw

Text in an environment where it should be kept as is (in C<@verbatim>,
C<@verb>, C<@macro> body).

=item rawline_arg

Used for the arguments to some special line commands whose arguments
aren't subject to the usual macro expansion.  For example C<@set>,
C<@clickstyle>, C<@unmacro>, C<@comment>.  The argument is associated to
the I<text> key.

=item spaces_at_end

Space within an index @-command before an @-command interrupting the
index command.

=item text_after_end

Text appearing after @bye.

=item text_before_beginning

Text appearing before real content, including the C<\input texinfo.tex>.

=item untranslated

English text added by the parser that may need to be translated
during conversion.  Happens for definition line @-commands aliases that
leads to prepending text such as ``Function''.

=back

=head3 Tree container elements

Some types of element are containers of portions of the tree,
either for the whole tree, or for contents appearing before C<@node>
and sectioning commands.

=over

=item before_node_section

Content before nodes and sectioning commands at the beginning of
C<document_root>.

=item document_root

=item root_line

C<root_line> is the type of the root tree when parsing Texinfo line
fragments using C<parse_texi_line>.  C<document_root> is the document
root otherwise.

C<document_root> first content should be C<before_node_section>, then nodes and
sections @-commands elements, C<@bye> element and C<postamble_after_end>.

=item postamble_after_end

This container holds everything appearing after @bye.

=item preamble_before_beginning

This container holds everything appearing before the first content, including
the C<\input texinfo.tex> line and following blank lines.

=item preamble_before_setfilename

This container holds everything that appears before C<@setfilename>.

=item preamble_before_content

This container holds everything appearing before the first formatted content,
corresponding to the I<preamble> in the Texinfo documentation.

=back

=head3 Types of container elements

The other types of element are containers with other elements appearing in
their C<contents>.  The C<paragraph> container holds normal text from the
Texinfo manual outside of any @-commands, and within @-commands with blocks of
text (C<@footnote>, C<@itemize> C<@item>, C<@quotation> for example).  The
C<preformatted> container holds the content appearing in @-commands like
C<@example> and the C<rawpreformatted> container holds the content appearing in
format commands such as C<@html>.  The other containers are more specific.

The types of container element are the following:

=over

=item balanced_braces

Special type containing balanced braces content (braces included)
in the context where they are valid, and where balanced braces need to
be collected to know when a top-level brace command is closed.  In C<@math>,
in raw output format brace commands and within brace @-commands in raw output
format block commands.

=item before_defline

A container for content before the first C<@defline> or C<@deftypeline>
in C<@defblock>.

=item before_item

A container for content before the first C<@item> of block @-commands
with items (C<@table>, C<@multitable>, C<@enumerate>...).

=item brace_container

=item brace_command_context

=item brace_arg

=item line_arg

=item block_line_arg

=item following_arg

Those containers occur within the C<args> array of @-commands taking an
argument.  I<brace_container> is used for the argument to commands
taking arguments surrounded by braces when the whole text in the braces
is in the argument.  I<brace_arg> is used for the arguments to commands taking
arguments surrounded by braces when the leading and, in most cases, trailing
spaces are not part of the argument, and for arguments in braces separated by
commas.  I<brace_command_context> is used for @-commands with braces that start
a new context (C<@footnote>, C<@caption>, C<@math>).

I<line_arg> is used for commands that take the texinfo code on the rest of the
line as their argument, such as C<@settitle>, C<@node>, C<@section>.
I<block_line_arg> is similar but is used for commands that start a new block
(which is to be ended with C<@end>).

I<following_arg> is used for the accent @-commands argument that did not use
braces but instead followed the @-command, possibly after a space, as

  @~n
  @ringaccent A

For example

 @code{in code}

leads to

 {'cmdname' => 'code',
  'args' => [{'type' => 'brace_container',
              'contents' => [{'text' => 'in code'}]}]}

=item bracketed_arg

Bracketed argument.  On definition command and on C<@multitable> line.

=item bracketed_linemacro_arg

Argument of a user defined linemacro call in bracket.  It holds directly the
argument text (which does not contain the braces) and does not contain other
elements.  It should not appear directly in the tree as the user defined
linemacro call is replaced by the linemacro body.

=item def_category

=item def_class

=item def_type

=item def_name

=item def_typearg

=item def_arg

Definition line arguments containers corresponding to the different parts of a
definition line command.  Contains one C<bracketed_arg>, C<def_line_arg> or
C<untranslated_def_line_arg> container.

=item def_line

=item def_item

=item inter_def_item

The I<def_line> type is associated with a container within a block definition
command.  It holds the definition line arguments in I<block_line_arg>.
A C<@def*> @-command line command such as C<@deffnx> or C<@defline>
also holds the definition line arguments, in I<line_arg>.
The type of each definition line arguments element describes the meaning of the
element.  It is one of I<def_category>, I<def_name>, I<def_class>, I<def_type>,
I<def_arg>, I<def_typearg>, I<spaces> or I<delimiter>, depending on the
definition.

The container with type I<def_item> holds the definition text content.
Content appearing before a definition command with a x form is in
an I<inter_def_item> container.

=item def_line_arg

=item untranslated_def_line_arg

the I<def_line_arg> contains one or several elements that together are a single
unit on a definition command line.  This container is very similar with a
I<bracketed_arg> on a definition line, except that there is no bracket.
Appears in definition line arguments containers such as I<def_category>,
I<def_arg> or similar.

The I<untranslated_def_line_arg> is similar, but only happens for automatically
added categories and contains only a text element.  For example, the C<deffun>
line I<def_category> container may contain an I<untranslated_def_line_arg> type
container containing itself a text element with ``Function'' as text, if the
document language demands a translation.  Note that the
I<untranslated_def_line_arg> is special, as, in general, it should not be
recursed into, as the text within is untranslated, but the untranslated text
should be gathered when converting the I<untranslated_def_line_arg> type
container.

=item macro_call

=item macro_call_line

=item rmacro_call

=item rmacro_call_line

=item linemacro_call

Container holding the arguments of a user defined macro, linemacro
or rmacro.  It should not appear directly in the tree as the user defined
call is expanded.  The name of the macro, rmacro or linemacro is the the info
I<command_name> value.  The I<macro_call_line> or I<rmacro_call_line> elements
are used when there are no braces and the whole line is the argument.

=item macro_name

=item macro_arg

Taken from C<@macro> definition and put in the C<args> key array of
the macro, I<macro_name> is the type of the text fragment corresponding
to the macro name, I<macro_arg> is the type of the text fragments
corresponding to macro formal arguments.

=item menu_comment

The I<menu_comment> container holds what is between menu entries
in menus.  For example, in:

  @menu
  Menu title

  * entry::

  Between entries
  * other::
  @end menu

Both

  Menu title

and

  Between entries

will be in a I<menu_comment>.

=item menu_entry

=item menu_entry_leading_text

=item menu_entry_name

=item menu_entry_separator

=item menu_entry_node

=item menu_entry_description

A I<menu_entry> holds a full menu entry, like

  * node::    description.

The different elements of the menu entry are in the
I<menu_entry> C<contents> array reference.

I<menu_entry_leading_text> holds the star and following spaces.
I<menu_entry_name> is the menu entry name (if present), I<menu_entry_node>
corresponds to the node in the menu entry, I<menu_entry_separator> holds
the text after the node and before the description, in most cases
C<::   >.  Lastly, I<menu_entry_description> is for the description.

=item multitable_head

=item multitable_body

=item row

In C<@multitable>, a I<multitable_head> container contains all the rows
with C<@headitem>, while I<multitable_body> contains the rows associated
with C<@item>.  A I<row> container contains the C<@item> and C<@tab>
forming a row.

=item paragraph

A paragraph.  The C<contents> of a paragraph (like other container
elements for Texinfo content) are elements representing the contents of
the paragraph in the order they occur, such as text elements
without a C<cmdname> or C<type>, or @-command elements for commands
appearing in the paragraph.

=item preformatted

Texinfo code within a format that is not filled.  Happens within some
block commands like C<@example>, but also in menu (in menu descriptions,
menu comments...).

=item rawpreformatted

Texinfo code within raw output format block commands such as C<@tex>
or C<@html>.

=item table_entry

=item table_term

=item table_definition

=item inter_item

Those containers appear in C<@table>, C<@ftable> and C<@vtable>.
A I<table_entry> container contains an entire row of the table.
It contains a I<table_term> container, which holds all the C<@item> and
C<@itemx> lines.  This is followed by a I<table_definition> container, which
holds the content that is to go into the second column of the table.

If there is any content before an C<@itemx> (normally only comments,
empty lines or maybe index entries are allowed), it will be in
a container with type I<inter_item> at the same level of C<@item>
and C<@itemx>, in a I<table_term>.

=back

=head2 Information available in the C<info> key

=over

=item arg_line

The string correspond to the line after the @-command
for @-commands that have special arguments on their line,
and for C<@macro> line.

=item command_name

Name of commands that can be defined dynamically.
The name of index command or definfoenclose defined command (also
available in I<cmdname> for those commands).
The name of user defined macro, rmacro or linemacro called
associated with the element holding the arguments of the user defined command
call.

=item delimiter

C<@verb> delimiter is in I<delimiter>.

=item inserted

Set if the element is not in the Texinfo input code, but is inserted
as a default for @-command argument or as a definition command automatically
inserted category (for example I<Function> for C<@defun>).

=item spaces_after_argument

A reference to an element containing the spaces after @-command arguments
before a comma, a closing brace or at end of line, for some @-commands and
bracketed content type with opening brace, and line commands and block command
lines taking Texinfo as argument and comma delimited arguments.  Depending on
the @-command, the I<spaces_after_argument> is associated with the @-command
element, or with each argument element.

=item spaces_after_cmd_before_arg

For accent commands with spaces following the @-command, like:

 @ringaccent A
 @^ u

there is a I<spaces_after_cmd_before_arg> key linking to an element
containing the spaces appearing after the command in I<text>.

Space between a brace @-command name and its opening brace also
ends up in I<spaces_after_cmd_before_arg>.  It is not recommended
to leave space between an @-command name and its opening brace.

=item spaces_before_argument

A reference to an element containing the spaces following the opening brace of
some @-commands with braces and bracketed content type, spaces following
@-commands for line commands and block command taking Texinfo as argument, and
spaces following comma delimited arguments.  For context brace commands, line
commands and block commands, I<spaces_before_argument> is associated with the
@-command element, for other brace commands and for spaces after comma, it is
associated with each argument element.

=back

=head2 Information available in the C<extra> key
X<Texinfo tree element extra key>

=head3 Extra keys available for more than one @-command

=over

=item element_node

The node element in the parsed tree containing the element.
Set for @-commands elements that have an associated
index entry and for C<@nodedescription>.

=item element_region

The region command (C<@copying>, C<@titlepage>) containing the element,
if it is in such an environement.  Set for @-commands elements that have an
associated index entry and for @anchor.

=item index_entry

The index entry information is associated to @-commands that have an associated
index entry.  The associated information should not be directly accessed,
instead L<C<Texinfo::Common::lookup_index_entry>|Texinfo::Common/($index_entry, $index_info) = lookup_index_entry($index_entry_info, $indices_information)>
should be called on the C<extra> I<index_entry> value:

   my ($index_entry, $index_info)
    = Texinfo::Common::lookup_index_entry(
                        $element->{'extra'}->{'index_entry'},
                        $indices_information);

The I<$indices_information> is the information on a Texinfo manual indices
obtained from
L<< C<Texinfo::Document::indices_information>|Texinfo::Document/$indices_information = $document->indices_information() >>.
The index entry information hash returned by
C<Texinfo::Common::lookup_index_entry> is described in
L<Texinfo::Document/index_entries>.

Currently, the I<index_entry> value is an array reference
with an index name as first element and the index entry number in that index
(1-based) as second element.

=item index_ignore_chars

A string containing the characters flagged as ignored in key sorting in the
document by setting flags such as I<txiindexbackslashignore>.  Set, if
not empty, for @-commands elements that have an associated index entry.

=item misc_args

An array holding strings, the arguments of @-commands taking simple
textual arguments as arguments, like C<@everyheadingmarks>,
C<@frenchspacing>, C<@alias>, C<@synindex>, C<@columnfractions>.

=item text_arg

The string correspond to the line after the @-command for @-commands
that have an argument interpreted as simple text, like C<@setfilename>,
C<@end> or C<@documentencoding>.

=back

=head3 Extra keys specific of certain @-commands or containers

=over

=item C<@abbr>

=item C<@acronym>

The first argument normalized is in I<normalized>.

=item C<@anchor>

=item C<@float>

@-commands that are targets for cross-references have a I<normalized> key for
the normalized label, built as specified in the Texinfo documentation in the
I<HTML Xref> node.  There is also a I<node_content> key for an element holding
the corresponding content.

=item C<@author>

If in a C<@titlepage>, the titlepage is in I<titlepage>, if in
C<@quotation> or C<@smallquotation>, the corresponding tree element
is in I<quotation>.

The author tree element is in the I<authors> array of the C<@titlepage>
or the C<@quotation> or C<@smallquotation> it is associated with.

=item C<@click>

In I<clickstyle> there is the current clickstyle command.

=item C<def_line>

=item line definition command

I<def_command> holds the line definition command name, without x if the line
definition command is an x form of a block definition command.  For a
C<def_line> container, I<def_command> holds the command name associated
with the C<def_line>.  I<original_def_cmdname> is the original def command
name.

If the element is a definition line command and is an x form of a block
definition command, it has I<not_after_command> set if not appearing
after the block definition command without x.

The I<def_index_element> is a Texinfo tree element corresponding to
the index entry associated to the definition line, based on the
name and class.  If needed this element is based on translated strings.
In that case, if C<@documentlanguage> is defined where the element
is located, I<documentlanguage> holds the documentlanguage value.
I<def_index_ref_element> is similar, but not translated, and only set if
there could have been a translation.

The I<omit_def_name_space> key value is set and true if the Texinfo variable
C<txidefnamenospace> was set, signaling that the space between function
definition name and arguments should be omitted.

=item C<@definfoenclose> defined commands

I<begin> holds the string beginning the C<@definfoenclose>,
I<end> holds the string ending the C<@definfoenclose>.

=item C<@documentencoding>

The argument, normalized is in I<input_encoding_name>.

=item C<@enumerate>

The I<enumerate_specification> C<extra> key contains the enumerate argument.

=item C<@float>

=item C<@listoffloats>

If C<@float> has a first argument, and for C<@listoffloats> argument there
is a I<float_type> key with the normalized float type.

I<caption> and I<shortcaption> hold the corresponding tree elements
associated to a C<@float>.  The C<@caption> or C<@shortcaption> have the
float tree element stored in I<float>.

=item index entry @-command

=item C<@subentry>

If an index entry @-command, such as C<@cindex>, or a C<@subentry> contains
a C<@sortas> command, I<sortas> holds the C<@sortas> command content
formatted as plain text.

I<subentry> links to the next level C<@subentry> element.  I<subentry_parent>
links to the previous level element.

Index entry @-command (but not C<@subentry>) can also have I<seentry>
and I<seealso> keys that link to the corresponding @-commands elements.

=item C<@inlinefmt>

=item C<@inlineraw>

=item C<@inlinefmtifelse>

=item C<@inlineifclear>

=item C<@inlineifset>

The first argument is in I<format>.  If an argument has been determined
as being expanded by the Parser, the index of this argument is in
I<expand_index>.  Index numbering begins at 0, but the first argument is
always the format or flag name, so, if set, it should be 1 or 2 for
C<@inlinefmtifelse>, and 1 for other commands.

=item C<@item> in C<@enumerate> or C<@itemize>

The I<item_number> C<extra> key holds the number of this item.

=item C<@item> and C<@tab> in C<@multitable>

The I<cell_number> index key holds the index of the column of
the cell.

=item C<@itemize>

=item C<@table>

=item C<@vtable>

=item C<@ftable>

The I<command_as_argument> C<extra> key points to the @-command
as argument on the @-command line.

If the command in argument for C<@table>, C<@vtable> or C<@ftable>
is C<@kbd> and the context and C<@kbdinputstyle> is such that C<@kbd>
should be formatted as code, the I<command_as_argument_kbd_code>
C<extra> key is set to 1.

=item C<@kbd>

I<code> is set depending on the context and C<@kbdinputstyle>.

=item C<@macro>

I<invalid_syntax> is set if there was an error on the C<@macro>
line.  C<info> key hash I<arg_line> holds the line after C<@macro>.

=item C<menu_entry_node>

Extra keys with information about the node entry label same as those
appearing in the C<@node> I<line_arg> explicit directions arguments
C<extra> hash labels information.

=item C<@multitable>

The key I<max_columns> holds the maximal number of columns.  If there is a
C<@columnfractions> as argument, then the I<columnfractions> key is associated
with the element for the @columnfractions command.

=item C<@node>

Explicit directions labels information are available in the I<line_arg>
node directions arguments of C<@node>.  Each I<line_arg> argument element
C<extra> hash I<node_content> key value is an element holding the
contents corresponding to the node name.  There is also a I<manual_content> key
if there is an associated external manual name, and a I<normalized> key for the
normalized label, built as specified in the I<HTML Xref> Texinfo documentation
node.

If you called L<Texinfo::Structuring::nodes_tree|Texinfo::Structuring/$nodes_list = nodes_tree($document)>,
the I<node_directions> hash in the C<@node> element C<extra> associates
I<up>, I<next> and I<prev> keys to the elements corresponding to the node
line directions.

An I<associated_section> key holds the tree element of the
sectioning command that follows the node.  An I<node_preceding_part>
key holds the tree element of the C<@part> that precedes the node,
if there is no sectioning command between the C<@part> and the node.
A I<node_description> key holds the first C<@nodedescription> associated
to the node.

A node containing a menu have a I<menus> key which refers to an array of
references to menu elements occuring in the node.

The first node containing a C<@printindex> @-command has the I<isindex>
key set.

=item C<paragraph>

The I<indent> or I<noindent> key value is set if the corresponding
@-commands are associated with that paragraph.

=item C<@part>

The next sectioning command tree element is in I<part_associated_section>.
The following node tree element is in I<part_following_node> if there is
no sectioning command between the C<@part> and the node.

=item C<@ref>

=item C<@xref>

=item C<@pxref>

=item C<@inforef>

The I<brace_arg> corresponding to the node argument holds information on
the label, with the same information in the C<extra> hash as for the
C<@node> I<line_arg> explicit directions arguments.

=item C<row>

The I<row_number> index key holds the index of the row in
the C<@multitable>.

=item sectioning command

The node preceding the command is in I<associated_node>.
The part preceding the command is in I<associated_part>.
If the level of the document was modified by C<@raisections>
or C<@lowersections>, the differential level is in I<level_modifier>.

Other C<extra> keys are set when you call L<Texinfo::Structuring::sectioning_structure|Texinfo::Structuring/$sections_list = sectioning_structure($document)>.

=item C<untranslated_def_line_arg>

I<documentlanguage> holds the C<@documentlanguage> value.
If there is a translation context, it should be in I<translation_context>.

=back

=head1 SEE ALSO

L<Texinfo manual|https://www.gnu.org/software/texinfo/manual/texinfo/>.

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
