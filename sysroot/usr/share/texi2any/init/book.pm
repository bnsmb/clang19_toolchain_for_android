# A style that tries to be analogous with a book, in HTML.
#
# Copyright 2004-2024 Free Software Foundation, Inc.
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
# Originally written by Patrice Dumas in 2004.
#
# This style is based on the scriptbasic style.

use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

#use Carp qw(cluck);

use Texinfo::Commands;
use Texinfo::Common;
use Texinfo::Convert::Texinfo;
# for section_level_adjusted_command_name
use Texinfo::Structuring;

my %sectioning_heading_commands = %Texinfo::Commands::sectioning_heading_commands;

texinfo_set_from_init_file('contents', 1);
texinfo_set_from_init_file('CONTENTS_OUTPUT_LOCATION', 'inline');
texinfo_set_from_init_file('NO_TOP_NODE_OUTPUT', 1);

# Following Rudolf Adamkovič idea, have Contents button for regular output
# units link to the section in table of contents.
sub book_in_contents_button {
  my ($self, $direction, $element) = @_;

  if ($element->{'extra'}->{'associated_section'}) {
    $element = $element->{'extra'}->{'associated_section'};
  }

  my $href = $self->command_contents_href($element, 'contents');

  # Call direction_string to have Contents translated.
  return ("[<a href=\"$href\">".
           $self->direction_string('Contents', 'text')."</a>]", 0);
}

my @book_contents_buttons = ('Back', 'Forward', ' ', 'Contents', 'Index', 'About');

foreach my $buttons ('TOP_BUTTONS') {
  texinfo_set_from_init_file($buttons, \@book_contents_buttons);
}

my @book_output_unit_buttons = ('Back', 'Forward', ' ',
                                ['This', \&book_in_contents_button],
                                'Index', 'About');

foreach my $buttons ('SECTION_BUTTONS', 'CHAPTER_BUTTONS') {
  texinfo_set_from_init_file($buttons, \@book_output_unit_buttons);
}

my @book_footer_buttons = ('Contents', 'Index', 'About');
foreach my $buttons ('MISC_BUTTONS', 'SECTION_FOOTER_BUTTONS',
                     'CHAPTER_FOOTER_BUTTONS', 'TOP_FOOTER_BUTTONS') {
  texinfo_set_from_init_file($buttons, \@book_footer_buttons);
}

texinfo_set_from_init_file('NODE_FOOTER_BUTTONS', ['Back', 'Forward']);
texinfo_set_from_init_file('LINKS_BUTTONS',
    ['Top', 'Index', 'Contents', 'About', 'Up', 'NextFile', 'PrevFile']);

texinfo_set_from_init_file('WORDS_IN_PAGE', undef);
texinfo_set_from_init_file('FORMAT_MENU', 'nomenu');
texinfo_set_from_init_file('USE_NODES', 0);

texinfo_set_from_init_file('BIG_RULE', '<hr>');

my $toc_numbered_mark_class = 'toc-numbered-mark';

my ($book_previous_default_filename, $book_previous_file_name,
    $book_unumbered_nr);

sub book_init($)
{
  my $converter = shift;

  $book_previous_default_filename = undef;
  $book_previous_file_name = undef;
  $book_unumbered_nr = 0;
  return 0;
}

texinfo_register_handler('init', \&book_init);

sub book_print_up_toc($$)
{
  my $converter = shift;
  my $command = shift;

  my $result = '';
  my $current_command = $command;
  my @up_commands;
  while ($current_command->{'extra'}->{'section_directions'}
         and defined($current_command->{'extra'}->{'section_directions'}->{'up'})
         and ($current_command->{'extra'}->{'section_directions'}->{'up'}
                                                           ne $current_command)
         and defined($current_command->{'extra'}->{'section_directions'}->{'up'}
                                                                ->{'cmdname'})) {
    unshift (@up_commands,
                $current_command->{'extra'}->{'section_directions'}->{'up'});
    $current_command = $current_command->{'extra'}->{'section_directions'}->{'up'};
  }
  # this happens for example for top tree unit
  return '' if !(@up_commands);
  my $up = shift @up_commands;
  #print STDERR "$up ".Texinfo::Convert::Texinfo::root_heading_command_to_texinfo($up)."\n";
  $result .= $converter->html_attribute_class('ul', [$toc_numbered_mark_class])."><li>"
  . "<a href=\"".$converter->command_href($up)."\">".$converter->command_text($up)
   . "</a> </li>\n";
  foreach my $up (@up_commands) {
    $result .= '<li>'
    .$converter->html_attribute_class('ul', [$toc_numbered_mark_class])."><li>"
    . "<a href=\"".$converter->command_href($up)."\">".$converter->command_text($up)
   . "</a> </li>\n";
  }
  foreach my $up (@up_commands) {
    $result .= "</ul></li>\n";
  }
  $result .= "</ul>\n";
  return $result;
}

sub book_format_navigation_header($$$$)
{
  my $self = shift;
  my $buttons = shift;
  my $cmdname = shift;
  my $element = shift;

  my $output_unit = $element->{'associated_unit'};
  if ($output_unit and $output_unit->{'unit_command'}
      and not $output_unit->{'unit_command'}->{'cmdname'} eq 'node'
      and ($output_unit->{'unit_contents'}->[0] eq $element
          or (!$output_unit->{'unit_contents'}->[0]->{'cmdname'}
              and $output_unit->{'unit_contents'}->[1] eq $element))
      and defined($output_unit->{'unit_filename'})
      and $self->count_elements_in_filename('current',
                         $output_unit->{'unit_filename'}) == 1) {
    return book_print_up_toc($self, $output_unit->{'unit_command'}) .
       &{$self->default_formatting_function('format_navigation_header')}($self,
                                 $buttons, $cmdname, $element);

  } else {
    return &{$self->default_formatting_function('format_navigation_header')}(
                                          $self, $buttons, $cmdname, $element);
  }
}

texinfo_register_formatting_function('format_navigation_header',
                                     \&book_format_navigation_header);

sub book_print_sub_toc($$$);

sub book_print_sub_toc($$$)
{
  my $converter = shift;
  my $parent_command = shift;
  my $command = shift;

  my $result = '';
  my $content_href = $converter->command_href($command);
  my $heading = $converter->command_text($command);
  if ($content_href) {
    $result .= "<li> "."<a href=\"$content_href\">$heading</a>" . " </li>\n";
  }
  if ($command->{'extra'}->{'section_childs'}
      and @{$command->{'extra'}->{'section_childs'}}) {
    $result .= '<li>'.$converter->html_attribute_class('ul', [$toc_numbered_mark_class])
     .">\n". book_print_sub_toc($converter, $parent_command,
                                $command->{'extra'}->{'section_childs'}->[0])
     ."</ul></li>\n";
  }
  if ($command->{'extra'}->{'section_directions'}
      and exists($command->{'extra'}->{'section_directions'}->{'next'})) {
    $result .= book_print_sub_toc($converter, $parent_command,
                  $command->{'extra'}->{'section_directions'}->{'next'});
  }
  return $result;
}

# this function is very similar with the default function, but there is
# an additional sub toc before the content.  It should be synced with
# the default function.
sub book_convert_heading_command($$$$$)
{
  my $self = shift;
  my $cmdname = shift;
  my $element = shift;
  my $args = shift;
  my $content = shift;

  my $result = '';

  # No situation where this could happen
  if ($self->in_string()) {
    $result .= $self->command_text($element, 'string') ."\n"
      if ($cmdname ne 'node');
    $result .= $content if (defined($content));
    return $result;
  }

  my $element_id = $self->command_id($element);

  print STDERR "CONVERT elt heading "
        # uncomment next line for the perl object name
        #."$element "
        .Texinfo::Convert::Texinfo::root_heading_command_to_texinfo($element)."\n"
          if ($self->get_conf('DEBUG'));
  my $output_unit;
  # All the root commands are associated to an output unit, the condition
  # on associated_unit is always true.
  if ($Texinfo::Commands::root_commands{$element->{'cmdname'}}
      and $element->{'associated_unit'}) {
    $output_unit = $element->{'associated_unit'};
  }
  my $element_header = '';
  if ($output_unit) {
    $element_header = &{$self->formatting_function('format_element_header')}(
                                        $self, $cmdname, $element, $output_unit);
  }

  my $document = $self->get_info('document');
  my $sections_list;
  if ($document) {
    $sections_list = $document->sections_list();
  }

  my $toc_or_mini_toc_or_auto_menu = '';
  if ($self->get_conf('CONTENTS_OUTPUT_LOCATION') eq 'after_top'
      and $cmdname eq 'top'
      and $sections_list
      and scalar(@{$sections_list}) > 1) {
    foreach my $content_command_name ('shortcontents', 'contents') {
      if ($self->get_conf($content_command_name)) {
        my $contents_text
          = $self->_contents_inline_element($content_command_name, undef);
        if ($contents_text ne '') {
          $toc_or_mini_toc_or_auto_menu .= $contents_text;
        }
      }
    }
  }

  if ($toc_or_mini_toc_or_auto_menu eq ''
      and $element->{'extra'}
      and $element->{'extra'}->{'section_childs'}
      and scalar(@{$element->{'extra'}->{'section_childs'}})
      # avoid a double of contents if already after title
      and ($cmdname ne 'top'
           or $self->get_conf('CONTENTS_OUTPUT_LOCATION') ne 'after_title')
      and $Texinfo::Commands::sectioning_heading_commands{$cmdname}) {
    $toc_or_mini_toc_or_auto_menu
      .= $self->html_attribute_class('ul', [$toc_numbered_mark_class]).">\n";
    $toc_or_mini_toc_or_auto_menu .= book_print_sub_toc($self, $element,
                                 $element->{'extra'}->{'section_childs'}->[0]);
    $toc_or_mini_toc_or_auto_menu .= "</ul>\n";
  }

  if ($self->get_conf('NO_TOP_NODE_OUTPUT')
      and $Texinfo::Commands::root_commands{$cmdname}) {
    my $in_skipped_node_top
      = $self->get_shared_conversion_state('top', 'in_skipped_node_top');
    $in_skipped_node_top = 0 if (!defined($in_skipped_node_top));
    if ($in_skipped_node_top == 1) {
      my $id_class = $cmdname;
      $result .= &{$self->formatting_function('format_separate_anchor')}($self,
                                                        $element_id, $id_class);
      $result .= $element_header;
      $result .= $toc_or_mini_toc_or_auto_menu;
      return $result;
    }
  }

  my $level_corrected_cmdname = $cmdname;
  my $level_set_class;
  if ($element->{'extra'}
      and defined $element->{'extra'}->{'section_level'}) {
    # if the level was changed, use a consistent command name
    $level_corrected_cmdname
      = Texinfo::Structuring::section_level_adjusted_command_name($element);
    if ($level_corrected_cmdname ne $cmdname) {
      $level_set_class = "${cmdname}-level-set-${level_corrected_cmdname}";
    }
  }

  # find the section starting here, can be through the associated node
  # preceding the section, or the section itself
  my $opening_section;
  my $level_corrected_opening_section_cmdname;
  if ($cmdname eq 'node'
      and $element->{'extra'}
      and $element->{'extra'}->{'associated_section'}) {
    $opening_section = $element->{'extra'}->{'associated_section'};
    $level_corrected_opening_section_cmdname
     = Texinfo::Structuring::section_level_adjusted_command_name(
                                                             $opening_section);
  } elsif ($cmdname ne 'node'
           # if there is an associated node, it is not a section opening
           # the section was opened before when the node was encountered
           and (not $element->{'extra'}
                or not $element->{'extra'}->{'associated_node'})
           # to avoid *heading* @-commands
           and $Texinfo::Commands::root_commands{$cmdname}) {
    $opening_section = $element;
    $level_corrected_opening_section_cmdname = $level_corrected_cmdname;
  }

  # could use empty args information also, to avoid calling command_text
  #my $empty_heading = (!scalar(@$args) or !defined($args->[0]));

  # $heading not defined may happen if the command is a @node, for example
  # if there is an error in the node.
  my $heading = $self->command_text($element);
  my $heading_level;
  # node is used as heading if there is nothing else.
  if ($cmdname eq 'node') {
    # NOTE: if USE_NODES = 0 and there are no sectioning commands,
    # $output_unit->{'unit_command'} does not exist.
    if ($output_unit->{'unit_command'}
        and $output_unit->{'unit_command'} eq $element
        and $element->{'extra'}
        and not $element->{'extra'}->{'associated_section'}
        and defined($element->{'extra'}->{'normalized'})) {
      if ($element->{'extra'}->{'normalized'} eq 'Top') {
        $heading_level = 0;
      } else {
        my $use_next_heading = 0;
        if ($self->get_conf('USE_NEXT_HEADING_FOR_LONE_NODE')) {
          my $next_heading
            = Texinfo::Convert::Utils::find_root_command_next_heading_command(
                     $element, $self->get_info('expanded_formats'),
                     ($self->get_conf('CONTENTS_OUTPUT_LOCATION') eq 'inline'));
          if ($next_heading) {
            $use_next_heading = 1;
          }
        }
        if (!$use_next_heading) {
          # use node
          $heading_level = 3;
        }
      }
    }
  } elsif ($element->{'extra'}
           and defined($element->{'extra'}->{'section_level'})) {
    $heading_level = $element->{'extra'}->{'section_level'};
  } else {
    # for *heading* @-commands which do not have a level
    # in the document as they are not associated with the
    # sectioning tree, but still have a $heading_level
    $heading_level = Texinfo::Common::section_level($element);
  }

  my $do_heading = (defined($heading) and $heading ne ''
                    and defined($heading_level));

  # if set, the id is associated to the heading text
  my $heading_id;
  if ($opening_section) {
    my $level;
    if ($opening_section->{'extra'}
        and defined($opening_section->{'extra'}->{'section_level'})) {
      $level = $opening_section->{'extra'}->{'section_level'};
    } else {
      # if Structuring sectioning_structure was not called on the
      # document (cannot happen in main program or test_utils.pl tests)
      $level = Texinfo::Common::section_level($opening_section);
    }
    my $closed_strings = $self->close_registered_sections_level(
                                  $self->current_filename(), $level);
    $result .= join('', @{$closed_strings});
    $self->register_opened_section_level($self->current_filename(), $level,
                                         "</div>\n");

    # use a specific class name to mark that this is the start of
    # the section extent. It is not necessary where the section is.
    $result .= $self->html_attribute_class('div',
                 ["${level_corrected_opening_section_cmdname}-level-extent"]);
    $result .= " id=\"$element_id\""
        if (defined($element_id) and $element_id ne '');
    $result .= ">\n";
  } elsif (defined($element_id) and $element_id ne '') {
    if ($element_header ne '') {
      # case of a @node without sectioning command and with a header.
      # put the node element anchor before the header.
      # Set the class name to the command name if there is no heading,
      # else the class will be with the heading element.
      my $id_class = $cmdname;
      if ($do_heading) {
        $id_class = "${cmdname}-id";
      }
      $result .= &{$self->formatting_function('format_separate_anchor')}($self,
                                                        $element_id, $id_class);
    } else {
      $heading_id = $element_id;
    }
  }

  $result .= $element_header;

  if ($do_heading) {
    if ($self->get_conf('TOC_LINKS')
        and $Texinfo::Commands::root_commands{$cmdname}
        and $sectioning_heading_commands{$cmdname}) {
      my $content_href = $self->command_contents_href($element, 'contents');
      if (defined($content_href)) {
        $heading = "<a href=\"$content_href\">$heading</a>";
      }
    }

    my @heading_classes;
    push @heading_classes, $level_corrected_cmdname;
    if (defined($level_set_class)) {
      push @heading_classes, $level_set_class;
    }
    if ($self->in_preformatted_context()) {
      my $id_str = '';
      if (defined($heading_id)) {
        $id_str = " id=\"$heading_id\"";
      }
      $result .= $self->html_attribute_class('strong', \@heading_classes)
                                   ."${id_str}>".$heading.'</strong>'."\n";
    } else {
      $result .= &{$self->formatting_function('format_heading_text')}($self,
                     $level_corrected_cmdname, \@heading_classes, $heading,
                     $heading_level +$self->get_conf('CHAPTER_HEADER_LEVEL') -1,
                     $heading_id, $element, $element_id);
    }
  } elsif (defined($heading_id)) {
    # case of a lone node and no header, and case of an empty @top
    $result .= &{$self->formatting_function('format_separate_anchor')}($self,
                                                       $heading_id, $cmdname);
  }

  $result .= $toc_or_mini_toc_or_auto_menu;

  $result .= $content if (defined($content));

  return $result;
}

foreach my $command (keys(%Texinfo::Commands::sectioning_heading_commands),
                                                                  'node') {
  texinfo_register_command_formatting($command,
                                \&book_convert_heading_command);
}

sub book_unit_file_name($$$$)
{
  my $converter = shift;
  my $output_unit = shift;
  my $filename = shift;
  my $filepath = shift;

  return (undef, undef) if (!$converter->get_conf('SPLIT'));

  # should only happen if ! SPLIT, so should be redundant with the
  # condition above
  return ($filename, $filepath) if (defined($filepath));

  if (defined($book_previous_default_filename)
      and ($filename eq $book_previous_default_filename)) {
    return ($book_previous_file_name, undef);
  }

  my $prefix = $converter->get_info('document_name');
  my $new_file_name;
  my $command;
  if ($output_unit->{'unit_command'}) {
    if ($output_unit->{'unit_command'}->{'cmdname'} ne 'node') {
      $command = $output_unit->{'unit_command'};
    } elsif ($output_unit->{'unit_command'}->{'extra'}
             and $output_unit->{'unit_command'}->{'extra'}->{'associated_section'}) {
      $command = $output_unit->{'unit_command'}->{'extra'}->{'associated_section'};
    }
  }
  return undef unless ($command);
  if ($converter->unit_is_top_output_unit($output_unit)) {
    $new_file_name = "${prefix}_top.html";
  } elsif (defined($command->{'extra'}->{'section_number'})
           and ($command->{'extra'}->{'section_number'} ne '')) {
    my $number = $command->{'extra'}->{'section_number'};
    $number .= '.' unless ($number =~ /\.$/);
    $new_file_name = "${prefix}_$number" . 'html';
  } else {
    $book_unumbered_nr++;
    $new_file_name = "${prefix}_U." . $book_unumbered_nr . '.html';
  }
  $book_previous_default_filename = $filename;
  $book_previous_file_name = $new_file_name;
  return ($new_file_name, undef);
}

texinfo_register_file_id_setting_function('unit_file_name',
                                          \&book_unit_file_name);

1;
