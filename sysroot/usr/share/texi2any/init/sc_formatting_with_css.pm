use strict;

texinfo_register_upper_case_command('sc', 0);

foreach my $context ('normal', 'preformatted') {
  texinfo_register_style_command_formatting ('sc', 'span',
                                             undef, $context);
}

sub sc_formatting_with_css_set_css {
  my $converter = shift;
  $converter->css_set_selector_style('span.sc', 'font-variant: small-caps');
  return 0;
}
texinfo_register_handler('structure', \&sc_formatting_with_css_set_css);
