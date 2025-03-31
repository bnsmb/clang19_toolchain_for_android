# DocBook.pm: output tree as DocBook.
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

package Texinfo::Convert::DocBook;

use 5.006;
use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Texinfo::Commands;
use Texinfo::Common;

# for debugging
use Texinfo::Convert::Texinfo;

# for section_level_adjusted_command_name
use Texinfo::Structuring;

use Texinfo::Convert::Unicode;
use Texinfo::Convert::Utils;
use Texinfo::Convert::Text;
use Texinfo::Convert::Converter;
use Texinfo::Convert::Plaintext;
#use Data::Dumper;
use Carp qw(cluck);

our @ISA = qw(Texinfo::Convert::Converter);

our $VERSION = '7.2';

my %brace_commands = %Texinfo::Commands::brace_commands;

my $nbsp = '&#'.hex('00A0').';';

my %defaults = (
  # Customization option variables
  'FORMAT_MENU'          => 'nomenu',
  'EXTENSION'            => 'xml', # dbk?
  'OUTPUT_ENCODING_NAME' => 'utf-8',
  'SPLIT'                => '',
  'documentlanguage'     => undef,
  'OPEN_QUOTE_SYMBOL'    => '&#'.hex('2018').';',
  'CLOSE_QUOTE_SYMBOL'   => '&#'.hex('2019').';',
  'USE_NUMERIC_ENTITY'   => 1,
  'NO_TOP_NODE_OUTPUT'   => 1,
);

my @docbook_image_extensions
  = ('eps', 'gif', 'jpg', 'jpeg', 'pdf', 'png', 'svg');

my %docbook_special_quotations;
foreach my $special_quotation (
    'caution', 'important', 'note', 'tip', 'warning') {
  $docbook_special_quotations{$special_quotation} = 1;
}

# For '*', there is no line break in DocBook, except in cmdsynopsis (in this
# case it is <sbr>).  But currently we don't use cmdsynopsis, and it is
# unlikely we ever will.
my %docbook_specific_formatting = (
  'TeX' => '&tex;',
  'LaTeX' => '&latex;',
  "\t" => $nbsp,
  "\n" => $nbsp,
  " " => $nbsp,
  'tie' => $nbsp,
);
my %docbook_no_arg_commands_formatting
  = %Texinfo::Convert::Converter::xml_text_entity_no_arg_commands_formatting;

foreach my $command (keys(%Texinfo::Convert::Unicode::unicode_entities)) {
  $docbook_no_arg_commands_formatting{$command}
   = $Texinfo::Convert::Unicode::unicode_entities{$command};
}

foreach my $command (keys(%docbook_specific_formatting)) {
  $docbook_no_arg_commands_formatting{$command}
    = $docbook_specific_formatting{$command};
}

my %quoted_style_commands = (
  'samp' => 1,
);

my %upper_case_style_commands = (
  'sc' => 1,
);

my @inline_elements = ('emphasis', 'abbrev', 'acronym', 'link',
  'inlinemediaobject', 'firstterm', 'footnote', 'replaceable',
  'subscript', 'superscript', 'wordasword');
my %inline_elements;
foreach my $inline_element (@inline_elements) {
  $inline_elements{$inline_element} = 1;
};

my %style_attribute_commands;
%style_attribute_commands = (
      'b'           => 'emphasis role="bold"',
      'cite'        => 'citetitle',
      'code'        => 'literal',
      'command'     => 'command',
      'dfn'         => 'firstterm',
      'emph'        => 'emphasis',
      'env'         => 'envar',
      'file'        => 'filename',
      'footnote'    => 'footnote',   # brace context command
      'headitemfont' => 'emphasis role="bold"', # actually <th> instead of <td>
      'i'           => 'emphasis',
      'indicateurl' => 'literal',
      'kbd'         => 'userinput',
      'key'         => 'keycap',
      'math'        => 'mathphrase', # brace context command
      'option'      => 'option',
      'r'           => '',
      'samp'        => 'literal',
      'sansserif'   => '',
      'strong'      => 'emphasis role="bold"',
      'sub'         => 'subscript',
      'sup'         => 'superscript',
      't'           => 'literal',
      'var'         => 'replaceable',
      'verb'        => 'literal',     # brace other command
);

my %style_brace_types = map {$_ => 1} ('style_other', 'style_code', 'style_no_code');
# @all_style_commands is the union of style brace commands, commands
# in %style_attribute_commands and a few other, some not style brace commands.
# Using keys of a map generated hash does like uniq, it avoids duplicates.
# The first grep selects style brace commands, ie commands with %brace_commands
# type in %style_brace_types.
my @all_style_commands = keys %{{ map { $_ => 1 }
    ((grep {$style_brace_types{$brace_commands{$_}}} keys(%brace_commands)),
      keys(%style_attribute_commands), 'w', 'dmn', 'titlefont') }};

# special string for 'w'.
my $w_command_mark = '<!-- /@w -->';

my %style_commands_formatting;
foreach my $command(@all_style_commands) {
  $style_commands_formatting{$command} = {};
  if ($style_attribute_commands{$command}) {
    $style_commands_formatting{$command}->{'attribute'}
      = $style_attribute_commands{$command};
  }
  if ($quoted_style_commands{$command}) {
    $style_commands_formatting{$command}->{'quote'} = 1;
  }
  if ($upper_case_style_commands{$command}) {
    $style_commands_formatting{$command}->{'upper_case'} = 1;
  }
}

my %docbook_line_elements_with_arg_map = (
  'exdent' => 'simpara role="exdent"',
  'center' => 'simpara role="center"',
);

my %docbook_nobrace_commands = %Texinfo::Commands::nobrace_commands;
foreach my $command ('item', 'headitem', 'tab',
   keys(%docbook_no_arg_commands_formatting)) {
  delete $docbook_nobrace_commands{$command};
}

my %docbook_line_commands = %Texinfo::Commands::line_commands;
foreach my $command ('itemx') {
  delete $docbook_line_commands{$command};
}

my %docbook_global_commands = (
  'documentlanguage' => 1,
);

my %default_args_code_style
  = %Texinfo::Convert::Converter::default_args_code_style;

my %defcommand_name_type = (
 'defline'   => 'varname',
 'deftypeline' => 'varname',
 'defcv'     => 'property',
 'deffn'     => 'function',
 'defop'     => 'methodname',
 'deftp'     => 'structname',
 'deftypecv' => 'property',
 'deftypefn' => 'function',
 'deftypeop' => 'methodname',
 'deftypevr' => 'varname',
 'defvr'     => 'varname',
);

my %def_argument_types_docbook = (
  'def_type' => ['returnvalue'],
  'def_class' => ['ooclass', 'classname'],
  # TODO or a simple emphasis?
  # replaceable is not used here, such that replaceable is only
  # used if there is an explicit @var{}
  'def_arg' => ['emphasis role="arg"'],
  'def_typearg' => ['type'],
);

my %ignored_block_commands;
foreach my $block_command ('copying', 'titlepage', 'documentdescription',
    'nodedescriptionblock') {
  $ignored_block_commands{$block_command} = 1;
}

my %ignored_types;
foreach my $type (
            'ignorable_spaces_after_command',
            'spaces_after_close_brace',
            'spaces_before_paragraph',
            'menu_entry_leading_text',
            'menu_entry_separator',
            'postamble_after_end',
            'preamble_before_beginning',
            'preamble_before_setfilename',
            'spaces_at_end',
  ) {
  $ignored_types{$type} = 1;
}

my %type_elements = (
  'paragraph' => 'para',
  'table_definition' => 'listitem',
  'table_entry' => 'varlistentry',
  'row' => 'row',
  'multitable_head' => 'thead',
  'multitable_body' => 'tbody',
  # Unfortunatly there does not seem to be anything better in DocBook.
  'def_item' => 'blockquote',
);

# Empty containers do not happen often, mainly when a source mark
# needs to be kept.  However, it is more robust to remove explictely
# empty containers that we want to remove instead of relying on a
# specific tree.
my %container_ignored_if_empty = (
  'preformatted' => 1,
  'menu_comment' => 1,
);

my %default_context_block_commands = (
  'float' => 1,
);

my %docbook_preformatted_formats = (
# command
   'example' => 'screen',
   'smallexample' => 'screen',
   'display' => 'literallayout',
   'smalldisplay' => 'literallayout',
   'lisp' => 'programlisting',
   'smalllisp' => 'programlisting',
   'format' => 'literallayout',
   'smallformat' => 'literallayout',
# type
   'menu_comment' => 'literallayout',
   'menu_description' => 'literallayout',
);

my %sectioning_commands_done;

sub converter_defaults($$)
{
  return \%defaults;
}


sub converter_initialize($)
{
  my $self = shift;

  $self->{'context_block_commands'} = {%default_context_block_commands};
  foreach my $raw (grep {$Texinfo::Commands::block_commands{$_} eq 'format_raw'}
                        keys(%Texinfo::Commands::block_commands)) {
    $self->{'context_block_commands'}->{$raw} = 1
         if $self->{'expanded_formats'}->{$raw};
  }

  foreach my $conf ('OPEN_QUOTE_SYMBOL', 'CLOSE_QUOTE_SYMBOL') {
    if (not defined($self->get_conf($conf))) {
      # override undef set in init file/command line
      $self->force_conf($conf, '');
    }
  }
}

sub conversion_initialization($;$)
{
  my $self = shift;
  my $document = shift;

  if ($document) {
    $self->set_document($document);
  }

  $self->{'document_context'} = [];
  _new_document_context($self);
  $self->{'lang_stack'} = [];
  $self->{'in_skipped_node_top'} = 0;
  %sectioning_commands_done = ();
}

sub conversion_finalization($)
{
  my $self = shift;

  pop @{$self->{'document_context'}};
}

sub convert($$)
{
  my $self = shift;
  my $document = shift;

  $self->conversion_initialization($document);

  my $root = $document->tree();

  push @{$self->{'lang_stack'}}, '';

  my $result = $self->convert_tree($root);

  $self->conversion_finalization();

  return $result;
}

sub convert_tree($$)
{
  my $self = shift;
  my $root = shift;

  if (scalar(@{$self->{'lang_stack'}}) == 0) {
    push @{$self->{'lang_stack'}}, '';
  }
  return _convert($self, $root);
}

# not the same as a default for @documentlanguage.  $DEFAULT_LANG
# is used in the lang attribute, but if there is no @documentlanguag,
# the lang_stack will start with an empty string, not with $DEFAULT_LANG.
my $DEFAULT_LANG = 'en';
sub conversion_output_begin($;$$)
{
  my $self = shift;
  my $output_file = shift;
  my $output_filename = shift;

  my $encoding = '';
  if ($self->get_conf('OUTPUT_ENCODING_NAME')
      and $self->get_conf('OUTPUT_ENCODING_NAME') ne 'utf-8') {
    $encoding = " encoding=\"".$self->get_conf('OUTPUT_ENCODING_NAME')."\" ";
  }

  my $id;
  if ($output_file ne '') {
    # FIXME DocBook 5 id -> xml:id
    $id = " id=\"".$self->xml_protect_text($output_filename)."\"";
  } else {
    $id = '';
  }

  my $lang = $DEFAULT_LANG;
  $self->set_global_document_commands('preamble', ['documentlanguage']);
  if (defined($self->get_conf('documentlanguage'))) {
    $lang = $self->get_conf('documentlanguage');
    push @{$self->{'lang_stack'}}, $self->get_conf('documentlanguage');
  } else {
    push @{$self->{'lang_stack'}}, '';
  }
  my $result =  "<?xml version=\"1.0\"${encoding}?>".'
<!DOCTYPE book PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd" [
  <!ENTITY tex "TeX">
  <!ENTITY latex "LaTeX">
]>
'. "<book${id} lang=\"$lang\">\n";

  my $legalnotice;
  my $global_commands;
  if ($self->{'document'}) {
    $global_commands = $self->{'document'}->global_commands_information();
  }
  if ($global_commands and $global_commands->{'copying'}) {
    my $copying_element = $global_commands->{'copying'};
    my $copying_result
     = $self->convert_tree({'contents' => $copying_element->{'contents'}});
    if ($copying_result ne '') {
      $legalnotice = "<legalnotice>$copying_result</legalnotice>";
    }
  }

  my $fulltitle_command;
  if ($global_commands) {
    foreach my $title_cmdname ('title', 'shorttitlepage', 'titlefont') {
      if ($global_commands->{$title_cmdname}) {
        my $command = $global_commands->{$title_cmdname};
        next if (!$command->{'args'}
                 or !$command->{'args'}->[0]->{'contents'});
        $fulltitle_command = $command;
        last;
      }
    }
  }

  # get informations from the @titlepage.  Since the fulltitle is gathered
  # independently, only author and subtitle are gathered here.
  my $subtitle_info = '';
  my $authors_info = '';
  if ($global_commands and $global_commands->{'titlepage'}) {
    my $collected_commands = Texinfo::Common::collect_commands_list_in_tree(
            $global_commands->{'titlepage'}, ['author', 'subtitle']);

    my @authors_elements;
    my $subtitle_text = '';
    if (scalar(@{$collected_commands})) {
      foreach my $element (@{$collected_commands}) {
        my $cmdname = $element->{'cmdname'};
        if ($cmdname eq 'author') {
          push @authors_elements, $element;
        } elsif ($cmdname eq 'subtitle') {
          # concatenate the text of @subtitle as DocBook only allows one.
          my ($arg, $end_line)
            = _convert_argument_and_end_line($self, $element);
          $subtitle_text .= $arg . $end_line
        }
      }
    }
    if ($subtitle_text ne '') {
      chomp ($subtitle_text);
      $subtitle_info = "<subtitle>$subtitle_text</subtitle>\n";
    }

    if (scalar(@authors_elements)) {
      # using authorgroup and collab is the best, because it doesn't require
      # knowing people name decomposition.  Also it should work for group names.
      # FIXME dblatex ignores collab/collabname.
      $authors_info .= "<authorgroup>\n";
      foreach my $element (@authors_elements) {
        my ($arg, $end_line) = _convert_argument_and_end_line($self, $element);
        # FIXME DocBook 5 no more collabname, merged with other elements in
        # orgname, which is much more specific than collabname, it is for an
        # organisation and therefore not suitable here.
        # https://tdg.docbook.org/tdg/5.0/ch01#introduction-whats-new
        # person/personname is not suitable either, because in Texinfo @author
        # may correspond to more than one author, and also because we do not
        # have the information in Texinfo needed for <person>, which requires
        # a split of the name in honorific, firstname, surname...
        # https://tdg.docbook.org/tdg/5.0/personname
        my $result = "<collab><collabname>$arg</collabname></collab>$end_line";
        chomp ($result);
        $result .= "\n";
        $authors_info .= $result;
      }
      $authors_info .= "</authorgroup>\n";
    }
  }

  my $settitle_command;
  if ($global_commands and $global_commands->{'settitle'}) {
    my $command = $global_commands->{'settitle'};
    $settitle_command = $command
      unless (!$command->{'args'}
              or !$command->{'args'}->[0]->{'contents'});
  }

  my $titleabbrev_command;
  if ($fulltitle_command) {
    $titleabbrev_command = $settitle_command;
  } elsif ($settitle_command) {
    $fulltitle_command = $settitle_command;
  } elsif (defined($legalnotice) and $global_commands
           and $global_commands->{'top'}) {
    # if there is a legalnotice, we really want to have a title
    # preceding it, so we also use @top
    my $command = $global_commands->{'top'};
    $fulltitle_command = $command
      unless (!$command->{'args'}
              or !$command->{'args'}->[0]->{'contents'});
  }

  my $title_info = '';

  if ($fulltitle_command) {
    foreach my $element_command ([$fulltitle_command, 'title'],
                                 [$titleabbrev_command, 'titleabbrev']) {
      my ($element, $docbook_element) = @$element_command;
      if (defined($element)) {
        my ($arg, $end_line) = _convert_argument_and_end_line($self, $element);
        my $result = "<$docbook_element>$arg</$docbook_element>$end_line";
        chomp ($result);
        $result .= "\n";
        $title_info .= $result;
        if ($docbook_element eq 'title') {
          $title_info .= $subtitle_info;
        }
      }
    }
  }
  $self->set_global_document_commands('before', ['documentlanguage']);

  my $document_info = '';
  $document_info .= $title_info . $authors_info;
  $document_info .= $legalnotice if (defined($legalnotice));

  # we duplicate title info, as it is explicitly said in the DocBook manual
  # that it can be duplicated if exactly the same
  $result .= $title_info;

  if ($document_info ne '') {
    # FIXME DocBook 5 bookinfo->info
    $result .= "<bookinfo>$document_info</bookinfo>\n";
  }

  return $result;
}

sub conversion_output_end($)
{
  my $self = shift;
  return "</book>\n";
}

sub output($$)
{
  my $self = shift;
  my $document = shift;

  return $self->output_tree($document);
}

my %docbook_sections = (
  'top'  => 'chapter',
  'part' => 'part',
  'chapter'  => 'chapter',
  'unnumbered'  => 'chapter',
  'centerchap'  => 'chapter',
  'appendix' => 'appendix',
  # chapter would have been the best choice here, but it is not a possibility
  # for renderas in bridgehead (possibilities are sect1 to 5 and other).
  # other is rendered small, smaller than sect1.  So use sect1, even though
  # it matches better with the @heading level.
  'majorheading' => 'sect1',
  'chapheading' => 'sect1',
  'heading' => 'sect1',
  'subheading' => 'sect2',
  'subsubheading' => 'sect3',
  2 => 'sect1',
  3 => 'sect2',
  4 => 'sect3'
);

my %docbook_special_unnumbered;
foreach my $special_unnumbered ('acknowledgements', 'colophon',
                                'dedication', 'preface') {
  $docbook_special_unnumbered{$special_unnumbered} = 1;
}

# element is not texinfo tree element here, but xml element
sub _docbook_section_element($$)
{
  my $self = shift;
  my $element = shift;

  if ($element->{'extra'}
      and defined($element->{'extra'}->{'section_level'})) {
    my $heading_level = $element->{'extra'}->{'section_level'};
    if (exists $docbook_sections{$heading_level}) {
      return $docbook_sections{$heading_level};
    }
  }
  my $level_adjusted_cmdname
     = Texinfo::Structuring::section_level_adjusted_command_name($element);
  if ($level_adjusted_cmdname eq 'unnumbered'
      and $element->{'extra'}
      and $element->{'extra'}->{'associated_node'}
      and $element->{'extra'}->{'associated_node'}->{'extra'}
      and $element->{'extra'}->{'associated_node'}->{'extra'}->{'normalized'}
      and $docbook_special_unnumbered{lc(
           $element->{'extra'}->{'associated_node'}->{'extra'}->{'normalized'})}) {
    return lc($element->{'extra'}->{'associated_node'}->{'extra'}->{'normalized'});
  }

  if (defined($docbook_sections{$level_adjusted_cmdname})) {
    return $docbook_sections{$level_adjusted_cmdname};
  } else {
    # special case of no structuring information available for a regular
    # sectioning command, like @section, @appendix, if Structuring
    # sectioning_structure was not called.
    my $heading_level = Texinfo::Common::section_level($element);
    return $docbook_sections{$heading_level};
  }
}

sub _index_entry($$)
{
  my $self = shift;
  my $element = shift;
  if ($element->{'extra'} and $element->{'extra'}->{'index_entry'}) {

    my $indices_information;
    if ($self->{'document'}) {
      $indices_information = $self->{'document'}->indices_information();
    }

    my ($index_entry, $index_info)
     = Texinfo::Common::lookup_index_entry($element->{'extra'}->{'index_entry'},
                                           $indices_information);
    # FIXME DocBook 5 role->type
    my $result = "<indexterm role=\"$index_entry->{'index_name'}\">";

    _new_document_context($self);
    $self->{'document_context'}->[-1]->{'monospace'}->[-1] = 1
      if ($index_info->{'in_code'});
    $result .= "<primary>";
    $result .= _convert($self, Texinfo::Common::index_content_element($element));
    $result .= "</primary>";

    # Add any index subentries.
    my $tmp = $index_entry->{'entry_element'};
    my $level = "secondary";
    while ($tmp->{'extra'}->{'subentry'}) {
      $result .= "<$level>";
      $tmp = $tmp->{'extra'}->{'subentry'};
      $result .= _convert($self, $tmp->{'args'}->[0]);
      $result .= "</$level>";
      $level = "tertiary";
    }
    if ($index_entry->{'entry_element'}->{'extra'}->{'seeentry'}) {
      $result .= "<see>";
      # args is set as the extra information is added when closing braces
      $result .= _convert($self, $index_entry->{'entry_element'}
                                   ->{'extra'}->{'seeentry'}->{'args'}->[0]);
      $result .= "</see>";
    }
    if ($index_entry->{'entry_element'}->{'extra'}->{'seealso'}) {
      $result .= "<seealso>";
      $result .= _convert($self, $index_entry->{'entry_element'}
                               ->{'extra'}->{'seealso'}->{'args'}->[0]);
      $result .= "</seealso>";
    }

    pop @{$self->{'document_context'}};

    $result .= "</indexterm>";
    return $result;
  }
  return '';
}

sub _parse_attribute($)
{
  my $element = shift;
  return ('', '') if (!defined($element));
  my $attributes = '';
  if ($element =~ /^(\w+)(\s+.*)/) {
    $element = $1;
    $attributes = $2;
  }
  return ($element, $attributes);
}

sub _protect_text($$)
{
  my $self = shift;
  my $text = shift;
  my $result = $self->xml_protect_text($text);
  # form feed not allowed in XML
  $result =~ s/\f/ /g;
  return $result;
}

sub _convert_argument_and_end_line($$)
{
  my $self = shift;
  my $element = shift;

  my $converted = $self->convert_tree($element->{'args'}->[-1]);
  my $end_line = $self->format_comment_or_return_end_line($element);
  return ($converted, $end_line);
}

sub _output_anchor($)
{
  my $element = shift;

  if ($element->{'extra'} and $element->{'extra'}->{'is_target'}) {
    # FIXME DocBook 5 id -> xml:id
    return "<anchor id=\"$element->{'extra'}->{'normalized'}\"/>";
  } else {
    return '';
  }
}

sub _new_document_context($)
{
  my $self = shift;
  push (@{$self->{'document_context'}}, {
                            'monospace' => [0],
                            'upper_case' => [0],
                            'no_break' => [0],
                          });
}

sub _convert_def_line($$)
{
  my $self = shift;
  my $element = shift;

  my $result = "<synopsis>";;
  $result .= _index_entry($self, $element);
  _new_document_context($self);
  $self->{'document_context'}->[-1]->{'monospace'}->[0] = 1;
  $self->{'document_context'}->[-1]->{'inline'}++;
  if ($element->{'args'}
      and $element->{'args'}->[0]->{'contents'}) {
    my $main_command;
    if ($Texinfo::Common::def_aliases{$element->{'extra'}->{'def_command'}}) {
      $main_command
        = $Texinfo::Common::def_aliases{$element->{'extra'}->{'def_command'}};
    } else {
      $main_command = $element->{'extra'}->{'def_command'};
    }
    foreach my $arg (@{$element->{'args'}->[0]->{'contents'}}) {
      my $type = $arg->{'type'};

      my $content = _convert($self, $arg);
      if ($type eq 'spaces' or $type eq 'delimiter') {
        $result .= $content;
      } elsif ($type eq 'def_category') {
        $result .= "<phrase role=\"category\"><emphasis role=\"bold\">"
                     ."$content</emphasis>:</phrase>";
      } elsif ($type eq 'def_name') {
        $result .= "<$defcommand_name_type{$main_command}>$content"
                       ."</$defcommand_name_type{$main_command}>";
      } else {
        if (!defined($def_argument_types_docbook{$type})) {
          warn "BUG: no def_argument_types_docbook for $type";
          return undef;
        }
        foreach my $element_attribute (reverse (
                               @{$def_argument_types_docbook{$type}})) {
          my ($element, $attribute_text) = _parse_attribute($element_attribute);
          $content = "<$element${attribute_text}>$content</$element>";
        }
        $result .= $content;
      }
    }
  }
  pop @{$self->{'document_context'}};
  $result .= "</synopsis>";
  $result .= "\n";
  return $result;
}

my $debug_global_element_nr = 0;


sub _convert($$;$);

sub _convert($$;$)
{
  my $self = shift;
  my $element = shift;

  my $debug_element_nr;
  #if (1) {
  if (0) { # verbose even for debugging
    $debug_element_nr = $debug_global_element_nr++;
    print STDERR "element $debug_element_nr";
    print STDERR " cmd: $element->{'cmdname'}," if ($element->{'cmdname'});
    print STDERR " type: $element->{'type'}" if ($element->{'type'});
    my $text = $element->{'text'};
    if (defined($text)) {
      $text =~ s/\n/\\n/;
      print STDERR " text: $text";
    }
    print STDERR "\n";
  }

  return '' if ($element->{'type'} and $ignored_types{$element->{'type'}});
  my $result = '';
  if (defined($element->{'text'})) {
    if (defined($element->{'type'}) and $element->{'type'} eq '_converted') {
      return $element->{'text'};
    } elsif ($self->{'document_context'}->[-1]->{'raw'}) {
      return $element->{'text'};
    }
    $result = $element->{'text'};
    if ($self->{'document_context'}->[-1]->{'upper_case'}->[-1]) {
      $result = uc($result);
    }
    if ($self->{'document_context'}->[-1]->{'no_break'}->[-1]) {
      $result =~ s/\n/ /g;
      $result =~ s/ +/$nbsp/g;
    }
    $result = _protect_text($self, $result);
    if (! defined($element->{'type'}) or $element->{'type'} ne 'raw') {
      if (!$self->{'document_context'}->[-1]->{'monospace'}->[-1]) {
        $result = $self->xml_format_text_with_numeric_entities($result);
      }
    }
    #warn "had text `$element->{'text'}', returning $result\n";
    return $result;
  }

  #warn " onto main conditional\n";
  my $cmdname;
  my @close_format_elements;
  if (defined($element->{'cmdname'})) {
    $cmdname = $element->{'cmdname'};
    #warn "  got cmdname $cmdname\n";
    if (defined($docbook_no_arg_commands_formatting{$cmdname})) {
      #warn "  has no_arg_commands_formatting \n";
      my $command_name;
      if ($cmdname eq 'click' and $element->{'extra'}
          and defined($element->{'extra'}->{'clickstyle'})) {
        $command_name = $element->{'extra'}->{'clickstyle'};
      } elsif ($self->{'document_context'}->[-1]->{'upper_case'}->[-1]
               and $Texinfo::Commands::letter_no_arg_commands{$cmdname}
               and $Texinfo::Commands::letter_no_arg_commands{uc($cmdname)}) {
        $command_name = uc($cmdname)
      } else {
        $command_name = $cmdname;
      }
      my $translated_tree
       = Texinfo::Convert::Utils::translated_command_tree($self, $command_name);
      if ($translated_tree) {
        return _convert($self, $translated_tree);
      } else {
        return $docbook_no_arg_commands_formatting{$command_name};
      }
    } elsif ($cmdname eq 'today') {
      return _convert($self, Texinfo::Convert::Utils::expand_today($self));
    } elsif ($Texinfo::Commands::accent_commands{$cmdname}) {
      return $self->xml_accents($element,
               $self->{'document_context'}->[-1]->{'upper_case'}->[-1]);
    } elsif ($cmdname eq 'item' or $cmdname eq 'itemx'
             or $cmdname eq 'headitem' or $cmdname eq 'tab') {
      my $parent_cmdname = $element->{'parent'}->{'cmdname'};
      if ($cmdname eq 'item' and $parent_cmdname
          and ($parent_cmdname eq 'itemize'
               or $parent_cmdname eq 'enumerate')) {
        $result .= "<listitem>";
        if ($parent_cmdname eq 'itemize'
            and !($element->{'parent'}->{'extra'}
                  and $element->{'parent'}->{'extra'}->{'command_as_argument'}
                  and $element->{'parent'}->{'extra'}->{'command_as_argument'}
                                                      ->{'cmdname'} eq 'bullet')
            and $element->{'parent'}->{'args'}) {
          $self->{'pending_prepend'}
            = _convert($self, $element->{'parent'}->{'args'}->[0]);
          $self->{'pending_prepend'} .= " ";
        }
        push @close_format_elements, 'listitem';
      } elsif (($cmdname eq 'item'
                or $cmdname eq 'itemx')
               and $element->{'parent'}->{'type'}
               and $element->{'parent'}->{'type'} eq 'table_term') {

        $result .= "<term>" if ($cmdname eq 'itemx');
        $result .= _index_entry($self, $element);
        if ($element->{'args'}
            and $element->{'args'}->[0]->{'contents'}) {
          my $table_item_tree = $self->table_item_content_tree($element);
          $table_item_tree = $element->{'args'}->[0]
            if (!defined($table_item_tree));

          $result .= _convert($self, $table_item_tree);
        }
        chomp ($result);
        $result .= "\n";
        $result .= "</term>";
      } else {
        unless (($cmdname eq 'item'
                 or $cmdname eq 'headitem'
                 or $cmdname eq 'tab')
                and $element->{'parent'}->{'type'}
                and $element->{'parent'}->{'type'} eq 'row') {
          warn "BUG: multitable cell command not in a row "
            .Texinfo::Common::debug_print_element($element, 1);
        }
        $result .= "<entry>";
        push @close_format_elements, 'entry';
      }
    } elsif ($element->{'type'}
             and $element->{'type'} eq 'index_entry_command') {
      my $end_line;
      if ($element->{'extra'} and $element->{'extra'}->{'index_entry'}
          # this condition is probably always true as extra index_entry is set
          and $element->{'args'}) {
        $end_line = $self->format_comment_or_return_end_line($element);
        if ($self->{'document_context'}->[-1]->{'in_preformatted'}) {
          chomp($end_line);
        }
      } else {
        $end_line = '';
      }
      return _index_entry($self, $element).${end_line};
    } elsif (exists($docbook_nobrace_commands{$cmdname})) {
      return '';
    } elsif (exists($docbook_line_commands{$cmdname})) {
      #warn "  is dbk line command\n";
      if ($docbook_global_commands{$cmdname}) {
        Texinfo::Common::set_informative_command_value($self, $element);
        return '';
      }
      if ($Texinfo::Commands::root_commands{$cmdname}) {
        if ($self->get_conf('NO_TOP_NODE_OUTPUT')) {
          my $node_element;
          if ($cmdname eq 'node') {
            $node_element = $element;
          } elsif ($cmdname eq 'part' and $element->{'extra'}
                   and $element->{'extra'}->{'part_following_node'}) {
            $node_element = $element->{'extra'}->{'part_following_node'};
          }
          if ($node_element or $cmdname eq 'part') {
            # $node_element->{'extra'}->{'normalized'} not defined happens for
            # empty nodes
            if ($node_element and $node_element->{'extra'}
                and $node_element->{'extra'}->{'normalized'}
                and $node_element->{'extra'}->{'normalized'} eq 'Top') {
              $self->{'in_skipped_node_top'} = 1;
            } elsif (defined($self->{'in_skipped_node_top'})
                     and $self->{'in_skipped_node_top'} == 1) {
              $self->{'in_skipped_node_top'} = -1;
            }
          }
        }
        if ($cmdname eq 'node'
            and (not $element->{'extra'}
                 or not $element->{'extra'}->{'associated_section'})) {
          my $anchor = _output_anchor($element);
          $result .= $anchor . "\n" if ($anchor ne '');
        } else {
          # start the section at the associated node or part, or at the
          # sectioning command if there is no associated node nor part
          my $section_element;
          my $part;
          if ($cmdname eq 'node') {
            $section_element = $element->{'extra'}->{'associated_section'};
          } elsif ($cmdname eq 'part') {
            $part = $element;
            if ($element->{'extra'}->{'part_associated_section'}) {
              $section_element = $element->{'extra'}->{'part_associated_section'};
            }
          } else {
            $section_element = $element;
          }
          if ($section_element and $section_element->{'extra'}
              and $section_element->{'extra'}->{'associated_part'}) {
            $part = $section_element->{'extra'}->{'associated_part'};
          }
          my @opened_elements;
          # we need to check if the section was already done in case there is
          # both a node and a part, we do not know in which order they appear.
          if (not ($section_element
                   and $sectioning_commands_done{$section_element})) {
            push @opened_elements, $part if $part;
            if ($section_element) {
              push @opened_elements, $section_element;
            }
          }
          foreach my $opened_element (@opened_elements) {
            if ($section_element and $opened_element eq $section_element) {
              $sectioning_commands_done{$section_element} = 1;
            }
            my $section_attribute = '';
            # It is not clear if a label should be set for @appendix* and
            # @chapter/@*section or not, as the formatter should be
            # able to figure it out.  For @unnumbered or if ! NUMBER_SECTIONS
            # having a label (empty) is important.
            my $label = '';
            if ($opened_element->{'extra'}
                and defined($opened_element->{'extra'}->{'section_number'})
                and ($self->get_conf('NUMBER_SECTIONS')
                     or !defined($self->get_conf('NUMBER_SECTIONS')))) {
              # Looking at docbook2html output, Appendix is appended in the
              # section title, so only the letter is used.
              $label = $opened_element->{'extra'}->{'section_number'};
            }
            my $docbook_sectioning_element
               = _docbook_section_element($self, $opened_element);
            if (! $docbook_special_unnumbered{$docbook_sectioning_element}) {
              $section_attribute .= " label=\"$label\"";
            }
            if ($opened_element->{'extra'}
                and $opened_element->{'extra'}->{'associated_node'}
                and $opened_element->{'extra'}->{'associated_node'}->{'extra'}
                and defined($opened_element->{'extra'}->{'associated_node'}
                                                ->{'extra'}->{'normalized'})) {
              # FIXME DocBook 5 id -> xml:id
              $section_attribute
    .= " id=\"$opened_element->{'extra'}->{'associated_node'}->{'extra'}->{'normalized'}\"";
            }
            my $language = '';
            if (defined($self->get_conf('documentlanguage'))) {
              $language = $self->get_conf('documentlanguage');
              if ($self->{'lang_stack'}->[-1] ne $language) {
                $section_attribute .= ' lang="'.$language.'"';
              }
            }
            push @{$self->{'lang_stack'}}, $language;
            $result .= "<$docbook_sectioning_element${section_attribute}>\n";
            if ($opened_element->{'args'}) {
              my ($arg, $end_line)
                = _convert_argument_and_end_line($self, $opened_element);
              $result .= "<title>$arg</title>$end_line";
              chomp ($result);
              $result .= "\n";
            }
            # if associated with a sectioning element, the part is opened
            # before the sectioning element, such that the part content
            # appears after the sectioning command opening, no need for
            # partintro.
            if ($docbook_sectioning_element eq 'part'
                and not ($opened_element->{'extra'}
                         and $opened_element->{'extra'}->{'part_associated_section'})
                and !Texinfo::Common::is_content_empty($opened_element)) {
              $result .= "<partintro>\n";
            }
          }
        }
      } elsif ($cmdname eq 'c' or $cmdname eq 'comment') {
        return $self->xml_comment($element->{'args'}->[0]->{'text'})
      } elsif ($Texinfo::Commands::sectioning_heading_commands{$cmdname}) {
        if ($element->{'args'}) {
          my ($arg, $end_line)
            = _convert_argument_and_end_line($self, $element);
          $result .=
            "<bridgehead renderas=\"$docbook_sections{$cmdname}\">"
                ."$arg</bridgehead>$end_line";
          chomp ($result);
          $result .= "\n";
          return $result;
        }
        return '';
      } elsif ($Texinfo::Commands::def_commands{$cmdname}) {
        my $def_line_result = _convert_def_line($self, $element);
        next if (!defined($def_line_result));
        $result .= $def_line_result;
      } elsif (exists ($docbook_line_elements_with_arg_map{$cmdname})) {
        my ($docbook_element, $attribute_text)
          = _parse_attribute($docbook_line_elements_with_arg_map{$cmdname});
        my ($arg, $end_line)
          = _convert_argument_and_end_line($self, $element);
        if ($docbook_element eq '') {
          $result .= "$arg$end_line";
        } else {
          $result .= "<$docbook_element${attribute_text}>"
                                  ."$arg</$docbook_element>$end_line";
        }
        chomp ($result);
        $result .= "\n";
        return $result;
      } elsif ($cmdname eq 'insertcopying') {
        if ($self->{'document'}) {
          my $global_commands
            = $self->{'document'}->global_commands_information();
          if ($global_commands and $global_commands->{'copying'}) {
            return _convert($self, {'contents'
              => $global_commands->{'copying'}->{'contents'}});
          }
        }

        return '';
      } elsif ($cmdname eq 'verbatiminclude') {
        my $verbatim_include_verbatim
          = Texinfo::Convert::Utils::expand_verbatiminclude($self, $element);
        if (defined($verbatim_include_verbatim)) {
          $result .= _convert($self, $verbatim_include_verbatim);
        } else {
          return '';
        }
      } elsif ($cmdname eq 'printindex') {
        if (defined($element->{'extra'})
            and defined($element->{'extra'}->{'misc_args'})) {
          # FIXME DocBook 5
          #return "<index type=\"$element->{'extra'}->{'misc_args'}->[0]\"></index>\n";
          return "<index role=\"$element->{'extra'}->{'misc_args'}->[0]\">"
                 ."</index>\n";
        } else {
          return "<index></index>\n";
        }
      } else {
        # ignore all the other line commands
        return '';
      }
    } elsif ($element->{'type'}
             and $element->{'type'} eq 'definfoenclose_command') {
      if ($element->{'args'}) {
        my $arg_text = _convert($self, $element->{'args'}->[0]);
        $result .= $arg_text;
      }

    } elsif ($element->{'args'}
             and exists($Texinfo::Commands::brace_commands{$cmdname})) {
      #Texinfo::Common::debug_list(" brace command with args", $element->{'args'});
      if ($style_commands_formatting{$cmdname}) {
        if ($Texinfo::Commands::brace_commands{$cmdname} eq 'context') {
          _new_document_context($self);
        }
        my $formatting = $style_commands_formatting{$cmdname};

        my $in_monospace_not_normal;
        if (defined($default_args_code_style{$cmdname})
            and $default_args_code_style{$cmdname}->[0]) {
           $in_monospace_not_normal = 1;
        } elsif ($brace_commands{$cmdname}
                 and $brace_commands{$cmdname} eq 'style_no_code') {
          $in_monospace_not_normal = 0;
        }
        if ($formatting->{'upper_case'}) {
          push @{$self->{'document_context'}->[-1]->{'upper_case'}}, 1;
        }
        if ($cmdname eq 'w') {
          push @{$self->{'document_context'}->[-1]->{'no_break'}}, 1;
        }
        push @{$self->{'document_context'}->[-1]->{'monospace'}},
          $in_monospace_not_normal
            if (defined($in_monospace_not_normal));

        my ($style, $attribute_text)
           = _parse_attribute($formatting->{'attribute'});
        my $result = _convert($self, $element->{'args'}->[0]);
        if ($style ne '' and (!$self->{'document_context'}->[-1]->{'inline'}
                               or $inline_elements{$style})) {
          $result = "<$style${attribute_text}>$result</$style>";
          if ($cmdname eq 'math') {
            $result = "<inlineequation>$result</inlineequation>";
          }
        }
        if (defined($formatting->{'quote'})) {
          $result = $self->get_conf('OPEN_QUOTE_SYMBOL') . $result
                   . $self->get_conf('CLOSE_QUOTE_SYMBOL');
        }
        if (defined($formatting->{'upper_case'})) {
          pop @{$self->{'document_context'}->[-1]->{'upper_case'}};
        }
        if ($cmdname eq 'w') {
          pop @{$self->{'document_context'}->[-1]->{'no_break'}};
        }
        pop @{$self->{'document_context'}->[-1]->{'monospace'}}
          if (defined($in_monospace_not_normal));
        if ($Texinfo::Commands::brace_commands{$cmdname} eq 'context') {
          pop @{$self->{'document_context'}};
        }
        if ($cmdname eq 'w') {
          $result .= $w_command_mark;
        }
        return $result;
      } elsif ($cmdname eq 'anchor') {
        return _output_anchor($element);
      } elsif ($Texinfo::Commands::ref_commands{$cmdname}) {
        if ($element->{'args'}) {
          my $args_nr = scalar(@{$element->{'args'}});
          my $command_name;
          my $book_element;
          my ($section_name, $node_name);
          my $manual_file_index = 3;
          if ($cmdname eq 'inforef') {
            $manual_file_index = 2;
            $command_name = 'xref';
          } elsif ($cmdname eq 'link') {
            $manual_file_index = 2;
            $command_name = 'ref';
          } else {
            if ($args_nr >= 5
                and $element->{'args'}->[4]->{'contents'}) {
              $book_element = $element->{'args'}->[4];
            }
            if ($args_nr >= 3
                and $element->{'args'}->[2]->{'contents'}) {
              my $section_arg = $element->{'args'}->[2];
              $section_name = _convert($self, $section_arg);
            }
            $command_name = $cmdname;
          }
          my $manual_file_element;
          if ($args_nr >= $manual_file_index+1
              and $element->{'args'}->[$manual_file_index]->{'contents'}) {
            $manual_file_element = $element->{'args'}->[$manual_file_index];
          }
          if (! defined($section_name) and $args_nr >= 2
              and $element->{'args'}->[1]->{'contents'}) {
            my $section_arg = $element->{'args'}->[1];
            $section_name = _convert($self, $section_arg);
          } elsif ($element->{'args'}->[0]->{'contents'}) {
            my $node_arg = $element->{'args'}->[0];
            push @{$self->{'document_context'}->[-1]->{'upper_case'}}, 0;
            $node_name = _convert($self, $node_arg);
            pop @{$self->{'document_context'}->[-1]->{'upper_case'}};

            if (($book_element or $manual_file_element)
                and $node_name eq 'Top') {
              $node_name = undef;
            }
          }

          my $result;
          push @{$self->{'document_context'}->[-1]->{'upper_case'}}, 0;
          # external book ref
          if ($book_element) {
            if ($section_name) {
              my $substituted_strings = {
                  'section_name' => {'type' => '_converted',
                                     'text' => $section_name},
                  'book' => $book_element
                };
              if ($command_name eq 'ref') {
                $result = _convert($self,
                  $self->cdt('section ``{section_name}\'\' in @cite{{book}}',
                             $substituted_strings));
              } elsif ($command_name eq 'xref') {
                $result = _convert($self,
                 $self->cdt('See section ``{section_name}\'\' in @cite{{book}}',
                             $substituted_strings));
              } elsif ($command_name eq 'pxref') {
                $result = _convert($self,
                 $self->cdt('see section ``{section_name}\'\' in @cite{{book}}',
                             $substituted_strings));
              }
            } elsif ($node_name) {
              my $substituted_strings = {
                 'node_name' => {'type' => '_converted',
                                 'text' => $node_name},
                 'book' => $book_element
                };
              if ($command_name eq 'ref') {
                $result = _convert($self,
                  $self->cdt('``{node_name}\'\' in @cite{{book}}',
                             $substituted_strings));
              } elsif ($command_name eq 'xref') {
                $result = _convert($self,
                  $self->cdt('See ``{node_name}\'\' in @cite{{book}}',
                             $substituted_strings));
              } elsif ($command_name eq 'pxref') {
                $result = _convert($self,
                  $self->cdt('see ``{node_name}\'\' in @cite{{book}}',
                             $substituted_strings));
              }
            } else {
              if ($command_name eq 'ref') {
                $result = _convert($self,
                  $self->cdt('@cite{{book}}',
                    {'book' => $book_element }));
              } elsif ($command_name eq 'xref') {
                $result = _convert($self,
                  $self->cdt('See @cite{{book}}',
                    {'book' => $book_element }));
              } elsif ($command_name eq 'pxref') {
                $result = _convert($self,
                  $self->cdt('see @cite{{book}}',
                    {'book' => $book_element }));
              }
            }
          } elsif ($manual_file_element) {
            if ($section_name) {
              my $substituted_strings = {
                'section_name' => {'type' => '_converted',
                                   'text' => $section_name},
                'manual' => $manual_file_element
               };
              if ($command_name eq 'ref') {
                $result = _convert($self,
                  $self->cdt('section ``{section_name}\'\' in @file{{manual}}',
                             $substituted_strings));
              } elsif ($command_name eq 'xref') {
                $result = _convert($self,
               $self->cdt('See section ``{section_name}\'\' in @file{{manual}}',
                             $substituted_strings));
              } elsif ($command_name eq 'pxref') {
                $result = _convert($self,
               $self->cdt('see section ``{section_name}\'\' in @file{{manual}}',
                             $substituted_strings));
              }
            } elsif ($node_name) {
              my $substituted_strings = {
                  'node_name' => {'type' => '_converted',
                                  'text' => $node_name},
                  'manual' => $manual_file_element
                };
              if ($command_name eq 'ref') {
                $result = _convert($self,
                  $self->cdt('``{node_name}\'\' in @file{{manual}}',
                             $substituted_strings));
              } elsif ($command_name eq 'xref') {
                $result = _convert($self,
                  $self->cdt('See ``{node_name}\'\' in @file{{manual}}',
                             $substituted_strings));
              } elsif ($command_name eq 'pxref') {
                $result = _convert($self,
                  $self->cdt('see ``{node_name}\'\' in @file{{manual}}',
                             $substituted_strings));
              }
            } else {
              if ($command_name eq 'ref') {
                $result = _convert($self,
                  $self->cdt('@file{{manual}}',
                    {'manual' => $manual_file_element }));
              } elsif ($command_name eq 'xref') {
                $result = _convert($self,
                  $self->cdt('See @file{{manual}}',
                    {'manual' => $manual_file_element }));
              } elsif ($command_name eq 'pxref') {
                $result = _convert($self,
                  $self->cdt('see @file{{manual}}',
                    {'manual' => $manual_file_element }));
              }
            }
          } elsif ($cmdname eq 'inforef') {
            $result = '';
          } else {
            my $linkend = '';
            my $node_arg = $element->{'args'}->[0];
            if ($node_arg and $node_arg->{'extra'}
                and defined($node_arg->{'extra'}->{'normalized'})
                and !$node_arg->{'extra'}->{'manual_content'}) {
              $linkend = " linkend=\"$node_arg->{'extra'}->{'normalized'}\"";
            }
            my $link_text = $section_name;
            $link_text = $node_name if (! defined($link_text));
            my $argument = "<link${linkend}>".$link_text."</link>";
            if ($cmdname eq 'ref'
                or $cmdname eq 'link') {
              $result = _convert($self,
                      $self->cdt('{title_ref}', {'title_ref' =>
                           {'type' => '_converted',
                            'text' => $argument}}));
            } elsif ($cmdname eq 'xref') {
              $result = _convert($self,
                      $self->cdt('See {title_ref}', {'title_ref' =>
                           {'type' => '_converted',
                            'text' => $argument}}));
            } elsif ($cmdname eq 'pxref') {
              $result = _convert($self,
                      $self->cdt('see {title_ref}', {'title_ref' =>
                           {'type' => '_converted',
                            'text' => $argument}}));
            }
          }
          pop @{$self->{'document_context'}->[-1]->{'upper_case'}};
          return $result;
        } else {
          return '';
        }
      } elsif ($cmdname eq 'image') {
        if ($element->{'args'}
            and $element->{'args'}->[0]->{'contents'}) {
          Texinfo::Convert::Text::set_options_code(
                                 $self->{'convert_text_options'});
          Texinfo::Convert::Text::set_options_encoding_if_not_ascii($self,
                                  $self->{'convert_text_options'});
          my $basefile = Texinfo::Convert::Text::convert_to_text(
                                        $element->{'args'}->[0],
                                    $self->{'convert_text_options'});
          Texinfo::Convert::Text::reset_options_code(
                                 $self->{'convert_text_options'});
          Texinfo::Convert::Text::reset_options_encoding(
                                 $self->{'convert_text_options'});

          my $is_inline = Texinfo::Common::element_is_inline($element);
          if ($is_inline) {
            $result .= "<inlinemediaobject>";
          } else {
            $result .= "<informalfigure><mediaobject>";
          }
          my @files;
          foreach my $extension (@docbook_image_extensions) {
            my ($file_name, $file_name_encoding)
               = $self->encoded_input_file_name("$basefile.$extension");
            if (Texinfo::Common::locate_include_file($file_name,
                                  $self->get_conf('INCLUDE_DIRECTORIES'))) {
              push @files, ["$basefile.$extension", uc($extension)];
            }
          }
          my $image_file_found = scalar(@files);;
          if (!$image_file_found) {
            push @files, ["$basefile.jpg", 'JPG'];
          }
          foreach my $file (@files) {
            $result .= "<imageobject><imagedata fileref=\""
               .$self->xml_protect_text($file->[0])
               ."\" format=\"$file->[1]\"></imagedata></imageobject>";
          }
          my ($image_text, $image_width)
                = $self->txt_image_text($element, $basefile);
          if (defined($image_text)) {
            # remove last end of line
            chomp($image_text);
            $result .= "<textobject><literallayout>"
               ._protect_text($self, $image_text)
               .'</literallayout></textobject>';
          }
          if (!defined($image_text) and !$image_file_found) {
            $self->converter_line_warn(sprintf(
                     __("\@image file `%s' not found, using `%s'"),
                       $basefile, "$basefile.jpg"), $element->{'source_info'});
          }

          if ($is_inline) {
            $result .= "</inlinemediaobject>";
          } else {
            $result .= "</mediaobject></informalfigure>";
          }
        }
      } elsif ($cmdname eq 'email') {
        if ($element->{'args'}) {
          my $name;
          my $email;
          my $email_text;
          if (scalar(@{$element->{'args'}}) >= 2
              and $element->{'args'}->[1]->{'contents'}) {
            $name = $element->{'args'}->[1];
          }
          if ($element->{'args'}->[0]->{'contents'}) {
            $email = $element->{'args'}->[0];
            Texinfo::Convert::Text::set_options_code(
                                 $self->{'convert_text_options'});
            Texinfo::Convert::Text::set_options_encoding_if_not_ascii($self,
                                  $self->{'convert_text_options'});
            $email_text
              = _protect_text($self, Texinfo::Convert::Text::convert_to_text(
                            $email, $self->{'convert_text_options'}));
            Texinfo::Convert::Text::reset_options_code(
                                 $self->{'convert_text_options'});
            Texinfo::Convert::Text::reset_options_encoding(
                                 $self->{'convert_text_options'});
          }
          if ($name and $email) {
            # FIXME DocBook 5 ulink -> link
            # There is no possibility to do something similar in DocBook 5.
            # The best is probably either to forget about the name, or
            # follow <email> by the name in parentheses
            return "<ulink url=\"mailto:$email_text\">"
              ._convert($self, $name).'</ulink>';
          } elsif ($email) {
            return "<email>$email_text</email>";
          } elsif ($name) {
            return _convert($self, $name);
          }
        } else {
          return '';
        }

      } elsif ($cmdname eq 'uref' or $cmdname eq 'url') {
        if ($element->{'args'}) {
          my $args_nr = scalar(@{$element->{'args'}});
          my ($url_text, $url_arg);
          if ($element->{'args'}->[0]->{'contents'}) {
            $url_arg = $element->{'args'}->[0];
            Texinfo::Convert::Text::set_options_code(
                                 $self->{'convert_text_options'});
            Texinfo::Convert::Text::set_options_encoding_if_not_ascii($self,
                                  $self->{'convert_text_options'});
            $url_text = _protect_text($self, 
              Texinfo::Convert::Text::convert_to_text($url_arg,
                                       $self->{'convert_text_options'}));
            Texinfo::Convert::Text::reset_options_code(
                                 $self->{'convert_text_options'});
            Texinfo::Convert::Text::reset_options_encoding(
                                 $self->{'convert_text_options'});
          } else {
            $url_text = '';
          }
          my $replacement;
          if ($args_nr >= 2
              and $element->{'args'}->[1]->{'contents'}) {
            $replacement = _convert($self, $element->{'args'}->[1]);
          }
          if (!defined($replacement) or $replacement eq '') {
            if ($args_nr >= 3
                and $element->{'args'}->[2]->{'contents'}) {
              $replacement = _convert($self, $element->{'args'}->[2]);
            }
          }
          if (!defined($replacement) or $replacement eq '') {
            $replacement = $url_text;
          }
          return "<ulink url=\"$url_text\">$replacement</ulink>";
          # FIXME DocBook 5
          # need to add in the preamble
          #    xmlns:xlink="http://www.w3.org/1999/xlink"
          # return "<link xlink:href=\"$url_text\">$replacement</link>";
        }

      } elsif ($cmdname eq 'abbr' or $cmdname eq 'acronym') {
        if ($element->{'args'}) {
          my $argument;
          if ($element->{'args'}->[0]->{'contents'}) {
            my $arg_text = _convert($self, $element->{'args'}->[0]);
            if ($arg_text ne '') {
              my $format_element;
              if ($cmdname eq 'abbr') {
                $format_element = 'abbrev';
              } else {
                $format_element = $cmdname;
              }
              $argument = "<$format_element>$arg_text</$format_element>";
            }
          }
          if (scalar(@{$element->{'args'}}) >= 2
              and $element->{'args'}->[1]->{'contents'}) {
            if (defined($argument)) {
              my $tree = $self->cdt('{abbr_or_acronym} ({explanation})',
                             {'abbr_or_acronym' => {'type' => '_converted',
                                                    'text' => $argument},
                              'explanation' =>
                                  $element->{'args'}->[1]});
              return _convert($self, $tree);
            } else {
              return _convert($self, $element->{'args'}->[1]);
            }
          } elsif (defined($argument)) {
            return $argument;
          }
        }
        return '';

      } elsif ($cmdname eq 'U') {
        if ($element->{'args'}
            and $element->{'args'}->[0]->{'contents'}
            and $element->{'args'}->[0]->{'contents'}->[0]->{'text'}) {
          my $arg_text = $element->{'args'}->[0]->{'contents'}->[0]->{'text'};

          if (defined($arg_text)) {
            my $result = "&#x$arg_text;";
            return $result;
          }
        }
        return '';
      } elsif ($Texinfo::Commands::brace_commands{$cmdname} eq 'inline') {
        my $expand = 0;
        if ($Texinfo::Commands::inline_format_commands{$cmdname}) {
          if ($cmdname eq 'inlinefmtifelse'
              or ($element->{'extra'} and $element->{'extra'}->{'format'}
                  and $self->{'expanded_formats'}->{$element->{'extra'}->{'format'}})) {
            $expand = 1;
          }
        } elsif (defined($element->{'extra'}->{'expand_index'})) {
          $expand = 1;
        }
        return '' if (! $expand);
        my $arg_index = 1;
        if ($cmdname eq 'inlineraw') {
          _new_document_context($self);
          $self->{'document_context'}->[-1]->{'raw'} = 1;
        } elsif ($cmdname eq 'inlinefmtifelse'
                 and ! $self->{'expanded_formats'}->{$element->{'extra'}->{'format'}}) {
          $arg_index = 2;
        }
        if (scalar(@{$element->{'args'}}) > $arg_index
            and $element->{'args'}->[$arg_index]->{'contents'}) {
          $result .= _convert($self, $element->{'args'}->[$arg_index]);
        }
        if ($cmdname eq 'inlineraw') {
          pop @{$self->{'document_context'}};
        }
        #warn "  returning braced cmd result $result\n";
        return $result;
      } else {
        # ignored brace command
        #warn "  returning empty string for ignored braced cmd\n";
        return '';
      }

    # special case to ensure that @w leads to something even if empty
    } elsif ($cmdname eq 'w') {
      return $w_command_mark;

    } elsif (exists($Texinfo::Commands::block_commands{$cmdname})) {
      if ($ignored_block_commands{$cmdname}) {
        return '';
      }
      if ($self->{'context_block_commands'}->{$cmdname}) {
        _new_document_context($self);
      }
      my @attributes;
      my $appended = '';
      my @format_elements;
      if (exists($docbook_preformatted_formats{$cmdname})) {
        push @{$self->{'document_context'}->[-1]->{'preformatted_stack'}},
           $docbook_preformatted_formats{$cmdname};
      } elsif ($cmdname eq 'enumerate') {
        push @format_elements, 'orderedlist';
        my $numeration;
        if ($element->{'extra'}
            and $element->{'extra'}->{'enumerate_specification'}) {
          if ($element->{'extra'}->{'enumerate_specification'} =~ /^[A-Z]/) {
            $numeration = 'upperalpha';
          } elsif ($element->{'extra'}->{'enumerate_specification'} =~ /^[a-z]/) {
            $numeration = 'loweralpha';
          } else {
            $numeration = 'arabic';
          }
        } else {
          $numeration = 'arabic';
        }
        push @attributes, " numeration=\"$numeration\"";
      } elsif ($Texinfo::Commands::block_commands{$cmdname} eq 'item_line') {
        push @format_elements, 'variablelist';
      } elsif ($cmdname eq 'itemize') {
        push @format_elements, 'itemizedlist';
        #push @attributes, " mark=\"\"";
      } elsif ($cmdname eq 'multitable') {
        push @format_elements, "informaltable";
        push @attributes, '';
        my $columns_count;
        if ($element->{'extra'} and defined($element->{'extra'}->{'max_columns'})) {
          $columns_count = $element->{'extra'}->{'max_columns'};
        } else {
          $columns_count = 0;
        }
        push @format_elements, 'tgroup';
        push @attributes, " cols=\"$columns_count\"";
        if ($element->{'extra'}) {
          my @fractions;
          my $multiply;
          if ($element->{'extra'}->{'columnfractions'}) {
            @fractions = @{$element->{'extra'}->{'columnfractions'}->{'extra'}->{'misc_args'}};
            $multiply = 100;
          } elsif ($element->{'args'}
                   and $element->{'args'}->[0]->{'contents'}) {
            $multiply = 1;
            foreach my $content (@{$element->{'args'}->[0]->{'contents'}}) {
              if ($content->{'type'} and $content->{'type'} eq 'bracketed_arg') {
                my $prototype_text = '';
                if ($content->{'contents'}) {
                  Texinfo::Convert::Text::set_options_encoding_if_not_ascii(
                                  $self, $self->{'convert_text_options'});
                  $prototype_text
                    = Texinfo::Convert::Text::convert_to_text(
                                     $content,
                                     $self->{'convert_text_options'});
                  Texinfo::Convert::Text::reset_options_encoding(
                                     $self->{'convert_text_options'});
                }
                push @fractions,
                  Texinfo::Convert::Unicode::string_width($prototype_text);
              }
            }
          }
          foreach my $fraction (@fractions) {
            $appended .= '<colspec colwidth="'.($fraction*$multiply)
                         .'*"></colspec>';
          }
        }
      } elsif ($cmdname eq 'float') {
        my $anchor = _output_anchor($element);
        $result .= $anchor . "\n" if ($anchor ne '');
      } elsif ($cmdname eq 'verbatim') {
        push @format_elements, 'screen';
      } elsif ($cmdname eq 'displaymath') {
        push @format_elements, 'informalequation';
        push @format_elements, 'mathphrase';
      } elsif ($cmdname eq 'quotation' or $cmdname eq 'smallquotation') {
        my $format_element;
        if ($element->{'extra'}) {
          if ($element->{'extra'}->{'authors'}) {
            foreach my $author (@{$element->{'extra'}->{'authors'}}) {
              if ($author->{'args'} and $author->{'args'}->[0]->{'contents'}) {
                $appended .= '<attribution>'.
                       _convert($self, $author->{'args'}->[0])
                           ."</attribution>\n";
              }
            }
          }
        }
        if ($element->{'args'}
            and $element->{'args'}->[0]->{'contents'}) {
          my $quotation_arg_text
            = Texinfo::Convert::Text::convert_to_text(
                          $element->{'args'}->[0],
                            $self->{'convert_text_options'});
          if ($docbook_special_quotations{lc($quotation_arg_text)}) {
            $format_element = lc($quotation_arg_text);
          } else {
            $self->{'pending_prepend'}
              = _convert($self, $self->cdt('@b{{quotation_arg}:} ',
                            {'quotation_arg' =>
                                  $element->{'args'}->[0]}));
          }
        }
        $format_element = 'blockquote' if (!defined($format_element));
        push @format_elements, $format_element;
      } elsif ($cmdname eq 'cartouche') {
        push @format_elements, 'sidebar';
        if ($element->{'args'}
            and $element->{'args'}->[0]->{'contents'}) {
          my $title = _convert($self, $element->{'args'}->[0]);
          if ($title ne '') {
            $appended .= '<title>'.$title.'</title>'."\n";
          }
        }
      } elsif ($Texinfo::Commands::block_commands{$cmdname} eq 'format_raw') {
        return '' if (!$self->{'expanded_formats'}->{$cmdname});
        # the context is here only for the command, so this is forgotten
        # once all the raw internal text has been formatted
        $self->{'document_context'}->[-1]->{'raw'} = 1;
      } elsif ($Texinfo::Commands::block_commands{$cmdname} eq 'raw'
               or $Texinfo::Commands::block_commands{$cmdname} eq 'menu') {
        return '';
      }
      foreach my $format_element (@format_elements) {
        my $attribute = shift @attributes;
        $attribute = '' if (!defined($attribute));
        $result .= "<$format_element${attribute}>";
        unshift @close_format_elements, $format_element;
      }
      $result .= $appended if (defined($appended));
    }
  }
  #warn " end of cmdname\n";


  if ($element->{'type'}) {

    if ($container_ignored_if_empty{$element->{'type'}}
        and !$element->{'contents'}) {
      return $result;
    }

    #warn " have type $element->{'type'}\n";
    if (exists($docbook_preformatted_formats{$element->{'type'}})) {
      push @{$self->{'document_context'}->[-1]->{'preformatted_stack'}},
         $docbook_preformatted_formats{$element->{'type'}};
    }
    if (defined($type_elements{$element->{'type'}})) {
      $result .= "<$type_elements{$element->{'type'}}>";
    } elsif ($element->{'type'} eq 'preformatted') {
      $result .= "<$self->{'document_context'}->[-1]->{'preformatted_stack'}->[-1]>";
      $self->{'document_context'}->[-1]->{'in_preformatted'} = 1;
    } elsif ($element->{'type'} eq 'def_line') {
      my $def_line_result = _convert_def_line($self, $element);
      next if (!defined($def_line_result));
      $result .= $def_line_result;
    } elsif ($element->{'type'} eq 'table_term') {
      # should be closed by the @item.  Allows to have the index entries in
      # term, which is better than out.
      $result .= "<term>";
    }
  }

  if ($element->{'contents'}) {
    #warn " have contents $element->{'contents'}\n";
    my $in_code;
    if ($cmdname
        and ($Texinfo::Commands::preformatted_code_commands{$cmdname}
             or $Texinfo::Commands::math_commands{$cmdname})) {
      $in_code = 1;
    }
    push @{$self->{'document_context'}->[-1]->{'monospace'}}, 1
      if ($in_code);
    if (ref($element->{'contents'}) ne 'ARRAY') {
      cluck "contents not an array($element->{'contents'}).";
    }
    if (defined($self->{'pending_prepend'})
        # not restricted enough, includes line_args, for instance
        #and Texinfo::Common::element_is_inline($element, 1)) {
        and $element->{'type'}
        and ($element->{'type'} eq 'paragraph'
             or $element->{'type'} eq 'preformatted')) {
      $result .= $self->{'pending_prepend'};
      delete $self->{'pending_prepend'};
    }
    #my $nr = -1;
    foreach my $content (@{$element->{'contents'}}) {
      #$nr++;
      #print STDERR "C$debug_element_nr[$nr] "
      #   .Texinfo::Common::debug_print_element($content)."\n";
      $result .= _convert($self, $content);
    }
    pop @{$self->{'document_context'}->[-1]->{'monospace'}}
      if ($in_code);
  }

  if ($element->{'type'}) {
    if (defined($type_elements{$element->{'type'}})) {
      $result .= "</$type_elements{$element->{'type'}}>";
    } elsif ($element->{'type'} eq 'preformatted') {
      $result .= "</$self->{'document_context'}->[-1]->{'preformatted_stack'}->[-1]>";
      delete $self->{'document_context'}->[-1]->{'in_preformatted'};
    }
  }

  foreach my $format_element (@close_format_elements) {
    $result .= "</$format_element>";
  }

  if ($cmdname
      and exists($Texinfo::Commands::block_commands{$cmdname})) {
    # a pending_prepend still there may happen if a quotation is empty.
    delete $self->{'pending_prepend'};
    if (!$self->{'document_context'}->[-1]->{'raw'}
        and exists($docbook_preformatted_formats{$cmdname})) {
      my $format = pop @{$self->{'document_context'}->[-1]->{'preformatted_stack'}};
      die "BUG $format ne $docbook_preformatted_formats{$cmdname}"
        if ($format ne $docbook_preformatted_formats{$cmdname});
    }
    if ($self->{'context_block_commands'}->{$cmdname}) {
      pop @{$self->{'document_context'}};
    }

  } elsif ($element->{'type'}
           and exists($docbook_preformatted_formats{$element->{'type'}})) {
    my $format = pop @{$self->{'document_context'}->[-1]->{'preformatted_stack'}};
    die "BUG $format ne $docbook_preformatted_formats{$element->{'type'}}"
      if ($format ne $docbook_preformatted_formats{$element->{'type'}});
  # close sectioning command
  } elsif ($cmdname and $cmdname ne 'node'
           and $Texinfo::Commands::root_commands{$cmdname}) {
    my $docbook_sectioning_element = _docbook_section_element($self, $element);
    if ($docbook_sectioning_element eq 'part'
        and not ($element->{'extra'}
                 and $element->{'extra'}->{'part_associated_section'})
        and !Texinfo::Common::is_content_empty($element)) {
      $result .= "</partintro>\n";
    }
    my $level_adjusted_cmdname
        = Texinfo::Structuring::section_level_adjusted_command_name($element);
    if (!($element->{'extra'}
          and $element->{'extra'}->{'section_childs'}
          and scalar(@{$element->{'extra'}->{'section_childs'}}))
        or $level_adjusted_cmdname eq 'top') {
      $result .= "</$docbook_sectioning_element>\n";
      pop @{$self->{'lang_stack'}};
      my $current = $element;
      while ($current->{'extra'}
             and $current->{'extra'}->{'section_directions'}
             and $current->{'extra'}->{'section_directions'}->{'up'}
             # the most up element is a virtual sectioning root element, this
             # condition avoids getting into it
             and $current->{'extra'}->{'section_directions'}->{'up'}->{'cmdname'}
             and !$current->{'extra'}->{'section_directions'}->{'next'}
             and Texinfo::Structuring::section_level_adjusted_command_name(
               $current->{'extra'}->{'section_directions'}->{'up'}) ne 'top') {
        $current = $current->{'extra'}->{'section_directions'}->{'up'};
        $result .= '</'._docbook_section_element($self, $current) .">\n";
        pop @{$self->{'lang_stack'}};
      }
    }
  } elsif ($element->{'type'} and $element->{'type'} eq 'before_node_section') {
    # ignore text before the first @node or sectioning command
    # as DocBook does not allow content not within some semantic
    # markup
    return '';
  }

  if ($cmdname
      and $Texinfo::Commands::root_commands{$cmdname}
      and defined($self->{'in_skipped_node_top'})
      and $self->{'in_skipped_node_top'} == 1) {
    return '';
  }

  #warn " returning $result\n";
  return $result;
}

# figure: mandatory title->use it with shortcaption?. Has a caption.

1;

__END__
# Automatically generated from maintain/template.pod

=head1 NAME

Texinfo::Convert::DocBook - Convert Texinfo tree to DocBook

=head1 SYNOPSIS

  my $converter
    = Texinfo::Convert::DocBook->converter({'NUMBER_SECTIONS' => 0});

  $converter->output($document);
  $converter->convert($document);
  $converter->convert_tree($tree);

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

Texinfo::Convert::DocBook converts a Texinfo tree to DocBook.

=head1 METHODS

=over

=item $converter = Texinfo::Convert::DocBook->converter($options)

Initialize converter from Texinfo to DocBook.

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
