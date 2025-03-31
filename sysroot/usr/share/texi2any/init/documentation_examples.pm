# API documentation code examples implemented, to check syntax
# and also expected effects.  Only for code that is not already elsewhere,
# nor is too complex to set up.  Some of those customization results
# are silly, just for the sake of checking.

use strict;

use utf8;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

texinfo_set_from_init_file('MATHJAX_CONFIGURATION',
"options: { enableMenu: false },
loader: {
load: [\'[tex]/physics\'],
versionWarnings: false
},
tex: {
packages: {\'[+]\': [\'physics\']}
}
");
texinfo_set_from_init_file('HTML_MATH', 'mathjax');

my $default_footnotestyle = texinfo_get_conf('footnotestyle');
my $main_program_footnotestyle;
if (not defined($default_footnotestyle)) {
  $main_program_footnotestyle = 'is undef';
} elsif ($default_footnotestyle eq 'separate') {
  $main_program_footnotestyle = 'is separate';
} else {
  $main_program_footnotestyle = 'not separate '.$default_footnotestyle;
}

my %translations = (
'fr' => {
'error--&gt;' => {'' => 'erreur--&gt;',},
'Higher' => {'Up direction button label' => 'Plus haut',},
'The @emph{Table of Contents}' => {'contents section heading'
              => '@result{} La @emph{Table des mati@`eres}',},
'Forward' => {'Forward direction string'
              => 'Vers l\'avant @result{}',},
# ...
},
'de' => {
'error--&gt;' => {'' => 'Fehler--&gt;',},
# ...
},
'pl' => {
'error--&gt;' => {'' => 'błąd--&gt;',},
'Higher' => {'Up direction button label' => 'Wyższy',},
# ...
},
# ...
);

texinfo_register_no_arg_command_formatting('-', undef, '&shy;');

texinfo_register_no_arg_command_formatting('error', undef, undef, undef,
                                           'error--&gt;');

texinfo_register_no_arg_command_formatting('equiv', undef, undef, undef,
                                         undef, 'is the @strong{same} as');

$translations{'fr'}->{'is the @strong{same} as'}
    = {'' => 'est la @strong{m@^eme} que',};

texinfo_register_style_command_formatting('sansserif', 'code', 0, 'normal');
texinfo_register_style_command_formatting('sansserif', 'code', 1, 'preformatted');
texinfo_register_upper_case_command('sc', 0);
texinfo_register_upper_case_command('var', 1);

texinfo_register_accent_command_formatting('dotless', 'nodot', 'ij');

texinfo_register_direction_string_info('Up', 'button', undef, 'Higher');
texinfo_register_direction_string_info('Forward', 'text', undef,
                                       'Forward');
texinfo_register_special_unit_info('heading', 'contents',
                                   'The @emph{Table of Contents}');

my $shown_styles;
my $footnotestyle;
sub my_function_set_some_css {
  my $converter = shift;
  my $all_included_rules = $converter->css_get_info('rules');
  my $all_default_selectors = $converter->css_get_info('styles');
  my $titlefont_style = $converter->css_get_selector_style('h1.titlefont');
  $titlefont_style = 'undefined' if (!defined($titlefont_style));
  $shown_styles = $titlefont_style.' '.
            $converter->css_get_selector_style('h1.shorttitlepage');
  $converter->css_set_selector_style('h1.titlefont', 'text-align:center');

  my $footnotestyle_before_setting = $converter->get_conf('footnotestyle');
  $footnotestyle_before_setting = 'UNDEF'
     if (not defined($footnotestyle_before_setting));
  $converter->set_conf('footnotestyle', 'separate');
  $footnotestyle = $main_program_footnotestyle
                    .'|'.$footnotestyle_before_setting
                    .'|'.$converter->get_conf('footnotestyle');
  # there should be nothing in @$all_included_rules for two reasons,
  # first because it requires 'CSS_FILES' to be set to parseable
  # CSS files, and CSS files parsing is done after the setup handler
  # is called.
  #print STDERR "all_included_rules: ".join('|', @$all_included_rules)."\n";

  $converter->define_shared_conversion_state ('quotation', 'color',
                                              ['string', 'integer']);
  $converter->set_shared_conversion_state('quotation', 'color',
                                          'special_black', 42);

  return 0;
}

texinfo_register_handler('setup', \&my_function_set_some_css);

sub my_format_separate_anchor($$;$)
{
  my $converter = shift;
  my $id = shift;
  my $class = shift;

  return $converter->html_attribute_class('p', [$class])." id=\"$id\"></p>";
}

texinfo_register_formatting_function('format_separate_anchor',
                                     \&my_format_separate_anchor);

sub my_email_formatting_function {
  my $converter = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;

  my $args_nr = 0;
  if ($args) {
    $args_nr = scalar(@$args);
  }

  my $mail = '';
  my $mail_string = '';
  if ($args_nr > 0 and defined($args->[0])) {
    my $mail_arg = $args->[0];
    $mail = $mail_arg->{'url'};
    $mail_string = $mail_arg->{'monospacestring'};
  }

  my $text = '';
  if ($args_nr > 1 and defined($args->[1])
      and defined($args->[1]->{'normal'})) {
    my $text_arg = $args->[1];
    $text = $text_arg->{'normal'};
  }
  $text = $mail_string unless ($text ne '');

  my $tree = $converter->cdt('Generated @emph{@today{}} using '
                   .'@uref{{homepage}, @emph{{program}}}.',
           { 'homepage' => { 'text' => $converter->get_conf('PACKAGE_URL') },
             'program' => { 'text' => $converter->get_conf('PROGRAM') }});
  my $translated1 = $converter->convert_tree($tree);

  my $explanation_result;
  if ($converter->in_string()) {
    $explanation_result = $mail_string;
  } else {
    $explanation_result = $converter->html_attribute_class('a', ['myurl'])
     .' href="'.$converter->url_protect_url_text($mail_string)."\">$text</a>";
  }
  my $translated2 = $converter->convert_tree($converter->cdt(
                                      '{explained_string} ({explanation})',
                                {'explained_string' => {'type' => '_converted',
                                                        'text' => $translated1},
                                 'explanation' => {'type' => '_converted',
                                               'text' => $explanation_result}}),
                                  "convert explained $cmdname");

  $text .= " $translated2;";

  my $result;
  if ($converter->in_string()) {
    return "$mail_string ($text) $shown_styles, $footnotestyle";
  } else {
    $result = $converter->html_attribute_class('a', [$cmdname])
     ." href=\"mailto:$mail_string\">$text</a> [$shown_styles, $footnotestyle]";
  }

  if ($converter->in_preformatted_context()) {
    my $pre_classes = $converter->preformatted_classes_stack();
    foreach my $pre_class (@$pre_classes) {
      if ($Texinfo::Commands::preformatted_code_commands{$pre_class}) {
        $result = '<var>' .$result. '</var>';
        last;
      }
    }
  }
  return $result;
}

texinfo_register_command_formatting('email', \&my_email_formatting_function);

sub _convert_math_command($$$$)
{
  my $converter = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;

  my $arg;
  if ($args and $args->[0]) {
    $arg = $args->[0]->{'normal'};
  } else {
    return '';
  }

  my $open = $converter->html_attribute_class('span', ['math-arg']);
  my $arg_result = $open.'>'.$arg.'</span>'
  if ($open ne '');
  my $result = $converter->html_attribute_class('em', [$cmdname, 'jax_p'])
   . '>' . $arg_result . '</em>';

  return $result;
}

texinfo_register_command_formatting('math', \&_convert_math_command);

# put here as it is in the documentation, but not used as the
# final version is used, below.
sub my_tree_element_convert_paragraph_type($$$$)
{
  my $converter = shift;
  my $type = shift;
  my $element = shift;
  my $content = shift;

  $content = '' if (!defined($content));

  if ($converter->in_string()) {
    return $content;
  }

  my @contents = @{$element->{'contents'}};
  push @contents, {'text' => ' <code>HTML</code> text ',
                   'type' => '_converted'};
  my $result = $converter->convert_tree({'type' => '_code',
                                   'contents' => \@contents});
  return "<p>".$result."</p>";
}


sub my_final_convert_paragraph_type($$$$)
{
  my $converter = shift;
  my $type = shift;
  my $element = shift;
  my $content = shift;

  $content = '' if (!defined($content));

  my $prepended
    = $converter->get_associated_formatted_inline_content($element);
  if ($converter->in_string()) {
    return $prepended.$content;
  }

  my @contents = @{$element->{'contents'}};
  push @contents, {'text' => ' <code>HTML</code> text ',
                   'type' => '_converted'};
  my $result = $converter->convert_tree({'type' => '_code',
                                   'contents' => \@contents});
  return "<p>".$prepended.$result."</p>";
}

texinfo_register_type_formatting('paragraph',
                                 \&my_final_convert_paragraph_type);

sub my_test_documentation_convert_indented_command($$$$$)
{
  my $converter = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;
  my $content = shift;

  if (!defined($content) or $content eq '') {
    return '';
  }

  if ($converter->in_string()) {
    return $content;
  }

  my $non_breaking_space = $converter->get_info('non_breaking_space');
  my $result = '<tr><td>' .$non_breaking_space. '</tr></td>';

  return $converter->html_attribute_class('table', [$cmdname]).'>'
           . $result . $content . "</td></tr></table>\n";
}

texinfo_register_command_formatting('indentedblock',
                \&my_test_documentation_convert_indented_command);

my $counter = 0;
sub my_test_documentation_convert_index_entry_command_type($$$$)
{
  my $converter = shift;
  my $type = shift;
  my $element = shift;
  my $content = shift;

  if ($converter->in_multi_expanded()
      or $converter->in_string()) {
    return '';
  }

  my $cmdname = $element->{'info'}->{'command_name'};

  my $color_number = $converter->get_shared_conversion_state('quotation',
                                                       'color', 'purple1');
  my $color2_number = $converter->get_shared_conversion_state('quotation',
                                                   'color', 'special_black');
  $color_number++;
  $converter->set_shared_conversion_state('quotation',
                            'color', 'purple1', $color_number);

  my $index_id = $converter->command_id($element);
  if (defined($index_id) and $index_id ne '') {
    my $result = '<table>';
    $counter++;
    my $anchor_id = 'anchor_id_' . $counter;
    my $anchor_with_counter
      = &{$converter->formatting_function('format_separate_anchor')}(
                                   $converter, $anchor_id, 'myanchor_class');
    $result .= $anchor_with_counter;
    $result .= "\n" unless ($converter->in_preformatted_context());

    #my $indices_information
    #  = $converter->get_info('document')->indices_information();
    #my ($index_entry, $index_info)
    # = Texinfo::Common::lookup_index_entry($element->{'extra'}->{'index_entry'},
    #                                       $indices_information);
    #my $target_element = $index_entry->{'entry_element'};
    my $target_element = $element;
    my $target_text = $converter->command_text($target_element)
        . "<code>purple: $color_number, black: $color2_number</code>";
    my $target_href = $converter->command_href($target_element);
    my $hyperlink = "<a href=\"$target_href\">$target_text</a>";

    my $entry_root_link = '';
    my $associated_command
      = $converter->command_root_element_command($target_element);
    if ($associated_command) {
      my $associated_command_href
        = $converter->command_href($associated_command);
      my $associated_command_text
        = $converter->command_text($associated_command);

      if (defined($associated_command_href)) {
        $entry_root_link
          = "<a href=\"$associated_command_href\">"
          ."$associated_command_text</a>";
      } elsif (defined($associated_command_text)) {
        $entry_root_link = $associated_command_text;
      }
    }

    my $formatted_entry = "<td><tr>$hyperlink</tr>"
         ."<tr>$entry_root_link</tr></td>\n";

    my $label_element = $target_element->{'args'}->[0];
    Texinfo::Convert::Text::set_options_code(
                              $converter->{'convert_text_options'});
    Texinfo::Convert::Text::set_options_encoding_if_not_ascii($converter,
                              $converter->{'convert_text_options'});
    my $file_name = Texinfo::Convert::Text::convert_to_text($label_element,
                                $converter->{'convert_text_options'});
    Texinfo::Convert::Text::reset_options_code(
                                 $converter->{'convert_text_options'});
    Texinfo::Convert::Text::reset_options_encoding(
                                 $converter->{'convert_text_options'});

    $result .= $formatted_entry . "<td><tr>$file_name</tr></td>\n";
    $result .= "</table>\n";
    return $result;
  } else {
    my $text_element = {'text' => '@'.$cmdname};
    my $tree = $converter->cdt('No value for @strong{{item}}',
                                   {'item' => $text_element});
    my $no_value_converted_output = $converter->convert_tree($tree);
    return "<div>$no_value_converted_output</div>\n";
  }

  return '';
}

texinfo_register_type_formatting('index_entry_command',
               \&my_test_documentation_convert_index_entry_command_type);

sub my_test_documentation_convert_xref_commands($$$$)
{
  my $converter = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;

  my $xref_tree_element = $command;
  my $prepended = '';

  my $arg_node = $xref_tree_element->{'args'}->[0];
  if ($arg_node and $arg_node->{'extra'}
      and defined($arg_node->{'extra'}->{'normalized'})) {
    my $target_node
     = $converter->label_command($arg_node->{'extra'}->{'normalized'});
    my $identifier = $converter->command_id($target_node);
    $prepended = "<samp>$identifier</samp>";
  }

  return $prepended
     . &{$converter->default_command_conversion($cmdname)}($converter,
                                          $cmdname, $command, $args);
}

texinfo_register_command_formatting('xref',
             \&my_test_documentation_convert_xref_commands);


sub my_test_documentation_convert_printindex_command($$$$)
{
  my $converter = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;

  my $printindex_element = $command;
  my $prepended = '';

  my ($output_unit, $root_command)
     = $converter->get_element_root_command_element($printindex_element);
  my $index_element_id = $converter->command_id($root_command);
  $prepended = "<strong>RC: $index_element_id</strong>";

  return $prepended
     . &{$converter->default_command_conversion($cmdname)}($converter,
                                          $cmdname, $command, $args);
}

texinfo_register_command_formatting('printindex',
             \&my_test_documentation_convert_printindex_command);


sub my_node_file_name($$$) {
  my ($converter, $element, $filename) = @_;
  # ....
  my $node_file_name = 'prepended_to_filenames-'.$filename;
  return $node_file_name;
}

texinfo_register_file_id_setting_function('node_file_name',
                                          \&my_node_file_name);


sub my_label_target_name($$$$) {
  my ($converter, $normalized, $label_element, $default_target) = @_;
  if (defined($normalized)) {
    my $element = $converter->label_command($normalized);
    return 'prepended_to_labels-'.$element->{'extra'}->{'normalized'};
  }
  return $default_target;
}

texinfo_register_file_id_setting_function('label_target_name',
                                          \&my_label_target_name);

sub my_format_translate_message($$$;$)
{
  my ($converter, $string, $lang, $translation_context) = @_;
  $translation_context = '' if (!defined($translation_context));
  if (exists($translations{$lang})
      and exists($translations{$lang}->{$string})
      and exists($translations{$lang}->{$string}->{$translation_context})) {
    my $translation = $translations{$lang}->{$string}->{$translation_context};
    return $translation;
  }
  return undef;
}

texinfo_register_formatting_function('format_translate_message',
                                          \&my_format_translate_message);

1;
