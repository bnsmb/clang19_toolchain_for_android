# OutputUnits.pm: setup and manage Texinfo document output units
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

package Texinfo::OutputUnits;

use 5.006;

# See comment at start of HTML.pm
use if $] >= 5.012, feature => 'unicode_strings';

# stop \s from matching non-ASCII spaces, etc.  \p{...} can still be
# used to match Unicode character classes.
use if $] >= 5.014, re => '/a';

use strict;

# Can be used to check that there is no incorrect autovivfication
#no autovivification qw(fetch delete exists store strict);

use Carp qw(cluck confess);

use Texinfo::StructTransfXS;

use Texinfo::XSLoader;

use Texinfo::Commands;
use Texinfo::Common;
use Texinfo::HTMLData;
use Texinfo::ManipulateTree;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
  units_directions
  units_file_directions
  split_by_node
  split_by_section
  split_pages
);

our $VERSION = '7.2';

my $XS_structuring = Texinfo::XSLoader::XS_structuring_enabled();

my %XS_overrides = (
  "Texinfo::OutputUnits::rebuild_output_units"
    => "Texinfo::StructTransfXS::rebuild_output_units",
  "Texinfo::OutputUnits::_XS_unsplit"
    => "Texinfo::StructTransfXS::unsplit",
);

# used in conversion only, and should only be loaded with XS converters
my %XS_convert_overrides = (
  # Not useful for HTML as functions, as the calling functions are
  # already overriden
  # Could be readded when other converters than HTML are done in C
  #  "Texinfo::OutputUnits::split_by_node"
  #    => "Texinfo::StructTransfXS::split_by_node");
  #  "Texinfo::OutputUnits::split_by_section"
  #    => "Texinfo::StructTransfXS::split_by_section");
  #  "Texinfo::OutputUnits::split_pages"
  #    => "Texinfo::StructTransfXS::split_pages"
);

our $module_loaded = 0;
sub import {
  if (!$module_loaded) {
    if ($XS_structuring) {
      for my $sub (keys %XS_overrides) {
        Texinfo::XSLoader::override ($sub, $XS_overrides{$sub});
      }
    }
    #if ($XS_convert) {
    #  for my $sub (keys %XS_convert_overrides) {
    #    Texinfo::XSLoader::override ($sub, $XS_convert_overrides{$sub});
    #  }
    #}
    $module_loaded = 1;
  }
  # The usual import method
  goto &Exporter::import;
}

# Return a list of output units.  Each output unit starts with a @node as its
# first content (except possibly the first one).  It is important that this
# function reassociates all the root commands such that the result does not
# depend on the previous association (if any).
sub split_by_node($)
{
  my $document = shift;
  my $root = $document->tree();

  my $output_units;

  my $current = { 'unit_type' => 'unit' };
  push @$output_units, $current;
  my @pending_parts = ();
  foreach my $content (@{$root->{'contents'}}) {
    if ($content->{'cmdname'} and $content->{'cmdname'} eq 'part') {
      push @pending_parts, $content;
      next;
    }
    if ($content->{'cmdname'} and $content->{'cmdname'} eq 'node') {
      if (not $current->{'unit_command'}) {
        $current->{'unit_command'} = $content;
      } else {
        $current = { 'unit_type' => 'unit', 'unit_command' => $content,
                    'tree_unit_directions' => {'prev' => $output_units->[-1]}};
        $output_units->[-1]->{'tree_unit_directions'} = {}
            if (! $output_units->[-1]->{'tree_unit_directions'});
        $output_units->[-1]->{'tree_unit_directions'}->{'next'} = $current;
        push @$output_units, $current;
      }
    }
    if (@pending_parts) {
      foreach my $part (@pending_parts) {
        push @{$current->{'unit_contents'}}, $part;
        $part->{'associated_unit'} = $current;
      }
      @pending_parts = ();
    }
    push @{$current->{'unit_contents'}}, $content;
    #if (defined($content->{'associated_unit'})) {
    #  print STDERR "Resetting node associated_unit for $content\n";
    #}
    $content->{'associated_unit'} = $current;
  }
  if (@pending_parts) {
    foreach my $part (@pending_parts) {
      push @{$current->{'unit_contents'}}, $part;
      $part->{'associated_unit'} = $current;
    }
    @pending_parts = ();
  }

  return $output_units;
}

# Return a list of output units.  Each output unit starts with the @node
# associated with a sectioning command or with the sectioning command if there
# is no associated node.  It is important that this function reassociates all
# the root commands such that the result does not depend on the previous
# association (if any).
sub split_by_section($)
{
  my $document = shift;
  my $root = $document->tree();

  my $output_units;

  my $current = { 'unit_type' => 'unit' };
  push @$output_units, $current;
  foreach my $content (@{$root->{'contents'}}) {
    my $new_section;
    if ($content->{'cmdname'} and $content->{'cmdname'} eq 'node'
        and $content->{'extra'}
        and $content->{'extra'}->{'associated_section'}) {
      $new_section = $content->{'extra'}->{'associated_section'};
    } elsif ($content->{'cmdname'} and $content->{'cmdname'} eq 'part'
             and $content->{'extra'}
             and $content->{'extra'}->{'part_associated_section'}) {
      $new_section = $content->{'extra'}->{'part_associated_section'};
    } elsif ($content->{'cmdname'} and $content->{'cmdname'} ne 'node'
             and $Texinfo::Commands::root_commands{$content->{'cmdname'}}) {
      $new_section = $content;
    }
    if ($new_section) {
      if (not defined($current->{'unit_command'})) {
        $current->{'unit_command'} = $new_section;
      } elsif ($new_section ne $current->{'unit_command'}) {
        $current = { 'unit_type' => 'unit',
                     'unit_command' => $new_section,
                     'tree_unit_directions' => {'prev' => $output_units->[-1]}};
        $output_units->[-1]->{'tree_unit_directions'} = {}
            if (! $output_units->[-1]->{'tree_unit_directions'});
        $output_units->[-1]->{'tree_unit_directions'}->{'next'} = $current;
        push @$output_units, $current;
      }
    }
    push @{$current->{'unit_contents'}}, $content;
    #if ($content->{'associated_unit'}) {
    #  print STDERR "Resetting section associated_unit for $content\n";
    #}
    $content->{'associated_unit'} = $current;
  }
  return $output_units;
}

sub _XS_unsplit($)
{
  my $document = shift;
  return -3;
}

# remove the association with document units
# NOTE not documented, but is internally used for tests only.
# In the situation where unsplit is called, in the test suite, it is
# always better to do it both for XS and perl.
sub unsplit($)
{
  my $document = shift;

  my $unsplit_needed = 0;
  my $XS_unsplit_needed = _XS_unsplit($document);
  if ($XS_unsplit_needed > 0) {
    $unsplit_needed = 1;
  }

  my $root = $document->tree();
  if (!$root->{'type'} or $root->{'type'} ne 'document_root'
      or !$root->{'contents'}) {
    return 0;
  }
  foreach my $content (@{$root->{'contents'}}) {
    if ($content->{'associated_unit'}) {
      delete $content->{'associated_unit'};
      $unsplit_needed = 1;
    }
  }
  return $unsplit_needed;
}

# does nothing in perl, the XS version reexports the output units
sub rebuild_output_units($$)
{
  my $document = shift;
  my $output_units = shift;
}

# Associate top-level units with pages according to the splitting
# specification.  Set 'first_in_page' on each unit to the unit
# that is the first in the output page.
sub split_pages($$)
{
  my $output_units = shift;
  my $split = shift;

  return if (!$output_units or !scalar(@$output_units));

  my $split_level;
  if (!$split) {
    foreach my $output_unit (@$output_units) {
      $output_unit->{'first_in_page'} = $output_units->[0];
    }
    return;
  } elsif ($split eq 'chapter') {
    $split_level = 1;
  } elsif ($split eq 'section') {
    $split_level = 2;
  } elsif ($split ne 'node') {
    warn "Unknown split specification: $split\n";
  }

  my $current_first_in_page;
  foreach my $output_unit (@$output_units) {
    my $level;
    my $section = _output_unit_section($output_unit);
    if (defined($section)) {
      $level = $section->{'extra'}->{'section_level'};
    }
    #print STDERR "level($split_level) $level "
    #       .output_unit_texi($output_unit)."\n";
    if (!defined($split_level) or (defined($level) and $split_level >= $level)
        or !$current_first_in_page) {
      $current_first_in_page = $output_unit;
    }
    $output_unit->{'first_in_page'} = $current_first_in_page;
  }
}

# Returns something associated with a label that can be used to setup a target
# to the label.  If the target is an external node, create the output unit here,
# if it is a node return the output unit that is supposed to be the
# target for links to the node.  Otherwise there is no such element (yet),
# for floats and anchor, return undef.
sub _label_target_unit_element($)
{
  my $label = shift;
  if ($label->{'extra'} and $label->{'extra'}->{'manual_content'}) {
    # setup an output_unit for consistency with regular output units
    my $external_node_unit = { 'unit_type' => 'external_node_unit',
                               'unit_command' => $label };
    return $external_node_unit;
  } elsif ($label->{'cmdname'} and $label->{'cmdname'} eq 'node') {
    return $label->{'associated_unit'};
  } else {
    # case of a @float or an @anchor, no target element defined at this stage
    return undef;
  }
}

sub _output_unit_section($)
{
  my $output_unit = shift;
  if (not defined($output_unit->{'unit_command'})) {
    return undef;
  }
  my $element = $output_unit->{'unit_command'};
  if ($element->{'cmdname'} eq 'node') {
    if ($element->{'extra'}
        and $element->{'extra'}->{'associated_section'}) {
      return $element->{'extra'}->{'associated_section'};
    } else {
      return undef;
    }
  } else {
    return $element;
  }
}

sub _output_unit_node($)
{
  my $output_unit = shift;
  if (not defined($output_unit->{'unit_command'})) {
    return undef;
  }
  my $element = $output_unit->{'unit_command'};
  if ($element->{'cmdname'} eq 'node') {
    return $element;
  } else {
    if ($element->{'extra'}
        and $element->{'extra'}->{'associated_node'}) {
      return $element->{'extra'}->{'associated_node'}
    } else {
      return undef;
    }
  }
}

# Do output units directions and store them in 'directions'.
# The directions are only created if pointing to other output units.
sub units_directions($$;$)
{
  my $identifier_target = shift;
  my $output_units = shift;
  my $print_debug = shift;

  return if (!$output_units or !scalar(@$output_units));

  my $node_top = $identifier_target->{'Top'};
  foreach my $output_unit (@$output_units) {
    my $directions = {};
    $directions->{'This'} = $output_unit;
    $directions->{'Forward'} = $output_unit->{'tree_unit_directions'}->{'next'}
      if ($output_unit->{'tree_unit_directions'}
          and $output_unit->{'tree_unit_directions'}->{'next'}
          and defined($output_unit->{'tree_unit_directions'}->{'next'}
                                                               ->{'unit_type'})
          and $output_unit->{'tree_unit_directions'}->{'next'}
                                                  ->{'unit_type'} eq 'unit');
    $directions->{'Back'} = $output_unit->{'tree_unit_directions'}->{'prev'}
      if ($output_unit->{'tree_unit_directions'}
          and $output_unit->{'tree_unit_directions'}->{'prev'}
          and defined($output_unit->{'tree_unit_directions'}->{'prev'}
                                                               ->{'unit_type'})
          and $output_unit->{'tree_unit_directions'}->{'prev'}
                                                     ->{'unit_type'} eq 'unit');
    my $node = _output_unit_node($output_unit);
    if (defined($node)) {
      foreach my $direction(['NodeUp', 'up'], ['NodeNext', 'next'],
                            ['NodePrev', 'prev']) {
        $directions->{$direction->[0]}
           = _label_target_unit_element(
               $node->{'extra'}->{'node_directions'}->{$direction->[1]})
            if ($node->{'extra'}->{'node_directions'}
                and $node->{'extra'}->{'node_directions'}->{$direction->[1]});
      }
      # Now do NodeForward which is something like the following node.
      my $associated_section;
      my $automatic_directions
        = (not ($node->{'args'} and scalar(@{$node->{'args'}}) > 1));
      if ($automatic_directions and $node->{'extra'}
          and $node->{'extra'}->{'associated_section'}) {
        $associated_section = $node->{'extra'}->{'associated_section'};
      }
      my $menu_child = Texinfo::ManipulateTree::first_menu_node($node,
                                                    $identifier_target);
      if ($menu_child) {
        $directions->{'NodeForward'}
          = _label_target_unit_element($menu_child);
      } elsif ($associated_section
               and $associated_section->{'extra'}->{'section_childs'}
               and $associated_section->{'extra'}->{'section_childs'}->[0]) {
        $directions->{'NodeForward'}
          = $associated_section->{'extra'}
                  ->{'section_childs'}->[0]->{'associated_unit'};
      } elsif ($node->{'extra'}->{'node_directions'}
               and $node->{'extra'}->{'node_directions'}->{'next'}) {
        $directions->{'NodeForward'}
            = _label_target_unit_element(
                  $node->{'extra'}->{'node_directions'}->{'next'});
      } elsif ($node->{'extra'}->{'node_directions'}
               and $node->{'extra'}->{'node_directions'}->{'up'}) {
        my $up = $node->{'extra'}->{'node_directions'}->{'up'};
        my @up_list = ($node);
        # the condition with the up_list avoids infinite loops
        # the last condition stops when the Top node is reached.
        while (not (grep {$up eq $_} @up_list
                    or ($node_top and $up eq $node_top))) {
          if ($up->{'extra'}->{'node_directions'}
              and defined($up->{'extra'}->{'node_directions'}->{'next'})) {
            $directions->{'NodeForward'}
              = _label_target_unit_element(
                           $up->{'extra'}->{'node_directions'}->{'next'});
            last;
          }
          push @up_list, $up;
          last if (not $up->{'extra'}->{'node_directions'}
                   or not $up->{'extra'}->{'node_directions'}->{'up'});
          $up = $up->{'extra'}->{'node_directions'}->{'up'};
        }
      }

      if ($directions->{'NodeForward'}
          and $directions->{'NodeForward'}->{'unit_type'} eq 'unit'
          and (!$directions->{'NodeForward'}->{'directions'}
               or !$directions->{'NodeForward'}->{'directions'}
                                                  ->{'NodeBack'})) {
        $directions->{'NodeForward'}->{'directions'} = {}
            if (! $directions->{'NodeForward'}->{'directions'});
        $directions->{'NodeForward'}->{'directions'}
                                       ->{'NodeBack'} = $output_unit;
      }
    }
    my $section = _output_unit_section($output_unit);
    if (not defined($section)) {
      # If there is no associated section, find the previous element section.
      # Use the FastForward of this element.
      # Use it as FastBack if the section is top level, or use the FastBack.
      my $section_output_unit;
      my $current_unit = $output_unit;
      while ($current_unit->{'tree_unit_directions'}
             and $current_unit->{'tree_unit_directions'}->{'prev'}) {
        $current_unit = $current_unit->{'tree_unit_directions'}->{'prev'};
        $section = _output_unit_section($current_unit);
        if (defined($section)) {
          $section_output_unit = $current_unit;
          last;
        }
      }
      if ($section_output_unit) {
        if ($section_output_unit->{'directions'}->{'FastForward'}) {
          $directions->{'FastForward'}
            = $section_output_unit->{'directions'}->{'FastForward'};
        }
        if ($section->{'extra'}->{'section_level'} <= 1) {
          $directions->{'FastBack'} = $section_output_unit;
        } elsif ($section_output_unit->{'directions'}->{'FastBack'}) {
          $directions->{'FastBack'}
            = $section_output_unit->{'directions'}->{'FastBack'};
        }
      }
    } else {
      foreach my $direction(['Up', 'up'], ['Next', 'next'],
                            ['Prev', 'prev']) {
        # in most cases $section->{'extra'}->{'section_directions'}
        #          ->{$direction->[1]}
        #                 ->{'associated_unit'} is defined
        # but it may not be the case for the up of @top.
        # The section may be its own up in cases like
        #  @part part
        #  @chapter chapter
        # in that cas the direction is not set up
        $directions->{$direction->[0]}
         = $section->{'extra'}->{'section_directions'}->{$direction->[1]}
             ->{'associated_unit'}
          if ($section->{'extra'}->{'section_directions'}
           and $section->{'extra'}->{'section_directions'}->{$direction->[1]}
           and $section->{'extra'}->{'section_directions'}->{$direction->[1]}
                                           ->{'associated_unit'}
           and (!$section->{'associated_unit'}
                or $section->{'extra'}->{'section_directions'}->{$direction->[1]}
                    ->{'associated_unit'}
                       ne $section->{'associated_unit'}));
      }

      # fastforward is the next element on same level than the upper parent
      # element.
      my $up = $section;
      while ($up->{'extra'}
             and defined($up->{'extra'}->{'section_level'})
             and $up->{'extra'}->{'section_level'} > 1
             and $up->{'extra'}->{'section_directions'}
             and $up->{'extra'}->{'section_directions'}->{'up'}) {
        $up = $up->{'extra'}->{'section_directions'}->{'up'};
      }

      if ($up->{'extra'}
          and defined($up->{'extra'}->{'section_level'})
          and $up->{'extra'}->{'section_level'} < 1
          and $up->{'cmdname'} and $up->{'cmdname'} eq 'top'
          and $up->{'extra'}->{'section_childs'}
          and @{$up->{'extra'}->{'section_childs'}}) {
        $directions->{'FastForward'}
           = $up->{'extra'}->{'section_childs'}->[0]->{'associated_unit'};
      } elsif ($up->{'extra'}->{'toplevel_directions'}
               and $up->{'extra'}->{'toplevel_directions'}->{'next'}) {
        $directions->{'FastForward'}
          = $up->{'extra'}->{'toplevel_directions'}->{'next'}
                                 ->{'associated_unit'};
      } elsif ($up->{'extra'}->{'section_directions'}
               and $up->{'extra'}->{'section_directions'}->{'next'}) {
        $directions->{'FastForward'}
          = $up->{'extra'}->{'section_directions'}->{'next'}
                              ->{'associated_unit'};
      }
      # if the element isn't at the highest level, fastback is the
      # highest parent element
      if ($up and $up ne $section
          and $up->{'associated_unit'}) {
        $directions->{'FastBack'} = $up->{'associated_unit'};
      } elsif ($section->{'extra'}
               and defined($section->{'extra'}->{'section_level'})
               and $section->{'extra'}->{'section_level'} <= 1
               and $directions->{'FastForward'}) {
        # the element is a top level element, we adjust the next
        # toplevel element fastback
        $directions->{'FastForward'}->{'directions'} = {}
           if (! $directions->{'FastForward'}->{'directions'});
        $directions->{'FastForward'}->{'directions'}->{'FastBack'}
          = $output_unit;
      }
    }
    if ($output_unit->{'directions'}) {
      %{$output_unit->{'directions'}}
        = (%{$output_unit->{'directions'}}, %$directions);
    } else {
      $output_unit->{'directions'} = $directions;
    }
  }
  if ($print_debug) {
    foreach my $output_unit (@$output_units) {
      print STDERR 'Directions'
       # uncomment to show the perl object name
       #  . "($output_unit)"
         . ': '.print_output_unit_directions($output_unit)."\n";
    }
  }
}

sub units_file_directions($)
{
  my $output_units = shift;
  return if (!$output_units or !@$output_units);

  my $current_filename;
  my $first_unit_in_file;
  # need to gather the directions before the FirstInFile* directions
  # are added to the first element in the file.
  my @first_unit_in_file_directions;
  foreach my $output_unit (@$output_units) {
    if (defined($output_unit->{'unit_filename'})) {
      my $filename = $output_unit->{'unit_filename'};
      my $current_output_unit = $output_unit;
      if (not defined($current_filename)
          or $filename ne $current_filename) {
        $first_unit_in_file = $output_unit;
        @first_unit_in_file_directions
            = keys %{$output_unit->{'directions'}};
        $current_filename = $filename;
      }
      while ($current_output_unit->{'tree_unit_directions'}
             and $current_output_unit->{'tree_unit_directions'}->{'prev'}) {
        $current_output_unit
          = $current_output_unit->{'tree_unit_directions'}->{'prev'};
        if (defined($current_output_unit->{'unit_filename'})) {
          if ($current_output_unit->{'unit_filename'} ne $filename) {
            $output_unit->{'directions'}->{'PrevFile'}
                 = $current_output_unit;
            last;
          }
        } else {
          last;
        }
      }
      $current_output_unit = $output_unit;
      while ($current_output_unit->{'tree_unit_directions'}
             and $current_output_unit->{'tree_unit_directions'}->{'next'}) {
        $current_output_unit
          = $current_output_unit->{'tree_unit_directions'}->{'next'};
        if (defined($current_output_unit->{'unit_filename'})) {
          if ($current_output_unit->{'unit_filename'} ne $filename) {
            $output_unit->{'directions'}->{'NextFile'}
               = $current_output_unit;
            last;
          }
        } else {
          last;
        }
      }
    }
    # set the directions of the first elements in file, to
    # be used in footers for example
    if (defined($first_unit_in_file)) {
      foreach my $first_in_file_direction
                (@first_unit_in_file_directions) {
        $output_unit->{'directions'}
                                ->{'FirstInFile'.$first_in_file_direction}
          = $first_unit_in_file->{'directions'}
                                         ->{$first_in_file_direction};
      }
    }
  }
}

# used in debug messages
sub output_unit_texi($)
{
  my $output_unit = shift;
  if (!$output_unit) {
    return "UNDEF OUTPUT UNIT";
  }
  if (!defined($output_unit->{'unit_type'})) {
    # show the output_unit as element, as a possible bug is that
    # an element was passed in argument instead of an output unit
    return "unit $output_unit without type: ".
       Texinfo::Common::debug_print_element_details($output_unit, 1)
      .' '.Texinfo::Common::debug_print_output_unit($output_unit);
  }

  my $unit_command = $output_unit->{'unit_command'};

  if ($output_unit->{'unit_type'} eq 'external_node_unit') {
    return "_EXT_NODE: ".Texinfo::Convert::Texinfo::convert_to_texinfo(
                            {'contents' => $unit_command->{'contents'}});
  } elsif ($output_unit->{'unit_type'} eq 'special_unit') {
    return "_SPECIAL_UNIT: $output_unit->{'special_unit_variety'}";
  }

  if (!$unit_command) {
    # happens when there are only nodes and sections are used as elements
    return "No associated command (type $output_unit->{'unit_type'})";
  }
  return Texinfo::Convert::Texinfo::root_heading_command_to_texinfo(
                                                          $unit_command);
}

my $direction_orders = Texinfo::HTMLData::get_directions_order();
# 'global', 'relative', 'file'
my @relative_directions_order = @{$direction_orders->[1]};
my @file_directions_order = @{$direction_orders->[2]};
my @all_directions_order
    = (@relative_directions_order, @file_directions_order,
       map {'FirstInFile'.$_} @relative_directions_order);

# Used for debugging and in test suite, but not generally useful. Not
# documented in pod section and not exportable as it should not, in
# general, be used.
sub print_output_unit_directions($)
{
  my $output_unit = shift;
  my $result = 'output unit: '.output_unit_texi($output_unit)."\n";

  if ($output_unit->{'directions'}) {
    #foreach my $direction (sort(keys(%{$output_unit->{'directions'}}))) {
    foreach my $direction (@all_directions_order) {
      if (defined($output_unit->{'directions'}->{$direction})) {
        $result .= "  $direction: ".
         output_unit_texi($output_unit->{'directions'}->{$direction})."\n";
      }
    }
  } else {
    $result .= "  NO DIRECTION\n";
  }
  return $result;
}

1;

__END__

=head1 NAME

Texinfo::OutputUnits - setup and manage Texinfo document output units

=head1 SYNOPSIS

  use Texinfo::OutputUnits qw(split_by_node split_by_section split_pages
    units_directions units_file_directions);

  # $document is a parsed Texinfo::Document document.
  # When customization variables information is needed, it is obtained
  # from the $document by calling the get_conf() method.
  my $identifier_target = $document->labels_information();
  my $output_units;
  if ($split_at_nodes) {
    $output_units = split_by_node($document);
  } else {
    $output_units = split_by_section($document);
  }
  split_pages($output_units, $split);
  units_directions($identifier_target, $output_units,
                   $document->get_conf('DEBUG'));
  units_file_directions($output_units);

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

You can convert a Texinfo parsed document to an output format in a Converter
code by first splitting the nodes and sectioning commands in units and then
converting those units.  We will call the main unit of output documents an
I<output unit>.  Usually a node is associated with a following sectioning
command, while a sectioning command is associated with a previous node; they
both together make up the output unit.  Either the node or the sectioning
command is considered to be the main element component.

The module provides methods to setup output units associated with
node and sectioning commands of a Texinfo parsed document. With
C<split_by_node> nodes are used as the main component for the separation of
output units, while with C<split_by_section> the sectioning command elements
are used to separate output units.  The first mode is typical of Info format,
while the second corresponds better to a traditional book.  Note that the
result is different when there are unassociated sectioning commands or nodes,
in the usual case of each node being associated with a sectioning command and
each sectioning command being associated with a node, splitting by node or by
section does not make much difference as each output unit will consist of the
node and the associated section in both cases.

Output units are used for conversion to HTML and Info output formats.  See
L<< C<Texinfo::Convert::Converter::convert_output_unit>|Texinfo::Convert::Converter/$result = $converter->convert_output_unit($output_unit) >>
for more information on conversion of output units in Converters.  Output units
are not relevant for all the formats, the Texinfo tree can also be converted
directly, see L<< C<Texinfo::Convert::Converter::output_tree>|Texinfo::Convert::Converter/$result = $converter->output_tree($document) >>.

The output units may be further grouped in I<pages>, which are not pages as
in book pages, but more like web pages, and hold series of output units.
The output units may have directions to other output units prepared
by C<units_directions>.  C<units_file_directions> should also
set direction related to files, provided files are associated with
output units by the user.

=head1 METHODS

No method is exported in the default case.

=head2 Output units creation

Output units are hash references created with the following keys:

=over

=item C<type>

The type of the output unit.  Set to C<unit> for output units associated
with nodes and sectioning commands.

=item C<unit_command>

Main node or sectioning command associated with the output unit.

=item C<unit_contents>

This array reference holds all the nodes and sectioning commands Texinfo tree
elements associated with the output unit (in order).  The Texinfo tree nodes
and sectioning commands elements have an C<associated_unit> key set that points
to the output unit.

=item C<tree_unit_directions>

Hash reference with I<next> and I<prev> pointing to the
previous and the next output unit.

=back

Call one of the following methods to create output units and associate them
with nodes and sectioning command Texinfo tree elements:

=over

=item $output_units = split_by_node($document)
X<C<split_by_node>>

Returns a reference array of output units where a node is associated with
the following sectioning commands.  Sectioning commands without nodes
are also with the previous node, while nodes without sectioning commands
are alone in their output units.

Each output unit I<unit_command> key points to the node command
associated with the output unit.

=item $output_units = split_by_section($document)
X<C<split_by_section>>

Similarly with C<split_by_node>, returns an array of output units.  This
time, lone nodes are associated with the previous sections and lone
sections makes up an output unit.

Output units I<unit_command> keys point to the sectioning command associated
with the output unit.

=back

=head2 Grouping output units in pages

You can call C<split_pages> to group together output units:

=over

=item split_pages($output_units, $split)
X<C<split_pages>>

Add the I<first_in_page> key to each output unit in the array
reference argument I<$output_units>, set to the first output unit in the group.

The first output unit in the group is based on the value of I<$split>:

=over

=item C<chapter>

The output units are grouped at chapter or other toplevel sectioning commands.

=item C<node>

Each output unit is on its own.

=item C<section>

The output units are grouped at sectioning commands below chapter.

=item empty string

No splitting, all the output units are together.

=back

=back

=head2 Setting output units directions

You can call the following methods to set output units directions:

=over

=item units_directions($identifier_target, $output_units, $print_debug)
X<C<units_directions>>

The I<$identifier_target> argument associates identifiers with target elements
and is generally obtained from a parsed document,
L<< C<Texinfo::Document::labels_information>|Texinfo::Document/$identifier_target = labels_information($document) >>.
Directions are set up for the output units in the array reference
I<$output_units> given in argument. The corresponding hash is associated
with the I<directions> key. In this hash, keys correspond to directions
while values are output units.

I<$print_debug> is optional.  If set, some debugging information is printed.

The following directions are set up:

=over

=item This

The output unit itself.

=item Forward

Unit next.

=item Back

Previous output unit.

=item NodeForward

Following node output unit in reading order.  It is the next node unit, or the
first in menu or the next of the up node.

=item NodeBack

Preceding node output unit.

=item NodeUp

=item NodeNext

=item NodePrev

The up, next and previous node output unit.

=item Up

=item Next

=item Prev

The up, next and previous section output unit.

=item FastBack

For top level output units, the previous top level output unit.  For other
output units the up top level unit.  For example, for a chapter output unit it
is the previous chapter output unit, for a subsection output unit it is the
chapter output unit that contains the subsection.

=item FastForward

The next top level output unit.

=back

=item units_file_directions($output_units)
X<C<units_file_directions>>

In the directions reference described above for C<units_directions>,
sets the I<PrevFile> and I<NextFile> directions to the output units in
previous and following files.

It also sets I<FirstInFile*> directions for all the output units by using
the directions of the first output unit in file.  So, for example,
I<FirstInFileNodeNext> is the output unit associated with the next node
of the first output unit node in the file for each output unit in the file.

The API for association of pages/output units to files is not defined yet.

=back

=head1 SEE ALSO

L<Texinfo manual|http://www.gnu.org/s/texinfo/manual/texinfo/>,
L<Texinfo::Document>, L<Texinfo::Convert::Converter>.

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

