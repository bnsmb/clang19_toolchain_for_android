# Transformations.pm: some transformations of the document tree
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
# Parts (also from Patrice Dumas) come from texi2html.pl.

package Texinfo::Transformations;

use 5.006;

use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);


use Carp qw(cluck confess);

use Texinfo::StructTransfXS;

use Texinfo::XSLoader;

use Texinfo::Commands;
use Texinfo::Common;
use Texinfo::Translations;
use Texinfo::Document;
use Texinfo::ManipulateTree;
use Texinfo::Structuring;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
protect_hashchar_at_line_beginning
reference_to_arg_in_tree
);

our $VERSION = '7.2';

my $XS_structuring = Texinfo::XSLoader::XS_structuring_enabled();

our %XS_overrides = (
  "Texinfo::Transformations::fill_gaps_in_sectioning"
    => "Texinfo::StructTransfXS::fill_gaps_in_sectioning",
  "Texinfo::Transformations::reference_to_arg_in_tree"
    => "Texinfo::StructTransfXS::reference_to_arg_in_tree",
  "Texinfo::Transformations::complete_tree_nodes_menus"
    => "Texinfo::StructTransfXS::complete_tree_nodes_menus",
  "Texinfo::Transformations::complete_tree_nodes_missing_menu"
    => "Texinfo::StructTransfXS::complete_tree_nodes_missing_menu",
  "Texinfo::Transformations::regenerate_master_menu"
    => "Texinfo::StructTransfXS::regenerate_master_menu",
  "Texinfo::Transformations::insert_nodes_for_sectioning_commands"
    => "Texinfo::StructTransfXS::insert_nodes_for_sectioning_commands",
  "Texinfo::Transformations::protect_hashchar_at_line_beginning"
    => "Texinfo::StructTransfXS::protect_hashchar_at_line_beginning",
  "Texinfo::Transformations::protect_first_parenthesis_in_targets"
    => "Texinfo::StructTransfXS::protect_first_parenthesis_in_targets",
);

our $module_loaded = 0;
sub import {
  if (!$module_loaded) {
    if ($XS_structuring) {
      for my $sub (keys %XS_overrides) {
        Texinfo::XSLoader::override ($sub, $XS_overrides{$sub});
      }
    }
    $module_loaded = 1;
  }
  # The usual import method
  goto &Exporter::import;
}

# Add raise/lowersections to be back at the normal level from
# the $SECTION level.  The raise/lowersections are added at the
# end of $PARENT.
# If $MODIFIER is set to -1, add raise/lowersections to go from
# the normal level to the $SECTION level.
sub _correct_level($$;$)
{
  my $section = shift;
  my $parent = shift;
  my $modifier = shift;
  $modifier = 1 if (!defined($modifier));

  if ($section->{'extra'} and $section->{'extra'}->{'level_modifier'}) {
    my $level_to_remove = $modifier * $section->{'extra'}->{'level_modifier'};
    my $cmdname;
    if ($level_to_remove < 0) {
      $cmdname = 'raisesections';
    } else {
      $cmdname = 'lowersections';
    }
    my $remaining_level = abs($level_to_remove);
    while ($remaining_level) {
      my $element = {'cmdname' => $cmdname,
                     'parent' => $parent};
      push @{$parent->{'contents'}}, $element;
      my $rawline_arg = {'type' => 'rawline_arg', 'text' => "\n",
                         'parent' => $element};
      push @{$element->{'args'}}, $rawline_arg;
      $remaining_level--;
    }
  }
}

sub fill_gaps_in_sectioning($;$)
{
  my $root = shift;
  my $commands_heading_content = shift;

  my $contents_nr = scalar(@{$root->{'contents'}});

  my @added_sections;

  # initialize current and next sections
  my $idx_current_section = -1;
  my $idx_next_section = -1;
  my $idx = 0;
  while ($idx < $contents_nr) {
    my $content = $root->{'contents'}->[$idx];
    if (! $content->{'cmdname'} or $content->{'cmdname'} eq 'node'
        or ! $Texinfo::Commands::root_commands{$content->{'cmdname'}}) {
    } elsif ($idx_current_section < 0) {
      $idx_current_section = $idx;
    } elsif ($idx_next_section < 0) {
      $idx_next_section = $idx;
      last;
    }
    $idx++;
  }

  return undef
    if ($idx_current_section < 0);

  return \@added_sections
    if ($idx_next_section < 0);

  while (1) {
    my $current_section = $root->{'contents'}->[$idx_current_section];
    my $current_section_level
       = Texinfo::Common::section_level($current_section);

    my $next_section = $root->{'contents'}->[$idx_next_section];
    my $next_section_level
       = Texinfo::Common::section_level($next_section);

    if ($next_section_level - $current_section_level > 1) {
      _correct_level($next_section, $current_section);
      my @new_sections;
      while ($next_section_level - $current_section_level > 1) {
        $current_section_level++;
        my $new_section = {'cmdname' =>
          $Texinfo::Common::level_to_structuring_command{'unnumbered'}
                                                ->[$current_section_level],
          'parent' => $root,
        };
        $new_section->{'info'} = {'spaces_before_argument' =>
                                              {'text' => ' ',}};
        my $line_arg = {'type' => 'line_arg', 'parent' => $new_section,
                        'info' => {'spaces_after_argument'
                                                 => {'text' => "\n",}}};
        $new_section->{'args'} = [$line_arg];
        my $line_content;
        if ($commands_heading_content) {
          $line_content
            = Texinfo::ManipulateTree::copy_contentsNonXS(
                                               $commands_heading_content);
          $line_content->{'parent'} = $line_arg;
        } else {
          my $asis_command = {'cmdname' => 'asis',
                              'parent' => $line_arg};
          $asis_command->{'args'} = [{'type' => 'brace_container',
                                      'parent' => $asis_command}];
          $line_content = $asis_command;
        }
        $line_arg->{'contents'} = [$line_content];
        $new_section->{'contents'} = [{'type' => 'empty_line',
                                       'text' => "\n",
                                       'parent' => $new_section}];
        push @new_sections, $new_section;
      }
      splice (@{$root->{'contents'}}, $idx_current_section+1, 0, @new_sections);
      $idx_next_section += scalar(@new_sections);
      $contents_nr += scalar(@new_sections);
      push @added_sections, @new_sections;
      _correct_level($next_section, $new_sections[-1], -1);
    }
    $idx_current_section = $idx_next_section;

    # find the new next section index
    $idx_next_section = $idx_current_section +1;
    while ($idx_next_section < $contents_nr) {
      my $content = $root->{'contents'}->[$idx_next_section];
      if ($content->{'cmdname'} and $content->{'cmdname'} ne 'node'
          and $Texinfo::Commands::root_commands{$content->{'cmdname'}}) {
        last;
      }
      $idx_next_section++;
    }
    if ($idx_next_section >= $contents_nr) {
      last;
    }
  }
  return \@added_sections;
}

# This converts a reference @-command to simple text using one of the
# arguments.  This is used to remove reference @-command from
# constructed node names trees, as node names cannot contain
# reference @-command while there could be some in the tree used in
# input for the node name tree.
sub _reference_to_arg($$$)
{
  my $type = shift;
  my $current = shift;
  my $document = shift;

  if ($current->{'cmdname'} and
      $Texinfo::Commands::ref_commands{$current->{'cmdname'}}
      and $current->{'args'}) {

    # remove from internal references
    if ($document) {
      my $internal_references = $document->internal_references_information();
      Texinfo::Common::remove_from_array($internal_references, $current);
    }

    my @args_try_order;
    if ($current->{'cmdname'} eq 'inforef'
        or $current->{'cmdname'} eq 'link') {
      @args_try_order = (0, 1, 2);
    } else {
      @args_try_order = (0, 1, 2, 4, 3);
    }
    foreach my $index (@args_try_order) {
      if (defined($current->{'args'}->[$index])) {
        my $arg = $current->{'args'}->[$index];
        # this will not detect if the arg expands as spaces only, like
        # @asis{ }, @ , but it is not an issue or could even be considered
        # as a feature.
        if (!Texinfo::Common::is_content_empty($arg)) {
          # avoid the type and spaces by getting only the contents
          my $result
            = {'contents' => $arg->{'contents'},
                        'parent' => $current->{'parent'}};
          foreach my $content (@{$arg->{'contents'}}) {
            $content->{'parent'} = $result;
          }
          return [$result];
        }
      }
    }
    return {'text' => '', 'parent' => $current->{'parent'}};
  } else {
    return undef;
  }
}

sub reference_to_arg_in_tree($;$)
{
  my $tree = shift;
  my $document = shift;

  return Texinfo::ManipulateTree::modify_tree($tree, \&_reference_to_arg,
                                              $document);
}

# prepare and add a new node as a possible cross reference targets
# modifies $document

# $CUSTOMIZATION_INFORMATION is used for error reporting, but it may
# not be useful, as the code checks that the new node target label does
# not exist already.
# Right now the $DOCUMENT error messages registrar is used to register
# error messages, instead it could be given as argument.  Does not matter
# much, see just above.
sub _new_node($$;$)
{
  my $node_tree = shift;
  my $document = shift;
  my $customization_information = shift;

  if ($XS_structuring and $Texinfo::StructTransfXS::XS_package) {
    # If there were XS overrides for all the transformations, they would
    # necessarily fail, so treat as a bug even though it does not matter
    # with missing overrides, as seen just below.
    if (!$node_tree->{'tree_document_descriptor'}) {
      print STDERR "BUG: new_node: with XS, no tree_document_descriptor\n";
    }

    # If changes are only done to underlying XS tree, the changes by
    # Texinfo::Common::protect_* will be done on the underlying XS tree,
    # but the perl tree will not change, although it is the perl tree
    # that is used to construct the node.
    # Also protect_first_parenthesis has no XS override, only
    # protect_first_parenthesis_in_targets.
    confess("BUG: _new_node: XS not supported");

    # It could have been possible to rebuild the tree, after adding
    # an override for protect_first_parenthesis.
    # If XS is used, however, it is be much better to override all
    # the functions calling the current function instead of trying
    # to have it work through an interface because the function is
    # mostly internal.  So, it is better to keep failing with XS.
    #
    # The issue arise because the current function is used in tests,
    # this cannot work with XS (and tests are skipped).
  }

  # We protect for all the contexts, as the node name should be
  # the same in the different contexts, even if some protections
  # are not needed for the parsing.  Also, this way the node tree
  # can be directly reused in the menus for example, without
  # additional protection, some parts could be double protected
  # otherwise, those that are protected with @asis.
  #
  # needed in nodes lines, @*ref and in menus with a label
  $node_tree = Texinfo::ManipulateTree::protect_comma_in_tree($node_tree);
  # always
  Texinfo::ManipulateTree::protect_first_parenthesis($node_tree);
  # in menu entry without label
  $node_tree = Texinfo::ManipulateTree::protect_colon_in_tree($node_tree);
  # in menu entry with label
  $node_tree
    = Texinfo::ManipulateTree::protect_node_after_label_in_tree($node_tree);
  $node_tree = reference_to_arg_in_tree($node_tree, $document);

  my $empty_node = 0;
  if (!$node_tree->{'contents'}
      or !scalar(@{$node_tree->{'contents'}})) {
    $node_tree->{'contents'} = [{'text' => ''}];
    $empty_node = 1;
  }

  my $comment_at_end;
  if ($node_tree->{'contents'}->[-1]->{'cmdname'}
      and ($node_tree->{'contents'}->[-1]->{'cmdname'} eq 'c'
           or $node_tree->{'contents'}->[-1]->{'cmdname'} eq 'comment')) {
    $comment_at_end = pop @{$node_tree->{'contents'}};
  }
  my $spaces_after_argument = '';
  if (scalar(@{$node_tree->{'contents'}}) > 0
             and $node_tree->{'contents'}->[-1]->{'text'}
             and $node_tree->{'contents'}->[-1]->{'text'} =~ s/(\s+)$//) {
    $spaces_after_argument = $1;
  }
  $spaces_after_argument .= "\n" unless ($spaces_after_argument =~ /\n/
                                         or $comment_at_end);

  my $appended_number = 0 +$empty_node;
  my ($node, $normalized);

  my $identifier_target = $document->labels_information();
  while (!defined($node)
         or ($identifier_target and $identifier_target->{$normalized})) {

    $node = {'cmdname' => 'node', 'extra' => {}};
    $node->{'info'} = {'spaces_before_argument' => {'text' => ' '}};
    my $node_line_arg = {'type' => 'line_arg', 'parent' => $node};
    $node->{'args'} = [$node_line_arg];
    $node_line_arg->{'info'} = {'spaces_after_argument' =>
                                     {'text' => $spaces_after_argument}};
    $node_line_arg->{'info'}->{'comment_at_end'} = $comment_at_end
      if (defined($comment_at_end));
    @{$node_line_arg->{'contents'}} = (@{$node_tree->{'contents'}});
    if ($appended_number) {
      push @{$node_line_arg->{'contents'}}, {'text' => " $appended_number"};
    }
    foreach my $content (@{$node_line_arg->{'contents'}}) {
      $content->{'parent'} = $node_line_arg;
    }

    $normalized
       = Texinfo::Convert::NodeNameNormalization::convert_to_identifier(
                       { 'contents' => $node_line_arg->{'contents'} });

    if ($normalized !~ /[^-]/) {
      if ($appended_number) {
        warn "BUG: spaces only node name despite appending $appended_number\n";
        return undef;
      } else {
        $node = undef;
      }
    }
    $appended_number++;
  }
  $node->{'extra'}->{'normalized'} = $normalized;

  my $debug;
  if ($customization_information) {
    $debug = $customization_information->get_conf('DEBUG');
  }
  Texinfo::Document::register_label_element($document, $node,
                                            $document->registrar(), $debug);

  return $node;
}

# reassociate a tree element to the new node, from previous node
sub _reassociate_to_node($$$)
{
  my $type = shift;
  my $current = shift;
  my $argument = shift;
  my ($new_node, $previous_node) = @{$argument};

  if ($current->{'cmdname'} and $current->{'cmdname'} eq 'menu') {
    if ($previous_node) {
      if (not $previous_node->{'extra'}
          or not defined($previous_node->{'extra'}->{'menus'})
          or not scalar(@{$previous_node->{'extra'}->{'menus'}})
          or not (grep {$current eq $_} @{$previous_node->{'extra'}->{'menus'}})) {
        print STDERR "BUG: menu $current not in previous node $previous_node\n";
      } else {
        @{$previous_node->{'extra'}->{'menus'}}
          = grep {$_ ne $current} @{$previous_node->{'extra'}->{'menus'}};
        delete $previous_node->{'extra'}->{'menus'} if !(@{$previous_node->{'extra'}->{'menus'}});
      }
    }
    push @{$new_node->{'extra'}->{'menus'}}, $current;
  } elsif ($current->{'extra'} and $current->{'extra'}->{'element_node'}) {
    if ($previous_node
        and $current->{'extra'}->{'element_node'} ne $previous_node) {
      print STDERR "Bug: element $current not in previous node $previous_node; "
          .Texinfo::Common::debug_print_element($current)."\n";
      print STDERR "  previous node: "
        .Texinfo::Convert::Texinfo::root_heading_command_to_texinfo($previous_node)."\n";
      print STDERR "  current node: ".
         Texinfo::Convert::Texinfo::root_heading_command_to_texinfo(
                          $current->{'extra'}->{'element_node'})."\n";
    }
    $current->{'extra'}->{'element_node'} = $new_node;
  }
  return undef;
}

sub insert_nodes_for_sectioning_commands($)
{
  my $document = shift;

  my $customization_information = $document;
  my $root = $document->tree();

  my @added_nodes;
  my $previous_node;
  my $contents_nr = scalar(@{$root->{'contents'}});
  for (my $idx = 0; $idx < $contents_nr; $idx++) {
    my $content = $root->{'contents'}->[$idx];
    if ($content->{'cmdname'} and $content->{'cmdname'} ne 'node'
        and $content->{'cmdname'} ne 'part'
        and $Texinfo::Commands::root_commands{$content->{'cmdname'}}
        and not ($content->{'extra'}
                 and $content->{'extra'}->{'associated_node'})) {
      my $new_node_tree;
      if ($content->{'cmdname'} eq 'top') {
        $new_node_tree = {'contents' => [{'text' => 'Top'}]};
      } else {
        $new_node_tree
         = Texinfo::ManipulateTree::copy_contentsNonXS($content->{'args'}->[0]);
      }
      my $new_node = _new_node($new_node_tree, $document,
                               $customization_information);
      if (defined($new_node)) {
        # insert before $content
        splice(@{$root->{'contents'}}, $idx, 0, $new_node);
        $idx++;
        $contents_nr++;
        push @added_nodes, $new_node;
        $new_node->{'extra'}->{'associated_section'} = $content;
        $content->{'extra'} = {} if (!$content->{'extra'});
        $content->{'extra'}->{'associated_node'} = $new_node;
        $new_node->{'parent'} = $content->{'parent'};
        # reassociate index entries and menus
        Texinfo::ManipulateTree::modify_tree($content, \&_reassociate_to_node,
                                             [$new_node, $previous_node]);
      }
    }
    # check is_target to avoid erroneous nodes, such as duplicates
    $previous_node = $content
      if ($content->{'cmdname'}
          and $content->{'cmdname'} eq 'node'
          and $content->{'extra'}
          and $content->{'extra'}->{'is_target'});
  }
  return \@added_nodes;
}

sub _prepend_new_menu_in_node_section($$$)
{
  my $node = shift;
  my $section = shift;
  my $current_menu = shift;

  if (not defined($current_menu)) {
    cluck "input menu undef";
  }
  push @{$section->{'contents'}}, $current_menu;
  $current_menu->{'parent'} = $section;
  push @{$section->{'contents'}}, {'type' => 'empty_line',
                                   'text' => "\n",
                                   'parent' => $section};
  push @{$node->{'extra'}->{'menus'}}, $current_menu;
}

sub complete_node_menu($;$)
{
  my $node = shift;
  my $use_sections = shift;

  my @node_childs
      = Texinfo::Structuring::get_node_node_childs_from_sectioning($node);

  if (scalar(@node_childs)) {
    my %existing_entries;
    if ($node->{'extra'}
        and $node->{'extra'}->{'menus'} and @{$node->{'extra'}->{'menus'}}) {
      foreach my $menu (@{$node->{'extra'}->{'menus'}}) {
        foreach my $entry (@{$menu->{'contents'}}) {
          if ($entry->{'type'} and $entry->{'type'} eq 'menu_entry') {
            my $normalized_entry_node
              = Texinfo::ManipulateTree::normalized_menu_entry_internal_node(
                                                                       $entry);
            if (defined($normalized_entry_node)) {
              $existing_entries{$normalized_entry_node} = [$menu, $entry];
            }
          }
        }
      }
    }
    #print STDERR "existing_entries: ".join('|', keys(%existing_entries))."\n";
    my @pending;
    my $current_menu;
    foreach my $node_entry (@node_childs) {
      if ($node_entry->{'extra'}
          and defined($node_entry->{'extra'}->{'normalized'})
          and $existing_entries{$node_entry->{'extra'}->{'normalized'}}) {
        my $entry;
        ($current_menu, $entry)
         = @{$existing_entries{$node_entry->{'extra'}->{'normalized'}}};
        if (@pending) {
          my $index;
          for ($index = 0; $index < scalar(@{$current_menu->{'contents'}}); $index++) {
            #print STDERR "$index, ".scalar(@{$current_menu->{'contents'}})."\n";
            last if ($current_menu->{'contents'}->[$index] eq $entry);
          }
          splice (@{$current_menu->{'contents'}}, $index, 0, @pending);
          foreach my $pending_entry (@pending) {
            $pending_entry->{'parent'} = $current_menu;
          }
          @pending = ();
        }
      } else {
        my $entry = Texinfo::Structuring::new_node_menu_entry($node_entry,
                                                              $use_sections);
        # not defined $entry should mean an empty node.  We do not warn as
        # we try, in general, to be silent in the transformations.
        push @pending, $entry if (defined($entry));
      }
    }
    if (scalar(@pending)) {
      if (!$current_menu) {
        my $section = $node->{'extra'}->{'associated_section'};
        $current_menu = {'contents' => \@pending, 'parent' => $section};
        Texinfo::Structuring::new_block_command($current_menu, 'menu');
        _prepend_new_menu_in_node_section($node, $section, $current_menu);
      } else {
        if ($current_menu->{'contents'}->[-1]->{'cmdname'}
            and $current_menu->{'contents'}->[-1]->{'cmdname'} eq 'end') {
          splice (@{$current_menu->{'contents'}}, -1, 0, @pending);
        } else {
          # Should probably only happen with menu without end
          push @{$current_menu->{'contents'}}, @pending;
        }
      }
      foreach my $entry (@pending) {
        $entry->{'parent'} = $current_menu;
      }
    }
  }
}

sub _get_non_automatic_nodes_with_sections($)
{
  my $root = shift;

  my @non_automatic_nodes;
  foreach my $content (@{$root->{'contents'}}) {
    if ($content->{'cmdname'} and $content->{'cmdname'} eq 'node'
        and not ($content->{'args'} and scalar(@{$content->{'args'}}) > 1)
        and $content->{'extra'}
        and $content->{'extra'}->{'associated_section'}) {
      push @non_automatic_nodes, $content;
    }
  }
  return [ @non_automatic_nodes ];
}

# This should be called after Texinfo::Structuring::sectioning_structure.
sub complete_tree_nodes_menus($;$)
{
  my $root = shift;
  my $use_sections = shift;

  my $non_automatic_nodes = _get_non_automatic_nodes_with_sections($root);
  foreach my $node (@{$non_automatic_nodes}) {
    complete_node_menu($node, $use_sections);
  }

}

# this only complete menus if there was no menu
# The document is used to pass customization information for the gdt() call.
sub complete_tree_nodes_missing_menu($;$)
{
  my $document = shift;
  my $use_sections = shift;

  my $customization_information = $document;
  my $root = $document->tree();

  my $non_automatic_nodes = _get_non_automatic_nodes_with_sections($root);
  foreach my $node (@{$non_automatic_nodes}) {
    if (not $node->{'extra'}->{'menus'}
        or not scalar(@{$node->{'extra'}->{'menus'}})) {
      my $section = $node->{'extra'}->{'associated_section'};
      my $current_menu
        = Texinfo::Structuring::new_complete_node_menu($node,
                                 $customization_information, $use_sections);
      if (defined($current_menu)) {
        _prepend_new_menu_in_node_section($node, $section, $current_menu);
      }
    }
  }
}

# The document is passed as customization information
sub regenerate_master_menu($;$)
{
  my $document = shift;
  my $use_sections = shift;

  my $identifier_target = $document->labels_information();

  my $top_node = $identifier_target->{'Top'};

  return undef if (!defined($top_node)
                   or !$top_node->{'extra'}
                   or !$top_node->{'extra'}->{'menus'}
                   or !scalar(@{$top_node->{'extra'}->{'menus'}}));

  my $new_detailmenu
      = Texinfo::Structuring::new_detailmenu($document,
                      $document->registrar(),
                      $identifier_target, $top_node->{'extra'}->{'menus'},
                      $use_sections);
  return undef if (!defined($new_detailmenu));

  my $global_detailmenu
    = $document->global_commands_information()->{'detailmenu'};
  foreach my $menu (@{$top_node->{'extra'}->{'menus'}}) {
    my $detailmenu_index = 0;
    foreach my $entry (@{$menu->{'contents'}}) {
      if ($entry->{'cmdname'} and $entry->{'cmdname'} eq 'detailmenu') {
        # replace existing detailmenu by the master menu
        $new_detailmenu->{'parent'} = $menu;
        splice (@{$menu->{'contents'}}, $detailmenu_index, 1,
                $new_detailmenu);
        # also replace in global commands
        my $index = 0;
        my $global_detailmenu_index = -1;
        foreach my $detailmenu_global (@$global_detailmenu) {
          if ($detailmenu_global eq $entry) {
            $global_detailmenu_index = $index;
            last;
          }
          $index++;
        }
        if ($global_detailmenu_index >= 0) {
          splice (@$global_detailmenu, $global_detailmenu_index, 1,
                  $new_detailmenu);
        }
        # NOTE the menu entries added in @detailmenu are not added as
        # internal references.  However, this is not an issue, as the
        # menu entries in @detailmenu are also in regular menus.
        # As long as internal references are only used to check if all
        # the nodes are referenced, not having @detailmenu entries
        # added is not an issue at all.

        # remove internal refs of removed entries
        my $internal_references = $document->internal_references_information();
        foreach my $detailmenu_entry (@{$entry->{'contents'}}) {
          if ($detailmenu_entry->{'type'}
              and $detailmenu_entry->{'type'} eq 'menu_entry') {
            foreach my $entry_content (@{$detailmenu_entry->{'contents'}}) {
              if ($entry_content->{'type'}
                  and $entry_content->{'type'} eq 'menu_entry_node') {
                Texinfo::Common::remove_from_array($internal_references,
                                                   $entry_content);
              }
            }
          }
        }
        return 1;
      }
      $detailmenu_index++;
    }
  }

  my $last_menu = $top_node->{'extra'}->{'menus'}->[-1];
  my $index = scalar(@{$last_menu->{'contents'}});
  if ($index
      and $last_menu->{'contents'}->[$index-1]->{'cmdname'}
      and $last_menu->{'contents'}->[$index-1]->{'cmdname'} eq 'end') {
    $index --;
  }

  $new_detailmenu->{'parent'} = $last_menu;
  if ($index) {
    my $last_element = $last_menu->{'contents'}->[$index-1];
    if ($last_element->{'type'} and $last_element->{'type'} eq 'menu_comment'
        and scalar(@{$last_element->{'contents'}})
        and $last_element->{'contents'}->[-1]->{'type'}
        and $last_element->{'contents'}->[-1]->{'type'} eq 'preformatted') {
      {
        # already a menu comment at the end of the menu, add an empty line
        my $preformatted = $last_element->{'contents'}->[-1];
        my $empty_line = {'type' => 'empty_line', 'text' => "\n",
                          'parent' => $preformatted};
        push @{$preformatted->{'contents'}}, $empty_line;
      }
    } elsif ($last_element->{'type'}
             and $last_element->{'type'} eq 'menu_entry') {
      # there is a last menu entry, add a menu comment containing an empty line
      # after it
      my $menu_comment = {'type' => 'menu_comment', 'parent' => $last_menu};
      splice (@{$last_menu->{'contents'}}, $index, 0, $menu_comment);
      $index++;
      my $preformatted = {'type' => 'preformatted', 'parent' => $menu_comment};
      push @{$menu_comment->{'contents'}}, $preformatted;
      my $empty_line = {'type' => 'after_menu_description_line', 'text' => "\n",
                        'parent' => $preformatted};
      push @{$preformatted->{'contents'}}, $empty_line;
    }
  }
  # insert master menu
  splice (@{$last_menu->{'contents'}}, $index, 0, $new_detailmenu);
  push @$global_detailmenu, $new_detailmenu;

  return 1;
}

# modify the menu tree to put description and menu comment content
# together directly in the menu.  Put the menu_entry in a preformatted.
# last merge preformatted.
sub menu_to_simple_menu($);

sub menu_to_simple_menu($)
{
  my $menu = shift;

  my @contents;
  foreach my $content (@{$menu->{'contents'}}) {
    if ($content->{'type'} and $content->{'type'} eq 'menu_comment') {
      push @contents, @{$content->{'contents'}};
    } elsif ($content->{'type'} and $content->{'type'} eq 'menu_entry') {
      my $preformatted = {'type' => 'preformatted', 'contents' => [$content]};
      push @contents, $preformatted;
      $content->{'parent'} = $preformatted;

      my $in_description;
      my @args = @{$content->{'contents'}};
      @{$content->{'contents'}} = ();
      while (@args) {
        if ($args[0]->{'type'} and $args[0]->{'type'} eq 'menu_entry_description') {
          my $description = shift @args;
          push @contents, @{$description->{'contents'}};
          push @contents, @args;
          last;
        } else {
          my $arg = shift @args;
          push @{$content->{'contents'}}, $arg;
        }
      }
    } elsif ($content->{'cmdname'}
             and $Texinfo::Commands::block_commands{$content->{'cmdname'}}
  and $Texinfo::Commands::block_commands{$content->{'cmdname'}} eq 'menu') {
      menu_to_simple_menu($content);
      push @contents, $content;
    } else {
      push @contents, $content;
    }
  }

  # reset parent, put in menu and merge preformatted.
  @{$menu->{'contents'}} = ();
  my $current_preformatted;
  foreach my $content (@contents) {
    $content->{'parent'} = $menu;
    if ($content->{'type'} and $content->{'type'} eq 'preformatted') {
      if (!defined($current_preformatted)) {
        $current_preformatted = $content;
        push @{$menu->{'contents'}}, $content;
      } else {
        foreach my $preformatted_content (@{$content->{'contents'}}) {
          push @{$current_preformatted->{'contents'}}, $preformatted_content;
          $preformatted_content->{'parent'} = $current_preformatted;
        }
      }
    } else {
      $current_preformatted = undef;
      push @{$menu->{'contents'}}, $content;
    }
  }
}

sub set_menus_to_simple_menu($)
{
  my $nodes_list = shift;

  if ($nodes_list) {
    foreach my $node (@{$nodes_list}) {
      if ($node->{'extra'} and $node->{'extra'}->{'menus'}) {
        foreach my $menu (@{$node->{'extra'}->{'menus'}}) {
          menu_to_simple_menu($menu);
        }
      }
    }
  }
}

sub _protect_hashchar_at_line_beginning($$$)
{
  my $type = shift;
  my $current = shift;
  my $argument = shift;

  my ($registrar, $customization_information) = @$argument;

  if ($current->{'text'} and
      $current->{'text'} =~ /^\s*#\s*(line)? (\d+)(( "([^"]+)")(\s+\d+)*)?\s*$/
      and $current->{'parent'} and $current->{'parent'}->{'contents'}) {
    # find the $current element index in parent to check if first or preceded
    # by a new line
    my $parent = $current->{'parent'};
    for (my $i = 0; $i < scalar(@{$parent->{'contents'}}); $i++) {
      if ($parent->{'contents'}->[$i] eq $current) {
        # protect if first in container, or if after a newline
        if ($i == 0
            or ($parent->{'contents'}->[$i-1]->{'text'}
                and $parent->{'contents'}->[$i-1]->{'text'} =~ /\n$/)) {
          # do not actually protect in raw block command, but warn
          if ($current->{'type'} and $current->{'type'} eq 'raw') {
            my $parent_for_warn = $parent;
            while ($parent_for_warn) {
              if ($parent_for_warn->{'cmdname'}
                  and $parent_for_warn->{'source_info'}) {
                if ($registrar) {
                  $registrar->line_warn(sprintf(__(
                      "could not protect hash character in \@%s"),
                           $parent_for_warn->{'cmdname'}),
                                        $parent_for_warn->{'source_info'}, 0,
                                $customization_information->get_conf('DEBUG'));
                }
                last;
              }
              $parent_for_warn = $parent_for_warn->{'parent'};
            }
            return undef;
          } else {
            my @result = ();
            my $remaining_source_marks;
            my $current_position = 0;
            if ($current->{'source_marks'}) {
              $remaining_source_marks = [@{$current->{'source_marks'}}];
              delete $current->{'source_marks'};
            }

            $current->{'text'} =~ s/^(\s*)#//;

            my $e = {'text' => $1, 'parent' => $parent};
            $current_position = Texinfo::Common::relocate_source_marks(
                                        $remaining_source_marks, $e,
                                        $current_position, length($1));
            if ($e->{'text'} ne '' or $e->{'source_marks'}) {
              push @result, $e;
            }

            $e = {'cmdname' => 'hashchar', 'parent' => $parent};
            my $arg = {'type' => 'brace_container', 'parent' => $e};
            $e->{'args'} = [$arg];
            $current_position = Texinfo::Common::relocate_source_marks(
                                          $remaining_source_marks, $e,
                                          $current_position, 1);
            push @result, $e;

            $current_position = Texinfo::Common::relocate_source_marks(
                                          $remaining_source_marks, $current,
                                          $current_position,
                                          length($current->{'text'}));
            push @result, $current;
            return \@result;
          }
        }
      }
    }
  }
  return undef;
}

sub protect_hashchar_at_line_beginning($;$$)
{
  my $tree = shift;
  my $registrar = shift;
  my $customization_information = shift;

  return Texinfo::ManipulateTree::modify_tree($tree,
                     \&_protect_hashchar_at_line_beginning,
                      [$registrar, $customization_information]);
}

sub _protect_first_parenthesis_in_targets($$$)
{
  my $type = shift;
  my $current = shift;
  my $argument = shift;

  my $element_label = Texinfo::Common::get_label_element($current);
  if ($element_label) {
    Texinfo::ManipulateTree::protect_first_parenthesis($element_label);
  }
  return undef;
}

# TODO not documented
sub protect_first_parenthesis_in_targets($)
{
  my $tree = shift;

  Texinfo::ManipulateTree::modify_tree($tree,
                           \&_protect_first_parenthesis_in_targets);
}

1;

__END__

=head1 NAME

Texinfo::Transformations - transformations of Texinfo tree

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

Includes miscellaneous methods such as as
C<insert_nodes_for_sectioning_commands> that adds nodes for sectioning commands
without nodes and C<complete_tree_nodes_menus> and
C<complete_tree_nodes_missing_menu> that completes the node menus based on the
sectioning tree.

Methods for copying and modifying the Texinfo tree used for default
conversion to output formats are in L<Texinfo::ManipulateTree>.

=head1 METHODS

No method is exported in the default case.

=over

=item complete_tree_nodes_menus($tree, $add_section_names_in_entries)
X<C<complete_tree_nodes_menus>>

Add menu entries or whole menus for nodes associated with sections,
based on the sectioning tree.  If the optional
C<$add_section_names_in_entries> argument is set, a menu entry
name is added using the section name.  This function should be
called after L<sectioning_structure|Texinfo::Structuring/$sections_list = sectioning_structure($document)>.

=item complete_tree_nodes_missing_menu($document, $use_section_names_in_entries)
X<C<complete_tree_nodes_missing_menu>>

Add whole menus for nodes associated with sections and without menu,
based on the I<$document> sectioning tree.
If the optional I<$add_section_names_in_entries> argument is set, a menu entry
name is added using the section name.  This function should be
called after L<sectioning_structure|Texinfo::Structuring/$sections_list = sectioning_structure($document)>.

=item fill_gaps_in_sectioning($tree, $commands_heading_tree)
X<C<fill_gaps_in_sectioning>>

This function adds empty C<@unnumbered> and similar commands in a tree
to fill gaps in sectioning.  This may be used, for example, when converting
from a format that can handle gaps in sectioning.  I<$tree> is the tree
root, which is modified by adding the new sectioning commands.

In the default case, the added sectioning commands headings are empty.  It is
possible to use instead the I<$commands_heading_tree> Texinfo tree element.

If the sectioning commands are lowered or raised (with C<@raisesections>,
C<@lowersection>) the tree may be modified with C<@raisesections> or
C<@lowersection> added to some tree elements.

=item insert_nodes_for_sectioning_commands($document)
X<C<insert_nodes_for_sectioning_commands>>

Insert nodes for sectioning commands without node in C<$document>
tree.

=item menu_to_simple_menu($menu)

=item set_menus_to_simple_menu($nodes_list)
X<C<menu_to_simple_menu>>
X<C<set_menus_to_simple_menu>>

C<menu_to_simple_menu> transforms the tree of a menu tree element.
C<set_menus_to_simple_menu> calls C<menu_to_simple_menu> for all the
menus of the nodes in C<$nodes_list>.

A simple menu has no I<menu_comment>, I<menu_entry> or I<menu_entry_description>
container anymore, their content are merged directly in the menu in
I<preformatted> container.

Note that this kind of tree is not supported by other codes, so this
transformation should be avoided unless one knows exactly what to expect.

=item protect_hashchar_at_line_beginning($tree, $registrar, $customization_information)
X<C<protect_hashchar_at_line_beginning>>

Protect hash (#) character at the beginning of line such that they would not be
considered as lines to be processed by the CPP processor.  The I<$registrar>
and I<$customization_information> arguments are optional.  If defined, the
I<$registrar> argument should be a L<Texinfo::Report> object in which the
errors and warnings encountered while parsing are registered.  If defined,
I<$customization_information> should give access to customization through
C<get_conf>.  If both I<$registrar> and I<$customization_information> are
defined they are used for error reporting in case an hash character could not
be protected because it appeared in a raw formatted environment (C<@tex>,
C<@html>...).

=item $modified_tree = reference_to_arg_in_tree($tree, $document)
X<C<reference_to_arg_in_tree>>

Modify I<$tree> by converting reference @-commands to simple text using one of
the arguments.  This transformation can be used, for example, to remove
reference @-command from constructed node names trees, as node names cannot
contain reference @-command while there could be some in the tree used in input
for the node name tree.  The I<$document> argument is optional.  If given,
the converted reference @-command is removed from the I<$document> internal
references list.

A I<$modified_tree> is not systematically returned, if the I<$tree> in argument
is not replaced, undef may also be returned.

=item regenerate_master_menu($document, $use_sections)
X<C<regenerate_master_menu>>

Regenerate the I<$document> Top node master menu, replacing the first
detailmenu in Top node menus or appending at the end of the Top node menu.

I<$use_sections> is an optional argument.  If set, sections associated with
nodes are used as labels in the generated master menu.

=back

=head1 SEE ALSO

L<Texinfo manual|http://www.gnu.org/s/texinfo/manual/texinfo/>,
L<Texinfo::Parser>, L<Texinfo::ManipulateTree>.

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
