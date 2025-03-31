# Texinfo.pm: output a Texinfo tree as Texinfo.
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

package Texinfo::Convert::Texinfo;

use 5.006;
use strict;

# stop \s from matching non-ASCII spaces, etc.  \p{...} can still be
# used to match Unicode character classes.
use if $] >= 5.014, re => '/a';

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Carp qw(cluck confess);

use Texinfo::Convert::ConvertXS;
use Texinfo::XSLoader;

# commands definitions
use Texinfo::Commands;
# get_label_element
use Texinfo::Common;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
  convert_to_texinfo
  link_element_to_texi
  target_element_to_texi_label
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
        "Texinfo::Convert::Texinfo::_convert_tree_with_XS",
        "Texinfo::Convert::ConvertXS::plain_texinfo_convert_tree"
      );
    }
    $module_loaded = 1;
  }
  # The usual import method
  goto &Exporter::import;
}

my %brace_commands           = %Texinfo::Commands::brace_commands;
my %block_commands           = %Texinfo::Commands::block_commands;
my %def_commands             = %Texinfo::Commands::def_commands;

# used in root_heading_command_to_texinfo
my %sectioning_heading_commands = %Texinfo::Commands::sectioning_heading_commands;

# This is used if the document is available for XS, but XS is not
# used (most likely $TEXINFO_XS_CONVERT is 0).
sub _convert_tree_with_XS($)
{
  my $root = shift;

  return _convert_to_texinfo($root);
}

sub _convert_to_texinfo($);
# expand a tree to the corresponding texinfo.
sub convert_to_texinfo($)
{
  my $element = shift;

  if (defined($element->{'tree_document_descriptor'})) {
    return _convert_tree_with_XS($element);
  }
  return _convert_to_texinfo($element);
}

# TODO document?
sub link_element_to_texi($)
{
  my $element = shift;
  my $result = '';
  return $result if (!$element->{'extra'});
  if ($element->{'extra'}->{'manual_content'}) {
    $result = '('.convert_to_texinfo($element->{'extra'}->{'manual_content'})
                    .')';
  }
  if ($element->{'extra'}->{'node_content'}) {
    $result .= convert_to_texinfo($element->{'extra'}->{'node_content'});
  }
  return $result
}

# TODO document?
sub target_element_to_texi_label($)
{
  my $element = shift;
  my $label_element = Texinfo::Common::get_label_element($element);
  # get_label_element does not handle links to external manuals in menus
  if (!defined($label_element)) {
    return link_element_to_texi($element);
  }
  return convert_to_texinfo({'contents' => $label_element->{'contents'}});
}

# only used in Texinfo::Structuring.  Here and not in Texinfo::Structuring
# to use re => '/a'.
# $REFERENCE_NODE should always be a target element associated to
# a label.
sub check_node_same_texinfo_code($$)
{
  my $reference_node = shift;
  my $node_content = shift;

  my $reference_node_texi;
  if (defined($reference_node->{'extra'}->{'normalized'})) {
    my $label_element = Texinfo::Common::get_label_element($reference_node);
    $reference_node_texi = convert_to_texinfo(
                                {'contents' => $label_element->{'contents'}});
    $reference_node_texi =~ s/\s+/ /g;
  } else {
    $reference_node_texi = '';
  }

  my $node_texi;
  if ($node_content) {
    my $contents_node = $node_content;
    if ($node_content->{'contents'}->[-1]->{'type'}
        and $node_content->{'contents'}->[-1]->{'type'}
                                      eq 'space_at_end_menu_node') {
      $contents_node = {'contents' => [@{$node_content->{'contents'}}]};
      pop @{$contents_node->{'contents'}};
    }
    $node_texi = convert_to_texinfo($contents_node);
    $node_texi =~ s/\s+/ /g;
  } else {
    $node_texi = '';
  }
  return ($reference_node_texi eq $node_texi);
}

# for debugging.
sub root_heading_command_to_texinfo($)
{
  my $element = shift;
  my $tree;
  if ($element->{'cmdname'}) {
    if (($element->{'cmdname'} eq 'node'
         or $sectioning_heading_commands{$element->{'cmdname'}})
        and $element->{'args'}->[0]->{'contents'}) {
      $tree = $element->{'args'}->[0]->{'contents'};
    }
  } else {
    return "Not a command";
  }
  if ($tree) {
    return '@'.$element->{'cmdname'}.' '
                .convert_to_texinfo({'contents' => $tree});
  } else {
    return '@'.$element->{'cmdname'};
  }
}

# Following subroutines deal with transforming a texinfo tree into texinfo
# text.  Should give the text that was used parsed, except for a few cases.

sub _convert_to_texinfo($)
{
  my $element = shift;

  confess "convert_to_texinfo: element undef" if (!defined($element));
  confess "convert_to_texinfo: bad element type (".ref($element).") $element"
     if (ref($element) ne 'HASH');
  my $result = '';

  return '' if ($element->{'info'}
                and $element->{'info'}->{'inserted'});
  if (defined($element->{'text'})) {
    $result .= $element->{'text'};
  } else {
    if ($element->{'cmdname'}
        or ($element->{'type'} and $element->{'type'} eq 'def_line')) {
      $result .= _expand_cmd_args_to_texi($element);
    } else {
      if ($element->{'type'}
          and ($element->{'type'} eq 'bracketed_arg'
               or $element->{'type'} eq 'bracketed_linemacro_arg')) {
        $result .= '{';
      }
      if ($element->{'info'}
          and $element->{'info'}->{'spaces_before_argument'}) {
        $result .= $element->{'info'}->{'spaces_before_argument'}->{'text'};
      }
    }
    if (defined($element->{'contents'})) {
      foreach my $child (@{$element->{'contents'}}) {
        $result .= _convert_to_texinfo($child);
      }
    }
    if ($element->{'info'} and $element->{'info'}->{'spaces_after_argument'}) {
      $result .= $element->{'info'}->{'spaces_after_argument'}->{'text'};
    }
    if ($element->{'info'} and $element->{'info'}->{'comment_at_end'}) {
      $result .= _convert_to_texinfo($element->{'info'}->{'comment_at_end'})
    }
    $result .= '}' if ($element->{'type'}
                       and ($element->{'type'} eq 'bracketed_arg'
                            or $element->{'type'} eq 'bracketed_linemacro_arg'));
  }
  return $result;
}

# expand a command argument as texinfo.
sub _expand_cmd_args_to_texi($) {
  my $cmd = shift;

  my $cmdname = $cmd->{'cmdname'};
  $cmdname = '' if (! defined($cmd->{'cmdname'}));
  my $result = '';

  if ($cmdname) {
    $result = '@'.$cmdname;

    # this is done here otherwise for some constructs, there are
    # no 'args', and so the space is never readded.
    if ($cmd->{'info'}
        and $cmd->{'info'}->{'spaces_after_cmd_before_arg'}) {
      $result .= $cmd->{'info'}->{'spaces_after_cmd_before_arg'}->{'text'};
    }
  }
  # arg_line set for line_commands with type special and @macro
  if ($cmd->{'info'} and defined($cmd->{'info'}->{'arg_line'})) {
    $result .= $cmd->{'info'}->{'spaces_before_argument'}->{'text'}
      if $cmd->{'info'} and $cmd->{'info'}->{'spaces_before_argument'};
    $result .= $cmd->{'info'}->{'arg_line'};
  } elsif ($cmd->{'args'}) {
    my $braces;
    $braces = 1 if (scalar(@{$cmd->{'args'}})
                    and ($cmd->{'args'}->[0]->{'type'}
                          and ($cmd->{'args'}->[0]->{'type'} eq 'brace_container'
                               or $cmd->{'args'}->[0]->{'type'} eq 'brace_arg'
                               or $cmd->{'args'}->[0]->{'type'} eq 'brace_command_context')));
    $result .= '{' if ($braces);
    if ($cmdname eq 'verb') {
      $result .= $cmd->{'info'}->{'delimiter'};
    }
    $result .= $cmd->{'info'}->{'spaces_before_argument'}->{'text'}
       if ($cmd->{'info'} and $cmd->{'info'}->{'spaces_before_argument'});
    my $with_commas = 0;
    if (($block_commands{$cmdname}
         # block line commands with arguments not separated by commas
         and not ($def_commands{$cmdname}
                  or $block_commands{$cmdname} eq 'multitable'))
        or $cmdname eq 'node'
        or exists($brace_commands{$cmdname})
        or ($cmd->{'type'} and $cmd->{'type'} eq 'definfoenclose_command')) {
      $with_commas = 1;
    }
    my $arg_nr = 0;
    foreach my $arg (@{$cmd->{'args'}}) {
      next if ($arg->{'info'} and $arg->{'info'}->{'inserted'});
      if ($with_commas) {
        $result .= ',' if ($arg_nr);
        $arg_nr++;
      }
      $result .= _convert_to_texinfo($arg);
    }
    if ($cmdname eq 'verb') {
      $result .= $cmd->{'info'}->{'delimiter'};
    }
    $result .= '}' if ($braces);
  } else {
    $result .= $cmd->{'info'}->{'spaces_before_argument'}->{'text'}
      if $cmd->{'info'} and $cmd->{'info'}->{'spaces_before_argument'};
  }
  return $result;
}

1;
__END__

=head1 NAME

Texinfo::Convert::Texinfo - Convert a Texinfo tree to Texinfo code

=head1 SYNOPSIS

  use Texinfo::Convert::Texinfo qw(convert_to_texinfo);

  my $texinfo_text = convert_to_texinfo($tree);

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

C<Texinfo::Convert::Texinfo> converts a Texinfo tree (described in
L<Texinfo::Parser>) to Texinfo code.  If the Texinfo tree results from
parsing some Texinfo document, The converted Texinfo code should be
exactly the same as the initial document, except that user defined @-macros
and C<@value> are expanded, and some invalid code is discarded.

=head1 METHODS

=over

=item $texinfo_text = convert_to_texinfo($tree)
X<C<convert_to_texinfo>>

Converts the Texinfo tree I<$tree> to Texinfo code.

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
