# Copyright 2023-2024 Free Software Foundation, Inc.
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

# This package provides a view of a parsed Texinfo document.  The
# instantiated objects are also used to carry information for the
# XS modules, mainly to be able to find the document information
# in memory.

package Texinfo::Document;

use strict;
use warnings;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Carp qw(cluck);

use Texinfo::DocumentXS;

use Texinfo::XSLoader;

use Texinfo::Common;
use Texinfo::Report;
use Texinfo::Indices;

our $VERSION = '7.2';

# Full XS coverage.  See comments before methods definitions for an
# explanation of why some methods have no XS override.

my $XS_parser = Texinfo::XSLoader::XS_parser_enabled();

our %XS_overrides = (
  "Texinfo::Document::remove_document"
    => "Texinfo::DocumentXS::remove_document",
  "Texinfo::Document::_XS_set_document_global_info",
    => "Texinfo::DocumentXS::set_document_global_info",
  "Texinfo::Document::errors"
    => "Texinfo::DocumentXS::document_errors",
  "Texinfo::Document::parser_errors"
    => "Texinfo::DocumentXS::document_parser_errors",
  "Texinfo::Document::rebuild_tree"
    => "Texinfo::DocumentXS::rebuild_tree",
  "Texinfo::Document::tree"
    => "Texinfo::DocumentXS::document_tree",
  "Texinfo::Document::register_document_options"
    => "Texinfo::DocumentXS::register_document_options",
  "Texinfo::Document::get_conf",
    => "Texinfo::DocumentXS::document_get_conf",
  "Texinfo::Document::global_information"
    => "Texinfo::DocumentXS::document_global_information",
  "Texinfo::Document::indices_information"
    => "Texinfo::DocumentXS::document_indices_information",
  "Texinfo::Document::global_commands_information"
    => "Texinfo::DocumentXS::document_global_commands_information",
  "Texinfo::Document::labels_information"
    => "Texinfo::DocumentXS::document_labels_information",
  "Texinfo::Document::labels_list"
    => "Texinfo::DocumentXS::document_labels_list",
  "Texinfo::Document::nodes_list"
    => "Texinfo::DocumentXS::document_nodes_list",
  "Texinfo::Document::sections_list"
    => "Texinfo::DocumentXS::document_sections_list",
  "Texinfo::Document::floats_information"
    => "Texinfo::DocumentXS::document_floats_information",
  "Texinfo::Document::internal_references_information"
    => "Texinfo::DocumentXS::document_internal_references_information",

  "Texinfo::Document::setup_indices_sort_strings"
    => "Texinfo::DocumentXS::setup_indices_sort_strings",
  "Texinfo::Document::indices_sort_strings"
    => "Texinfo::DocumentXS::indices_sort_strings",
);

our $module_loaded = 0;
sub import {
  if (!$module_loaded) {
    if ($XS_parser) {
      for my $sub (keys %XS_overrides) {
        Texinfo::XSLoader::override ($sub, $XS_overrides{$sub});
      }
    }
    $module_loaded = 1;
  }
  # The usual import method
  goto &Exporter::import;
}

sub new_document($)
{
  my $indices_information = shift;
  my $document = {
    'indices' => $indices_information,
    'listoffloats_list' => {},
    'internal_references' => [],
    'global_info' => {'input_encoding_name' => 'utf-8',
                    #'included_files' => [],
                    },
    'commands_info' => {},
    'identifiers_target' => {},
    'labels_list' => [],
     # error registrar for parsing
    'parser_registrar' => Texinfo::Report::new(),
     # error registrar for the document for structuring, not for parsing
    'registrar' => Texinfo::Report::new(),
  };

  bless $document;
  return $document;
}

sub register_tree($$)
{
  my $document = shift;
  my $tree = shift;
  $document->{'tree'} = $tree;
}

sub register_document_nodes_list($$)
{
  my $document = shift;
  my $nodes_list = shift;
  $document->{'nodes_list'} = $nodes_list;
}

sub register_document_sections_list($$)
{
  my $document = shift;
  my $sections_list = shift;
  $document->{'sections_list'} = $sections_list;
}

sub _XS_set_document_global_info($$$)
{
}

sub set_document_global_info($$$)
{
  my $document = shift;
  my $key = shift;
  my $value = shift;
  if ($XS_parser) {
    _XS_set_document_global_info($document, $key, $value);
  }
  $document->{'global_info'}->{$key} = $value;
}

sub tree($;$)
{
  my $self = shift;
  return $self->{'tree'};
}

# return indices information
sub indices_information($)
{
  my $self = shift;
  return $self->{'indices'};
}

sub floats_information($)
{
  my $self = shift;
  return $self->{'listoffloats_list'};
}

sub internal_references_information($)
{
  my $self = shift;
  return $self->{'internal_references'};
}

sub global_commands_information($)
{
  my $self = shift;
  return $self->{'commands_info'};
}

sub global_information($)
{
  my $self = shift;
  return $self->{'global_info'};
}

sub labels_information($)
{
  my $self = shift;
  return $self->{'identifiers_target'};
}

sub labels_list($)
{
  my $self = shift;
  return $self->{'labels_list'};
}

sub nodes_list($)
{
  my $self = shift;
  return $self->{'nodes_list'};
}

sub sections_list($)
{
  my $self = shift;
  return $self->{'sections_list'};
}

sub registrar($)
{
  my $self = shift;
  return $self->{'registrar'};
}

# Useful for options used in structuring/tree transformations.
sub register_document_options($$)
{
  my $self = shift;
  my $options = shift;

  $self->{'options'} = $options;
}

sub get_conf($$)
{
  my $self = shift;
  my $var = shift;

  if (!$self->{'options'}) {
    # This may happen if a tree/document is manipulated without having
    # any configuration set.  This is or was the case for pod2texi.
    # TODO it is not clear yet whether allowing document options not to be set
    # at all is right or wrong:
    # In favor
    #  * it would be a good thing if the output was correct with undef set
    #    for each of the structuring options.
    #  * not having to worry about setting customization information
    #    at all allows writing simpler code.
    # Against
    #  * it guards against having forgotten to setup customization
    #    variables
    #  * it forces writers of code using a document object to think about
    #    which customization should be set or not
    #  * it is very easy to setup options as an empty hash, which removes
    #    the warning but has not other effect, once one is confident that
    #    the result obtained with all the customization variables unset is ok
    #print STDERR "DEBUG: $var: Document get_conf uninitialized options\n";
    #cluck();
    return undef;
  }
  return $self->{'options'}->{$var};
}

# No XS override, as there is no reason to call this function directly,
# since it is already called by other methods, in particular
# sorted_indices_by_*.
sub merged_indices($)
{
  my $self = shift;

  if ($self->{'indices'}) {
    if (!$self->{'merged_indices'}) {
      $self->{'merged_indices'}
        = Texinfo::Indices::merge_indices($self->{'indices'});
    }
  }
  return $self->{'merged_indices'};
}

# calls Texinfo::Indices::setup_index_entries_sort_strings and caches the
# result.
# In general, it is not needed to call that function directly,
# as it is called by Texinfo::Indices::sort_indices_by_*.  It could
# be called in advance if errors need to be collected early.
sub setup_indices_sort_strings($$)
{
  my $document = shift;
  my $customization_information = shift;

  if (!$document->{'index_entries_sort_strings'}) {
    my $indices_sort_strings
      = Texinfo::Indices::setup_index_entries_sort_strings
             ($document->{'registrar'}, $customization_information,
              $document->merged_indices(),
              $document->indices_information(), 0);
    $document->{'index_entries_sort_strings'} = $indices_sort_strings;
  }
}

# index_entries_sort_strings accessor.  A different function from
# setup_indices_sort_strings such that it is possible to build Perl data
# only for this function in XS.
sub indices_sort_strings($$)
{
  my $document = shift;
  my $customization_information = shift;

  setup_indices_sort_strings($document, $customization_information);
  return $document->{'index_entries_sort_strings'};
}

# calls Texinfo::Indices::sort_indices_by_letter and caches the result.
# No XS override, as there is no reason to call this function directly,
# Texinfo::Convert::Converter get_converter_indices_sorted_by_letter
# should be called directly.
sub sorted_indices_by_letter($$$$)
{
  my $document = shift;
  my $customization_information = shift;
  my $use_unicode_collation = shift;
  my $locale_lang = shift;

  my $lang_key;
  if (!$use_unicode_collation) {
    $lang_key = '';
  } elsif (!defined($locale_lang)) {
    # special name corresponding to Unicode Collation with 'Non-Ignorable'
    # set for variable collation elements
    $lang_key = '-';
  } else {
    $lang_key = $locale_lang;
  }

  $document->{'sorted_indices_by_letter'} = {}
    if (!$document->{'sorted_indices_by_letter'});

  if (!$document->{'sorted_indices_by_letter'}->{$lang_key}) {
    $document->merged_indices();
    $document->{'sorted_indices_by_letter'}->{$lang_key}
      = Texinfo::Indices::sort_indices_by_letter
          ($document, $document->{'registrar'}, $customization_information,
           $use_unicode_collation, $locale_lang);
  }
  return $document->{'sorted_indices_by_letter'}->{$lang_key};
}

# calls Texinfo::Indices::sort_indices_by_index and caches the result.
# No XS override, as there is no reason to call this function directly,
# Texinfo::Convert::Converter get_converter_indices_sorted_by_index
# should be called directly.
sub sorted_indices_by_index($$$$)
{
  my $document = shift;
  my $customization_information = shift;
  my $use_unicode_collation = shift;
  my $locale_lang = shift;

  my $lang_key;
  if (!$use_unicode_collation) {
    $lang_key = '';
  } elsif (!defined($locale_lang)) {
    # special name corresponding to Unicode Collation with 'Non-Ignorable'
    # set for variable collation elements
    $lang_key = '-';
  } else {
    $lang_key = $locale_lang;
  }

  $document->{'sorted_indices_by_index'} = {}
    if (!$document->{'sorted_indices_by_index'});

  if (!$document->{'sorted_indices_by_index'}->{$lang_key}) {
    $document->merged_indices();
    $document->{'sorted_indices_by_index'}->{$lang_key}
      = Texinfo::Indices::sort_indices_by_index
          ($document, $document->{'registrar'}, $customization_information,
           $use_unicode_collation, $locale_lang);
  }
  return $document->{'sorted_indices_by_index'}->{$lang_key};
}

# only set if the Texinfo::Document object has been set up by XS code.
sub document_descriptor($)
{
  my $self = shift;
  return $self->{'document_descriptor'};
}

sub _existing_label_error($$;$$)
{
  my $self = shift;
  my $element = shift;
  my $registrar = shift;
  my $debug = shift;

  if ($element->{'extra'}
      and defined($element->{'extra'}->{'normalized'})) {
    my $normalized = $element->{'extra'}->{'normalized'};
    if (defined($registrar)) {
      my $existing_target = $self->{'identifiers_target'}->{$normalized};
      my $label_element = Texinfo::Common::get_label_element($element);
      $registrar->line_error(sprintf(__("\@%s `%s' previously defined"),
                                     $element->{'cmdname'},
                    Texinfo::Convert::Texinfo::convert_to_texinfo(
                         {'contents' => $label_element->{'contents'}})),
                              $element->{'source_info'}, 0, $debug);
      $registrar->line_error(
                    sprintf(__("here is the previous definition as \@%s"),
                            $existing_target->{'cmdname'}),
                             $existing_target->{'source_info'}, 1, $debug);
    }
  }
}

sub _add_element_to_identifiers_target($$)
{
  my $self = shift;
  my $element = shift;

  if ($element->{'extra'}
      and defined($element->{'extra'}->{'normalized'})) {
    my $normalized = $element->{'extra'}->{'normalized'};
    if (!defined $self->{'identifiers_target'}->{$normalized}) {
      $self->{'identifiers_target'}->{$normalized} = $element;
      $element->{'extra'}->{'is_target'} = 1;
      return 1;
    }
  }
  return 0;
}

# Called from Texinfo::ParserNonXS.
# This should be considered an internal function of the parser.
# It is here to reuse code.
# Sets $self->{'identifiers_target'} based on $self->{'labels_list'}.
sub set_labels_identifiers_target($$;$)
{
  my $self = shift;
  my $registrar = shift;
  my $debug = shift;

  my @elements_with_error;

  $self->{'identifiers_target'} = {};
  if (defined $self->{'labels_list'}) {
    foreach my $element (@{$self->{'labels_list'}}) {
      my $retval = _add_element_to_identifiers_target($self, $element);
      if (!$retval and $element->{'extra'}
          and defined($element->{'extra'}->{'normalized'})) {
        push @elements_with_error, $element;
      }
    }
  }
  # use identifiers order to have the same error messages order as in XS parser
  if (scalar(@elements_with_error) > 0) {
    my @sorted
     = sort {$a->{'extra'}->{'normalized'} cmp $b->{'extra'}->{'normalized'}}
        @elements_with_error;
    foreach my $element (@sorted) {
      _existing_label_error($self, $element, $self->{'registrar'}, $debug);
    }
  }
}

# TODO document when stabilized
sub register_label_element($$;$$)
{
  my $self = shift;
  my $element = shift;
  my $registrar = shift;
  my $debug = shift;

  my $retval = _add_element_to_identifiers_target($self, $element);
  if (!$retval) {
    _existing_label_error($self, $element, $registrar, $debug);
  }
  # TODO do not push at the end but have the caller give an information
  # on the element it should be after or before in the list?
  push @{$self->{'labels_list'}}, $element;
  return $retval;
}

# do nothing, only the XS override does something.
sub remove_document($)
{
  my $document = shift;
}

# this method does nothing, but the XS override rebuilds the Perl
# tree based on XS data.
sub rebuild_tree($;$)
{
  my $tree = shift;
  my $no_store = shift;

  return $tree;
}

sub parser_errors($)
{
  my $document = shift;

  my $registrar = $document->{'parser_registrar'};

  my ($error_warnings_list, $error_count) = $registrar->errors();

  $registrar->clear();

  return ($error_warnings_list, $error_count);
}

# The XS override pass C error messages to the document registrar and destroys
# C associated data.
sub errors($)
{
  my $document = shift;

  my $registrar = $document->{'registrar'};

  my ($error_warnings_list, $error_count) = $registrar->errors();

  $registrar->clear();

  return ($error_warnings_list, $error_count);
}

1;
__END__
=head1 NAME

Texinfo::Document - Texinfo document tree and information

=head1 SYNOPSIS

  use Texinfo::Parser;

  my $parser = Texinfo::Parser::parser();
  my $document = $parser->parse_texi_file("somefile.texi");

  my $indices_information = $document->indices_information();
  my $float_types_arrays = $document->floats_information();
  my $internal_references_array
    = $parser->internal_references_information();

  # $identifier_target is an hash reference on normalized
  # node/float/anchor names.
  my $identifier_target = $document->labels_information();

  # A hash reference, keys are @-command names, value is an
  # array reference holding all the corresponding @-commands.
  # Also contains dircategory and direntry list.
  my $global_commands_information
                 = $document->global_commands_information();

  # a hash reference on document information (encodings,
  # input file name, for example).
  my $global_information = $document->global_information();

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

This module is used to represent parsed Texinfo documents, with the Texinfo
tree and associated information.  In general a document is obtained from
a Texinfo parser call, there is no need to setup the document.

=head1 METHODS

=head2 Getting document information

The main purpose of Texinfo::Document methods is to retrieve information
on a Texinfo document.

The Texinfo tree obtained by parsing a Texinfo document is available through
C<tree>:

=over

=item $tree = tree($document, $handler_only)
X<C<tree>>

The I<$tree> is a hash reference.  It is described in
L<Texinfo::Parser/TEXINFO TREE>.

If I<$handler_only> is set and XS extensions are used, the returned
tree holds a reference to the C Texinfo tree data only, but no actual
Perl Texinfo tree.  This avoids building the Perl tree if all the
functions called with the tree as argument have XS interfaces and
directly use the C data and do not use the Perl tree.

=back

Some global information is available through C<global_information>:

=over

=item $info = global_information($document)
X<C<global_information>>

The I<$info> returned is a hash reference.  The possible keys are

=over

=item included_files

An array of included file paths as they appear in the document.  Binary
strings.  From both C<@include> and C<@verbatiminclude>.

=item input_encoding_name

C<input_encoding_name> string is the encoding name used for the
Texinfo code.

=item input_file_name

=item input_directory

The name of the main Texinfo input file and the associated directory.
Binary strings.  In C<texi2any>, they should come from the command line
(and can be decoded with the encoding in the customization variable
C<COMMAND_LINE_ENCODING>).

=back

=back

Some command lists are available, such that it is possible to go through
the corresponding tree elements without walking the tree.  They are
available through C<global_commands_information>:

=over

=item $commands = global_commands_information($document)
X<C<global_commands_information>>

I<$commands> is an hash reference.  The keys are @-command names.  The
associated values are array references containing all the corresponding
tree elements.

The following list of commands is also available as a key:

=over

=item dircategory_direntry

An array of successive C<@dircategory> and C<@direntry> as they appear
in the document.

=back

=back

All the @-commands that have an associated label (so can be the
target of cross references) -- C<@node>, C<@anchor> and C<@float> with
label -- have a normalized name associated, constructed as described in the
I<HTML Xref> node in the Texinfo documentation.  Those normalized labels and
the association with @-commands is available through C<labels_information>:

=over

=item $identifier_target = labels_information($document)
X<C<labels_information>>

I<$identifier_target> is a hash reference whose keys are normalized
labels, and the associated value is the corresponding @-command.

=item $labels_list = labels_list ($document)
X<C<labels_list>>

I<$labels_list> is a list of Texinfo tree command elements that
could be the target of cross references.

=back

Information on C<@float> grouped by type of floats, each type corresponding
to potential C<@listoffloats> is available through C<floats_information>.

=over

=item $float_types = floats_information($document)
X<C<floats_information>>

I<$float_types> is a hash reference whose keys are normalized float
types (the first float argument, or the C<@listoffloats> argument).
The normalization is the same as for the first step of node names
normalization. The value is the list of float tree elements appearing
in the texinfo document.

=back

Internal references, nodes and section lists may also be available.

=over

=item $internal_references_array = internal_references_information($document)
X<C<internal_references_information>>

The function returns an array reference of cross-reference commands referring
to the same document with @-commands that refer to node, anchors or floats.

=item $nodes_list = nodes_list($document)

Returns an array reference containing the document nodes.  In general set to
the nodes list returned by L<Texinfo::Structuring
nodes_tree|Texinfo::Structuring/$nodes_list = nodes_tree($document)>, by a call
to L<register_document_nodes_list|/register_document_nodes_list ($document,
$nodes_list)>.

=item $sections_list = sections_list($document)

Returns an array reference containing the document sections.  In general set to the sections list returned by
L<Texinfo::Structuring sectioning_structure|Texinfo::Structuring/$sections_list = sectioning_structure($document)>,
by a call to L<register_document_sections_list|/register_document_sections_list ($document, $sections_list)>.

=back

Information about defined indices, indices merging and index entries is
available through C<indices_information>.

=over

=item $indices_information = $document->indices_information()
X<C<indices_information>>

I<$indices_information> is a hash reference.  The keys are

=over

=item in_code

1 if the index entries should be formatted as code, 0 in the opposite case.

=item name

The index name.

=item prefix

An array reference of prefix associated to the index.

=item merged_in

In case the index is merged to another index, this key holds the name of
the index the index is merged into.  It takes into account indirectly
merged indices.

=item index_entries

An array reference containing index entry structures for index entries
associated with the index.  The index entry could be associated to
@-commands like C<@cindex>, or C<@item> in C<@vtable>, or definition
commands entries like C<@deffn>.

The keys of the index entry structures are

=over

=item index_name

The index name associated to the command.  Not modified if the corresponding
index is merged in another index (with C<@synindex>, for example).

=item entry_element

The element in the parsed tree associated with the @-command holding the
index entry.

=item entry_number

The number of the index entry.

=back

=back

The following shows the references corresponding to the default indexes
I<cp> and I<fn>, the I<fn> index having its entries formatted as code and
the indices corresponding to the following texinfo

  @defindex some
  @defcodeindex code

  $index_names = {'cp' => {'name' => 'cp', 'in_code' => 0, },
                  'fn' => {'name' => 'fn', 'in_code' => 1, },
                  'some' => {'in_code' => 0},
                  'code' => {'in_code' => 1}};

If C<name> is not set, it is set to the index name.

=back

=head2 Merging and sorting indices

Merged and sorted document indices are also available.  Parsed indices
are not merged nor sorted, L<Texinfo::Indices> functions are
called to merge or sort the indices the first time the following
methods are called.  The results are afterwards associated to the
document and simply returned.

In general, those methods should not be called directly, instead
L<Texinfo::Convert::Converter/Index sorting> Converter methods should be
used, which already call the following functions.

=over

=item $merged_indices = $document->merged_indices()
X<C<merged_indices>>

Merge indices if needed and return merged indices.  The I<$merged_indices>
returned is a hash reference whose keys are the index names and values arrays
of index entry structures described in L</index_entries>.

L<< C<Texinfo::Indices::merge_indices>|Texinfo::Indices/$merged_indices = merge_indices($indices_information) >>
is used to merge the indices.

In general, it is not useful to call this function directly, as it is already
called by index sorting functions.

=item $sorted_indices = $document->sorted_indices_by_index($customization_information, $use_unicode_collation, $locale_lang)

=item $sorted_indices = $document->sorted_indices_by_letter($customization_information, $use_unicode_collation, $locale_lang)
X<C<sorted_indices_by_index>> X<C<sorted_indices_by_letter>>

C<sorted_indices_by_letter> returns the indices sorted by index and letter,
while C<sorted_indices_by_index> returns the indices with all entries
of an index together.

By default, indices are sorted according to the I<Unicode Collation Algorithm>
defined in the L<Unicode Technical Standard
#10|http://www.unicode.org/reports/tr10/>, without language-specific collation
tailoring.  If I<$use_unicode_collation> is set to 0, the sorting will not use
the I<Unicode Collation Algorithm> and simply sort according to the codepoints.
If I<$locale_lang> is set, the language is used for linguistic tailoring of the
sorting, if possible.

When sorting by letter, an array reference of letter hash references is
associated with each index name.  Each letter hash reference has two
keys, a I<letter> key with the letter, and an I<entries> key with an array
reference of sorted index entries beginning with the letter.  The letter
is a character string suitable for sorting letters, but is not necessarily
the best to use for output.

When simply sorting, the array of the sorted index entries is associated
with the index name.

The optional I<$customization_information> argument is used for
error reporting, both to find the L<Texinfo::Report> object to use for error
reporting and Texinfo customization variables information.  In general, it
should be a converter (L<Texinfo::Convert::Converter/Getting and setting
customization variables>) or a document L<Texinfo::Document/Getting
customization options values registered in document>).

L<< C<Texinfo::Indices::sort_indices_by_index>|Texinfo::Indices/$index_entries_sorted = sort_indices_by_index($document, $registrar, $customization_information, $use_unicode_collation, $locale_lang) >>
and L<< C<Texinfo::Indices::sort_indices_by_letter>|Texinfo::Indices/$index_entries_sorted = sort_indices_by_letter($document, $registrar, $customization_information, $use_unicode_collation, $locale_lang) >>
are used to sort the indices, if needed.

In general, those methods should not be called directly, instead
L<< C<Texinfo::Convert::Converter::get_converter_indices_sorted_by_index>|Texinfo::Convert::Converter/$sorted_indices = $converter->get_converter_indices_sorted_by_index() >>
and L<< C<Texinfo::Convert::Converter::get_converter_indices_sorted_by_letter>|Texinfo::Convert::Converter/$sorted_indices = $converter->get_converter_indices_sorted_by_letter() >>
should be used.  The C<Texinfo::Convert::Converter> methods call
C<sorted_indices_by_index> and C<sorted_indices_by_letter>.

=back

=head2 Getting errors and error registering object

A document has a L<Texinfo::Report> objet associated, that is used to
register errors and warning messages in.  To get the errors registered
in the document, the C<errors> method should be called.
It is also possible to get the document associated C<Texinfo::Report> objet
by calling the C<registrar> accessor method.

=over

=item $registrar = registrar($document)

Returns the C<Texinfo::Report> object associated with the I<$document>.

In general, this is not needed as most functions use the document associated
C<Texinfo::Report> object automatically.  However, for some functions a
C<Texinfo::Report> object is passed in argument, being able to
get the document registrar object is interesting in those cases.

=item ($error warnings list, $error count) = errors($document)

This function returns as I<$error_count> the count of errors since setting
up the I<$document> (or calling the function). The returned
I<$error_warnings_list> is an array of hash references
one for each error, warning or error line continuation.  The format of
these hash references is described
in L<C<Texinfo::Report::errors>|Texinfo::Report/($error_warnings_list, $error_count) = errors($registrar)>.

=back

=head2 Getting customization options values registered in document

By default, customization information is registered in a document object
just after parsing the Texinfo code. Structuring and tree transformation
methods then get customization variables values from the document object
they have in argument. The customization variables set by default may be a
subset selected to be useful for structuring and tree transformation codes.

To retrieve Texinfo customization variables you can call C<get_conf>:

=over

=item $value = $document->get_conf($variable_name)

Returns the value of the Texinfo customization variable I<$variable_name>
(possibly C<undef>), if the variable value was registered in the document,
or C<undef>.

=back

=head2 Registering document and information in document

The setup of a document is described next, it should only be used in
parsers codes.

=over

=item $document = Texinfo::Document::register($tree, $global_information, $indices_information, $floats_information, $internal_references_information, $global_commands_information, $identifier_target, $labels_list, $parser_registrar)

Setup a document. There is no reason to call this method out of parsers, as
it is already done by the Texinfo parsers.  The arguments are gathered
during parsing and correspond to information returned by the other methods.

=back

Further information can be registered in the document.

=over

=item register_document_nodes_list ($document, $nodes_list)
X<C<register_document_nodes_list>>

Register the I<$nodes_list> array reference as I<$document> nodes
list.  This method should be called after the processing of document
structure.

=item register_document_options ($document, $options)
X<C<register_document_options>>

The I<$options> hash reference holds options for the document. These options
should be Texinfo customization options.  Usually, the options registered in
the document contain those useful for structuring and tree transformation
getting place between Texinfo code parsing and conversion to output formats.
Indeed, document customization options are mainly accessed by structuring and
tree transformation methods (by calling L<< C<get_conf>|/$value = $document->get_conf($variable_name) >>). The options should in general be registered before
the calls to C<get_conf>.

=item register_document_sections_list ($document, $sections_list)
X<C<register_document_sections_list>>

Register the I<$sections_list> array reference as I<$document> sections
list.  This method should be called after the processing of document
structure.

=item set_document_global_info($document, $key, $value)
X<C<set_document_global_info>>

Add I<$value> I<$key> global information to I<$document>.  This method
should not be generally useful, as document global information is already
set by the Texinfo parser.  The information set should be available through
the next calls to L<global_information|/$info = global_information($document)>.
The method should in general be called before the calls to
C<global_information>.

=back

=head2 Methods for Perl and C code interactions

The parsing of Texinfo code, structuring and transformations of the tree
called through Texinfo Perl modules may be done by pure Perl modules or
by C code called through XS interfaces.  In general, it makes no difference
whether pure Perl or C code is used.  When the document and tree are
modified by C code, the Perl structures are automatically rebuilt when
calling the accessors described previously.  In some cases, however, specific
functions need to be called to pass information from C to Perl or perform
actions related to C data.

The methods can always be called on pure Perl modules even if they do nothing.
Therefore it is, in general, better to call them assuming that modules
setting up C data were called, even when it is not the case.

First, C<document_descriptor> can be called to get the document identifier
document used by C code to retrieve the document data in C.  In general
this identifier is directly and transparently taken from the document, but may
need to be set on other objects in rare cases.

=over

=item $document_descriptor = $document->document_descriptor()
X<C<document_descriptor>>

Returns the document descriptor if the document is available as C data,
0 or C<undef> if not.

=back

When the tree is directly accessed in Perl (not through a document)
but is modified by C code, for instance called through L<Texinfo::Common> or
L<Texinfo::Transformations> methods, the Perl structures need to be rebuilt
from the C data with C<rebuild_tree>:

=over

=item $rebuilt_tree = rebuild_tree($tree, $no_store)
X<C<rebuild_tree>>

Return a I<$rebuilt_tree>, rebuilt from C data if needed.  If there
is no C data, the tree is returned as is.  The tree rebuilt is
based on the Texinfo parsed document associated to the Texinfo
tree I<$tree>.

If the optional I<$no_store> argument is set, remove the C data.

=back

Note that the Perl tree associated to a document is rebuilt from C data
when calling C<< $document->tree() >>.  Similarly, the tree is rebuilt when
calling other accessors that depend on the document tree.  Therefore
C<rebuild_tree> should only be called when there is no document associated to a
tree and C<< $document->tree() >> cannot be called to rebuild the tree.

Some methods allow to release the memory held by C data associated
to a Texinfo parsed document:

=over

=item remove_document($document)
X<C<remove_document>>

Remove the C data corresponding to I<$document>.

=back

=head1 SEE ALSO

L<Texinfo::Parser>. L<Texinfo::Structuring>.

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
