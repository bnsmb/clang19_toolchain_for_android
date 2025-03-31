# -*-perl-*-
#+##############################################################################
#
# html32.pm: output HTML 3.2
#
# Copyright 2003, 2004, 2007, 2009, 2011-2024 Free Software Foundation, Inc.
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
# Originally written by Patrice Dumas.
#
#-##############################################################################
#
# TODO there are id attributes in many places in the default HTML output
# that should be replaced with <a name=...></a> to be compliant with HTML3.2.
# HTML3.2 is not very interesting as an output format, this file is mostly
# a check that the API allows to output different variants of HTML.  Therefore
# it is not high priority to fix those cases, especially if it means copying
# a lot of code to replace id= with a separate anchor without changing anything
# else.

use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Texinfo::Commands;

use Texinfo::Common;


texinfo_set_from_init_file('INDENTED_BLOCK_COMMANDS_IN_TABLE', 1);

texinfo_set_from_init_file('DOCTYPE', '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 3.2//EN" "http://www.w3.org/TR/html32/loose.dtd">');

texinfo_set_from_init_file('BODY_ELEMENT_ATTRIBUTES',
  'bgcolor="#FFFFFF" text="#000000" link="#0000FF" vlink="#800080" alink="#FF0000"');

texinfo_set_from_init_file('BEFORE_SHORT_TOC_LINES', '');
texinfo_set_from_init_file('AFTER_SHORT_TOC_LINES', '');
texinfo_set_from_init_file('BEFORE_TOC_LINES', '');
texinfo_set_from_init_file('AFTER_TOC_LINES', '');

# html version for latex2html
texinfo_set_from_init_file('L2H_HTML_VERSION', '3.2');

# no css, no class
texinfo_set_from_init_file('NO_CSS', 1);
texinfo_set_from_init_file('COPIABLE_LINKS', 0);
texinfo_set_from_init_file('NO_CUSTOM_HTML_ATTRIBUTE', 1);

# no accesskey in html 3.2
texinfo_set_from_init_file('USE_ACCESSKEY', 0);

texinfo_set_from_init_file('MENU_SYMBOL', '*');

texinfo_set_from_init_file('OPEN_QUOTE_SYMBOL', '`');
texinfo_set_from_init_file('CLOSE_QUOTE_SYMBOL', "'");


# &quot; is not in html 3.2
sub html32_format_protect_text($$)
{
  my $converter = shift;
  my $text = shift;
  $text =~ s/&/&amp;/g;
  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;
  $text =~ s/\"/&#34;/g;
  $text =~ s/\f/&#12;/g;
  return $text;
}

texinfo_register_formatting_function('format_protect_text', \&html32_format_protect_text);


foreach my $command ('euro', 'geq', 'leq',
   'bullet', 'equiv', 'expansion', 'minus', 'point', 'result', 'arrow',
   'quotedblleft', 'quotedblright',
   'quoteleft', 'quoteright',
   'quotedblbase', 'quotesinglbase', 'guillemetleft', 'guillemetright',
   'guillemotleft', 'guillemotright', 'guilsinglleft', 'guilsinglright') {
  my $formatted_command = html32_format_protect_text(undef,
             $Texinfo::Common::text_brace_no_arg_commands{$command});
  texinfo_register_no_arg_command_formatting($command, undef, $formatted_command);
}

texinfo_register_no_arg_command_formatting('oe', undef, '&#156;');
texinfo_register_no_arg_command_formatting('OE', undef, '&#140;');

foreach my $dots ('dots') {
  texinfo_register_no_arg_command_formatting($dots, undef, '...', 'small');
  texinfo_register_no_arg_command_formatting($dots, 'preformatted', '...');
}

foreach my $context ('preformatted', 'normal') {
  foreach my $command('sansserif', 'r') {
    texinfo_register_style_command_formatting($command, undef, undef, $context);
  }
  texinfo_register_style_command_formatting('t', 'tt', undef, $context);
}

# no inodot in HTML3.2
texinfo_register_accent_command_formatting('dotless', '', '');


# reset BIG_RULE to HTML3.2 compatible rule if in TEXI2HTML mode
texinfo_register_handler('setup', \&html32_setup);

sub html32_setup($)
{
  my $self = shift;
  if (defined($self->get_conf('TEXI2HTML'))) {
    $self->set_conf('BIG_RULE', '<hr size="6">');
  }
  return 0;
}


sub html32_format_separate_anchor($$;$)
{
  my $self = shift;
  my $id = shift;
  my $class = shift;

  # note that the classes argument will be ignored with NO_CSS
  return $self->html_attribute_class('a', [$class])." name=\"$id\"></a>";
}

texinfo_register_formatting_function('format_separate_anchor', \&html32_format_separate_anchor);

sub html32_convert_text($$$$)
{
  my $self = shift;
  my $type = shift;
  my $element = shift;
  my $text = shift;

  # do that first because in verb and verbatim, type is 'raw'
  if ($self->in_verbatim()) {
    return &{$self->formatting_function('format_protect_text')}($self, $text);
  }
  return $text if ($self->in_raw());

  $text = uc($text) if ($self->in_upper_case());
  $text = &{$self->formatting_function('format_protect_text')}($self, $text);

  if (!$self->in_code() and !$self->in_math()) {
    $text =~ s/``/&#34;/g;
    $text =~ s/''/&#34;/g;
    $text =~ s/---/\x{1F}/g;
    $text =~ s/--/-/g;
    $text =~ s/\x{1F}/--/g;
  }
  if (!$self->in_preformatted_context()
      and ($self->in_non_breakable_space()
             or $self->in_space_protected())) {
    $text .= '&nbsp;' if (chomp($text));
    $text =~ s/ /&nbsp;/g;
  }
  return $text;
}
texinfo_register_type_formatting('text', \&html32_convert_text);

sub html32_convert_explained_command($$$$)
{
  my $self = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;

  my $with_explanation;

  return '' if (!$args or !$args->[0]
                or $args->[0]->{'normal'} !~ /\S/);

  if ($args->[1] and $args->[1]->{'string'} =~ /\S/) {
    $with_explanation = 1;
  }

  my $result;
  if ($with_explanation) {
    $result = $self->convert_tree($self->cdt('{explained_string} ({explanation})',
          {'explained_string' => $args->[0]->{'arg_tree'},
           'explanation' => $args->[1]->{'arg_tree'} }));
  } else {
    $result = $args->[0]->{'normal'};
  }
  return $result;
}

foreach my $explained_command (keys(%Texinfo::Commands::explained_commands)) {
  texinfo_register_command_formatting($explained_command,
                              \&html32_convert_explained_command);
}

# row in multitable. no thead/tbody in html 3.2
sub html32_convert_multitable_head_type($$$$) {
  my $self = shift;
  my $type = shift;
  my $element = shift;
  my $content = shift;

  $content = '' if (!defined($content));

  return $content if ($self->in_string());
  if ($content =~ /\S/) {
    return $content . "\n";
  } else {
    return '';
  }
}
texinfo_register_type_formatting('multitable_head', \&html32_convert_multitable_head_type);

sub html32_convert_multitable_body_type($$$$) {
  my $self = shift;
  my $type = shift;
  my $element = shift;
  my $content = shift;

  $content = '' if (!defined($content));

  return $content if ($self->in_string());
  if ($content =~ /\S/) {
    return $content;
  } else {
    return '';
  }
}
texinfo_register_type_formatting('multitable_body', \&html32_convert_multitable_body_type);

sub html32_convert_itemize_command($$$$$)
{
  my $self = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;
  my $content = shift;

  $content = '' if (!defined($content));

  if ($self->in_string()) {
    return $content;
  }

  return "<ul>\n" . $content. "</ul>\n";
}

texinfo_register_command_formatting('itemize', \&html32_convert_itemize_command);

sub html32_convert_tab_command($$$$$)
{
  my $self = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;
  my $content = shift;

  $content = '' if (!defined($content));

  $content =~ s/^\s*//;
  $content =~ s/\s*$//;

  if ($self->in_string()) {
    return $content;
  }

  my $row = $command->{'parent'};
  my $row_cmdname = $row->{'contents'}->[0]->{'cmdname'};

  if ($row_cmdname eq 'headitem') {
    return "<th>" . $content . '</th>';
  } else {
    return "<td>" . $content . '</td>';
  }
}
texinfo_register_command_formatting('tab',
                            \&html32_convert_tab_command);

sub html32_convert_item_command($$$$$)
{
  my $self = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;
  my $content = shift;

  $content = '' if (!defined($content));

  if ($self->in_string()) {
    return $content;
  }
  if ($command->{'parent'}->{'type'}
      and $command->{'parent'}->{'type'} eq 'row') {
    return &{$self->command_conversion('tab')}($self, $cmdname, $command,
                                                           $args, $content);
  } elsif ($command->{'parent'}->{'cmdname'}
      and $command->{'parent'}->{'cmdname'} eq 'itemize') {
    my $prepend ;
    my $itemize = $command->{'parent'};
    if ($itemize->{'extra'} and $itemize->{'extra'}->{'command_as_argument'}
       and $itemize->{'extra'}->{'command_as_argument'}->{'cmdname'} eq 'bullet') {
      $prepend = '';
    } else {
      # Setting multiple expansion should not be needed, except in
      # case of invalid constructs
      $prepend = $self->convert_tree_new_formatting_context(
        $itemize->{'args'}->[0],
        $command->{'cmdname'}, 'item_prepended');
    }
    if ($content =~ /\S/) {
      return '<li>' . $prepend .' '. $content . '</li>';
    } else {
      return '';
    }
  } else {
    return &{$self->default_command_conversion($cmdname)}($self, $cmdname,
                                                $command, $args, $content);
  }
}

texinfo_register_command_formatting('item',
                            \&html32_convert_item_command);
texinfo_register_command_formatting('headitem',
                            \&html32_convert_item_command);

sub html32_convert_center_command($$$$)
{
  my $self = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;

  if (!$args or !$args->[0]) {
    return '';
  }

  if ($self->in_string()) {
    return $args->[0]->{'normal'}."\n";
  } else {
    return '<div align="center">'.$args->[0]->{'normal'}."\n</div>";
  }
}

texinfo_register_command_formatting('center',
                            \&html32_convert_center_command);


my %html32_paragraph_style = (
      'center'     => 'center',
      'flushleft'  => 'left',
      'flushright' => 'right',
      );

sub html32_convert_paragraph_type($$$$)
{
  my $self = shift;
  my $type = shift;
  my $element = shift;
  my $content = shift;

  $content = '' if (!defined($content));

  $content = $self->get_associated_formatted_inline_content($element).$content;

  if ($self->paragraph_number() == 1) {
    my $in_format = $self->top_block_command();
    if ($in_format) {
      # no first paragraph in those environment to avoid extra spacing
      if ($in_format eq 'itemize'
          or $in_format eq 'enumerate'
          or $in_format eq 'multitable') {
        return $content;
      }
    }
  }
  return $content if ($self->in_string());

  if ($content =~ /\S/) {
    my $align = $self->in_align();
    if ($align and $html32_paragraph_style{$align}) {
      return "<p align=\"$html32_paragraph_style{$align}\">".$content."</p>";
    } else {
      return "<p>".$content."</p>";
    }
  } else {
    return '';
  }
}

texinfo_register_type_formatting('paragraph', \&html32_convert_paragraph_type);


sub html32_convert_subtitle_command($$$$)
{
  my $self = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;

  return '' if (!$args or !$args->[0]);

  if (!$self->in_string()) {
    return "<h3 align=\"right\">$args->[0]->{'normal'}</h3>\n";
  } else {
    return $args->[0]->{'normal'};
  }
}

texinfo_register_command_formatting('subtitle',
                            \&html32_convert_subtitle_command);


1;
