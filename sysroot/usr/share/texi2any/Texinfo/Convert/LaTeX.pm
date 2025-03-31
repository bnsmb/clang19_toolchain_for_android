# LaTeX.pm: output tree as LaTeX
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
# TODO
#
# RELEVANT BUT NOT DECISIVE
#
# If @allowcodebreaks is false, - should be set such that it is not a
# breaking point anymore.
#
# Note that the texinfo.tex code does more, for instance turns off normal
# hyphenation, sets plainfrenchspacing (see \tclose), and sets line breaks
# at _ and - with several special cases, such as no break right after one
# or two hyphen, no break between __ or hyphen.  See near \global\def\code
# in texinfo.tex.
#
#
# breaking in urls is not implemented, maybe there is some support already in
# hyperref.  @urefbreakstyle, @/
#
# Need some thinking/discussion for translations.  In texi2any?  In LaTeX?  If
# in texi2any in general no need for something as complex as gdt leading to a
# Texinfo tree, as we can provide strings to be translated already in LaTeX
# with the same property than Texinfo strings with LaTeX commands avoiding,
# to some extent, dependence on the language and/or encoding.
#
# It seems that \chaptername doesn't become Appendix for a sectioning command
# appearing after \appendix
#
# command that could be used for translation \sectionname does not exist in the
# default case.  it is defined in the pagenote package together with \pagename
# which is page in the default case, but it is unclear if this can be used as a
# basis for translations
#
# The @afourpaper, @afourlatex and @afourwide commands all map to
# papername=a4paper.  It is most likely ok for @afourlatex, but the other two
# should be associated with other geometries.
#
# The \geometry command does not really reset the geometry after
# \begin{document} according to the documentation, something else should be
# used to switch paper definition after document begin if needed.  Not
# necessarily a bad thing not to be able to change paper geometry after the
# beginning of the document.
#
# @pagesizes uses \newgeometry which forgets about previous settings except for
# paper size.  It could be a good thing to change geometry that way, but it is
# not how Texinfo TeX does it.
#
# The environment used for @quotation is quote as it seems to match in term of
# output, but the description of quote does not really match with what is
# supposed to be the @quotation output.
#
# Proper indenting of nested environments, @exdent from nested environment
#
# should we percent encode @email and @uref/@url urls?
#
# Some customization would be relevant, for example the
# document type, fonts, packages...  In particular, as reported by Karl,
# people will surely want to run xelatex or lualatex and use ttf/otf
# fonts, which means getting rid of the {fontenc} call entirely. (And
# using \usepackage{fontspec}\usepackage{unicode-math} instead.)
# We can also imagine people wanting different euro symbols.
# Maybe each one of the default \usepackage's should be configurable.
#
# @shortcontents is not implemented.  Tried shorttoc package but it
# has two limitations that are not in Texinfo, need a main \tableofcontents
# and need to be before @contents.  A code snippet looked good for a
# @shortcontents after @contents, but not before:
#{
#\renewcommand*{\contentsname}{Short contents}
#\setcounter{tocdepth}{0}
#\expandafter\def\csname @starttoc\endcsname#1{\InputIfFileExists{\jobname.#1}{}{}}%
#\tableofcontents
#}
# We could treat LaTeX like HTML with CONTENTS_OUTPUT_LOCATION=aftertop and
# ignore both @contents and @shortcontents.
#
# it seems that \indent only works with \setlength{\parindent}{0pt}
# which makes it quite different from Texinfo @indent.  Implement
# something differently to have the expected output with @indent?
#
#
# CAN WAIT
#
# Use texinfo.cnf?  Here?  in texi2any.pl?
#
# @need is implemented in a specific way, maybe there could be a definition of
# \mil instead.
#
# @group is not implemented.  We could try the minipage environment.
#
# @fonttextsize with \changefontsize does not seems to change fonts much.  It
# seems to change in the text, but only 10pt, and does not seems to change
# sections font sizes.
#
# The \listof formatting does not look so good.  Also it does not use the type
# (name) of float.
#
# in TeX, acronym is in a smaller font (1pt less). Can this be easily done in
# LaTeX?  Is it really useful to do that?
#
# interline spacing in @title multi lines in @titlepage and between multiple
# @author is not as good as in Texinfo TeX output/ example titlepage_classical
# in t/latex_tests.t can show it.
#
# shorttitlepage in Texinfo TeX does not seem to break line.  Probably ok.
#
# for external references it seems that Texinfo TeX points to a file, it could
# be relevant to do the same in LaTeX.
#
# Nothing specific is done for @headings singleafter and @headings doubleafter
# compared to @headings single and @headings double
#
# The support of \global\urefurlonlylinktrue would be rather easy, but
# need to make it a proper @-command first.  Similar for
# \global\def\linkcolor and \global\def\urlcolor.  There are options for
# colors in hyperref, like linkbordercolor but it is unclear whether it
# can be used to distinguish links and urls.
#
# In the manual it is said that majorheading generates a larger vertical
# whitespace before the heading than @chapheading command.  It is not
# implemented.  However, it seems that the chapter level commands in LaTeX
# generate bigger fonts and much more vertical whitespace than in Texinfo TeX
# so maybe it is not needed to do something here.
#
# index entry between @table and first @item causes an empty \item[] to be
# output.
#
# @headitem row is not formatted differently from an item row.  It is
# possible to use the multitable_head to get the same information.
#
# if there is a prototype for a multitable, it is converted to plain
# text to determine the fraction.  If it was done differently, @headitemfont
# may need to be processed, too.
#
# In Texinfo TeX, @code{@slanted{slanted in code}} and
# @slanted{@code{code in slanted}} are different,
# @slanted{@code{code in slanted}} is not slanted.
# According to Karl, we should not try to specify what nested style commands
# should be formatted as.  So this should probably not be considered
# as an issue, at least until we get user reports.
# https://lists.gnu.org/archive/html/bug-texinfo/2006-06/msg00030.html
#
# @indentedblock and @smallindentedblock should not have a wider right
# margin.  The wider margin is because they are in quote environment.
#
# @def* body should not have a wider right margin.  The wider margin
# is because they are in quote environment.

package Texinfo::Convert::LaTeX;

use 5.006;

# See comment at start of HTML.pm
use if $] >= 5.012, feature => qw(unicode_strings);

use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use File::Spec;

use Carp qw(cluck confess);

use Texinfo::Commands;
use Texinfo::Common;
use Texinfo::Convert::Texinfo;
use Texinfo::Convert::NodeNameNormalization;
use Texinfo::Convert::Text;
use Texinfo::Indices;
use Texinfo::Convert::Converter;

our @ISA = qw(Texinfo::Convert::Converter);

our $VERSION = '7.2';

# could export convert_to_latex_math


# commands that are of use for formatting.
my %formatted_line_commands = %Texinfo::Commands::formatted_line_commands;
my %formatted_nobrace_commands = %Texinfo::Commands::formatted_nobrace_commands;
my %formattable_line_commands = %Texinfo::Commands::formattable_line_commands;

my %paper_geometry_commands = (
  'afourpaper' => 'papername=a4paper',
  'afourlatex' => 'papername=a4paper',
  'afourwide' => 'papername=a4paper',
  'afivepaper' => 'papername=a5paper',
  'bsixpaper' => 'papername=b6paper',
  'smallbook' => 'paperheight=9.25in,paperwidth=7in',
);

my %informative_commands;
foreach my $informative_command (keys (%Texinfo::Common::document_settable_at_commands)) {
  $informative_commands{$informative_command} = 1;
}

my %brace_no_arg_commands;
foreach my $command (keys (%Texinfo::Commands::brace_commands)) {
  $brace_no_arg_commands{$command} = 1
    if ($Texinfo::Commands::brace_commands{$command} eq 'noarg');
}
my %accent_commands = %Texinfo::Commands::accent_commands;
my %line_commands = %Texinfo::Commands::line_commands;
my %nobrace_commands = %Texinfo::Commands::nobrace_commands;
my %sectioning_heading_commands = %Texinfo::Commands::sectioning_heading_commands;
my %def_commands = %Texinfo::Commands::def_commands;
my %ref_commands = %Texinfo::Commands::ref_commands;
my %block_commands = %Texinfo::Commands::block_commands;
my %root_commands = %Texinfo::Commands::root_commands;
my %preformatted_commands = %Texinfo::Commands::preformatted_commands;
my %math_commands = %Texinfo::Commands::math_commands;
my %preformatted_code_commands = %Texinfo::Commands::preformatted_code_commands;
my %default_index_commands = %Texinfo::Commands::default_index_commands;
my %heading_spec_commands = %Texinfo::Commands::heading_spec_commands;
my %letter_no_arg_commands = %Texinfo::Commands::letter_no_arg_commands;
my %explained_commands = %Texinfo::Commands::explained_commands;
my %inline_format_commands = %Texinfo::Commands::inline_format_commands;
my %brace_code_commands       = %Texinfo::Commands::brace_code_commands;
my %non_formatted_brace_command = %Texinfo::Commands::non_formatted_brace_command;

my %nobrace_symbol_text = %Texinfo::Common::nobrace_symbol_text;

foreach my $kept_command (keys(%informative_commands),
   keys(%default_index_commands),
   keys(%formattable_line_commands)) {
  $formatted_line_commands{$kept_command} = 1;
}

my %def_line_commands;
foreach my $def_command (keys(%def_commands)) {
  if ($line_commands{$def_command}) {
    $formatted_line_commands{$def_command} = 1;
    $def_line_commands{$def_command} = 1;
  }
}

# TODO command that could be used for translation \sectionname does
# not exist in the default case.  it is defined in the pagenote package
# together with \pagename which is page in the default case, but it is unclear
# if this can be used as a basis for translations
my %LaTeX_in_heading_commands_formatting = (
  # default for texinfo.tex is similar:
  #   \putwordChapter{} \thischapternum: \thischaptername}
  # see doc/txi-zh.tex for how it could be in chinese
  # TODO translation
  'thischapter' => '\chaptername{} \thechapter{} \chaptertitle{}',
  'thischaptername' => '\chaptertitle{}',
  'thischapternum' => '\thechapter{}',
  #  default for texinfo.tex is similar:
  #   \putwordSection{} \thissectionnum: \thissectionname}
  #'thissection' => '\sectionname{} \thesection{} \sectiontitle{}',
  'thissection' => 'Section \thesection{} \sectiontitle{}',
  'thissectionname' => '\sectiontitle{}',
  'thissectionnum' => '\thesection{}',
  'thisfile' => '\Texinfotheinclude{}',
  'thispage' => '\thepage{}',
  'thistitle' => '\Texinfosettitle{}',
);

foreach my $kept_command (keys(%LaTeX_in_heading_commands_formatting),
                                       'indent', 'noindent') {
  $formatted_nobrace_commands{$kept_command} = 1;
}

my %block_math_commands;
foreach my $block_math_command (keys(%math_commands)) {
  if (exists($block_commands{$block_math_command})) {
    $block_math_commands{$block_math_command} = 1;
  }
}

my %ignored_line_commands;
foreach my $line_command (keys(%line_commands)) {
  $ignored_line_commands{$line_command} = 1
    unless ($formatted_line_commands{$line_command});
}

my %ignored_nobrace_commands;
foreach my $nobrace_command (keys(%nobrace_commands)) {
  $ignored_nobrace_commands{$nobrace_command} = 1
    unless ($formatted_nobrace_commands{$nobrace_command});
}

# from \def\Gin@extensions in graphics-def/pdftex.def
my @LaTeX_image_extensions = (
'pdf','png','jpg','mps','jpeg','jbig2','jb2','PDF','PNG','JPG','JPEG','JBIG2','JB2');

my %section_map = (
   'top' => 'part*',
   'part' => 'part',
   'chapter' => 'chapter',
   'section' => 'section',
   'subsection' => 'subsection',
   'subsubsection' => 'subsubsection',
   # embed in a \Texinfonopagebreakheading call to remove pagebreaks
   'chapheading' => 'Texinfonopagebreakheading{\chapter*}',
   'majorheading' => 'Texinfonopagebreakheading{\chapter*}',
   'heading' => 'section*',
   'subheading' => 'subsection*',
   'subsubheading' => 'subsubsection*',
   'unnumbered' => 'chapter*',
   'centerchap' => 'chapter*',
   'unnumberedsec' => 'section*',
   'unnumberedsubsec' => 'subsection*',
   'unnumberedsubsubsec' => 'subsubsection*',
   'appendix' => 'chapter',
   'appendixsec' => 'section',
   'appendixsubsec' => 'subsection',
   'appendixsubsubsec' => 'subsubsection',
);

my %LaTeX_no_arg_brace_commands = (
   # textmode
  'cmd_text' => {
    'TeX' => '\TeX{}',
    'LaTeX' => '\LaTeX{}',
    'bullet' => '\textbullet{}',
    'copyright' => '\copyright{}',
    'registeredsymbol' => '\circledR{}',
    'dots' => '\dots{}\@',
    'enddots' => '\dots{}',
    'equiv' => '$\equiv{}$',
    'error' => '\fbox{error}',
    'expansion' => '$\mapsto{}$',
    'arrow' => '$\rightarrow{}$',
    'minus' => '-',
    'point' => '$\star{}$',
    'print' => '$\dashv{}$',
    'result' => '$\Rightarrow{}$',
    'pounds' => '\textsterling{}',
    'atchar', => '@',
    'lbracechar' => '\{',
    'rbracechar' => '\}',
    'backslashchar' => '\textbackslash{}',
    'hashchar' => '\#',
    'comma' => ',',
    'ampchar' => '\&',
    'euro' => '\euro{}',
    'geq' => '$\geq{}$',
    'leq' => '$\leq{}$',
    'textdegree' => '\textdegree{}',
    'today' => '\today{}',
    'tie' => '~'
  },
  'cmd_math' => {
    # error in math with \TeX \LaTeX, spacing command used not allowed
    # so use plain text
    'TeX' => 'TeX',
    'LaTeX' => 'LaTeX',
    'bullet' => '\bullet{}',
    'copyright' => '\copyright{}',
    'registeredsymbol' => '\circledR{}',
    'dots' => '\dots{}',
    'enddots' => '\dots{}',
    'equiv' => '\equiv{}',
    'error' => '\fbox{error}',
    'expansion' => '\mapsto{}',
    'arrow' => '\rightarrow{}',
    'minus' => '-',
    'point' => '\star{}',
    'print' => '\dashv{}',
    'result' => '\Rightarrow{}',
    'pounds' => '\mathsterling{}',
    'atchar', => '@',
    'lbracechar' => '\{',
    'rbracechar' => '\}',
    # this follows the Texinfo manual, however there is no obvious
    # visible effect
    'backslashchar' => '\mathtt{\backslash{}}',
    'hashchar' => '\#',
    'comma' => ',',
    'ampchar' => '\&',
    'euro' => '\euro{}',
    'geq' => '\geq{}',
    'leq' => '\leq{}',
    'textdegree' => '^{\circ{}}',
    'today' => '\today{}',
    'tie' => '\hbox{}',
  }
);

# the corresponding LaTeX commands can only appear in text mode
# so we switch to text mode to output them if in math
my %LaTeX_text_only_no_arg_brace_commands = (
  'exclamdown' => 'textexclamdown',
  'questiondown' => 'textquestiondown',
  'ordf' => 'textordfeminine',
  'ordm' => 'textordmasculine',
  'quotedblleft' => 'textquotedblleft',
  'quotedblright' => 'textquotedblright',
  'quoteleft' => 'textquoteleft',
  'quoteright' => 'textquoteright',
  'quotedblbase' => 'quotedblbase',
  'quotesinglbase' => 'quotesinglbase',
  'guillemetleft', => 'guillemotleft',
  'guillemetright' => 'guillemotright',
  'guillemotleft' => 'guillemotleft',
  'guillemotright' => 'guillemotright',
  'guilsinglleft' => 'guilsinglleft',
  'guilsinglright' => 'guilsinglright',
);

foreach my $letter_no_arg_command ('aa','AA','ae','oe','AE','OE','o','O',
                                   'ss','l','L','DH','dh','TH','th') {
  $LaTeX_text_only_no_arg_brace_commands{$letter_no_arg_command}
   = $letter_no_arg_command;
}

foreach my $text_only_no_arg_brace_command
     (keys(%LaTeX_text_only_no_arg_brace_commands)) {
  my $LaTeX_command =
    "\\$LaTeX_text_only_no_arg_brace_commands{$text_only_no_arg_brace_command}\{\}";
  $LaTeX_no_arg_brace_commands{'cmd_text'}->{$text_only_no_arg_brace_command}
    = $LaTeX_command;
  $LaTeX_no_arg_brace_commands{'cmd_math'}->{$text_only_no_arg_brace_command}
    = '\mathord{\text{'.$LaTeX_command.'}}';
}

# dotless is special
my %LaTeX_accent_commands = (
   # textmode
  'cmd_text' => {
    ',' => 'c',
    'ringaccent' => 'r',
    'H' => 'H',
    'dotaccent' => '.',
    'ubaraccent' => 'b',
    'udotaccent' => 'd',
    'ogonek' => 'k',
    'tieaccent' => 't',
  },
  'cmd_math' => {
    '"' => 'ddot',
    '~' => 'tilde',
    '^' => 'hat',
    '`' => 'grave',
    "'" => 'acute',
    '=' => 'bar',
    'ringaccent' => 'mathring',
    'dotaccent' => 'dot',
    'u' => 'breve',
    'v' => 'check',
  }
);

foreach my $accent_command (keys %{$LaTeX_accent_commands{'cmd_math'}}) {
  if (not exists($LaTeX_accent_commands{'cmd_text'}->{$accent_command})) {
    $LaTeX_accent_commands{'cmd_text'}->{$accent_command} = $accent_command;
  }
}


my %ignored_commands = (%ignored_line_commands, %ignored_nobrace_commands);
# processed as part of the index command or type formatting, or ignored.
foreach my $ignored_brace_commands (
  'sortas', 'seeentry', 'seealso', 'errormsg') {
  $ignored_commands{$ignored_brace_commands} = 1;
}

# titlepage content is directly formatted at document begin
foreach my $ignored_block_commands ('ignore', 'macro', 'rmacro', 'linemacro',
  'copying', 'documentdescription', 'titlepage', 'nodedescriptionblock') {
  $ignored_commands{$ignored_block_commands} = 1;
}

my %LaTeX_list_environments = (
  'itemize' => 'itemize',
  'enumerate' => 'enumerate',
);

my %format_raw_commands;
foreach my $block_command (keys(%block_commands)) {
  $ignored_commands{$block_command} = 1
    if ($block_commands{$block_command} eq 'menu');
  $LaTeX_list_environments{$block_command} = 'description'
    if ($block_commands{$block_command} eq 'item_line');
  $format_raw_commands{$block_command} = 1
    if ($block_commands{$block_command} eq 'format_raw');
}

my %block_raw_commands = %format_raw_commands;
foreach my $block_raw_command ('verbatim') {
  $block_raw_commands{$block_raw_command} = 1
}

my @LaTeX_same_block_commands = (
  'titlepage', 'verbatim');

my $small_font_size = 'footnotesize';

my %LaTeX_environment_commands = (
  'raggedright' => ['flushleft'],
  'flushleft' => ['flushleft', 'Texinfopreformatted'],
  'flushright' => ['flushright', 'Texinfopreformatted'],
  'quotation' => ['quote'],
  'smallquotation' => ['quote', $small_font_size],
  'indentedblock' => ['quote'],
  'smallindentedblock' => ['quote', $small_font_size],
  'cartouche' => ['mdframed'],
  'itemize' => ['itemize'],
  'enumerate' => ['enumerate'],
  'table' => ['description'],
  'vtable' => ['description'],
  'ftable' => ['description'],
  'example' => ['Texinfoindented'],
  'lisp' => ['Texinfoindented'],
  'display' => ['Texinfoindented'],
);

my %LaTeX_environment_options = (
  'cartouche' => {'mdframed' => 'style=Texinfocartouche'},
);

my %LaTeX_environment_packages = (
  'cartouche' => ['mdframed'],
);

my %LaTeX_fixed_width_environments = (
  'verbatim' => 1,
  'Texinfopreformatted' => 1,
);

# Empty containers do not happen often, mainly when a source mark
# needs to be kept.  However, it is more robust to remove explictely
# empty containers that we want to remove instead of relying on a
# specific tree.
my %container_ignored_if_empty = (
  'preformatted' => 1,
  #'menu_comment' => 1,
);

foreach my $environment_command (@LaTeX_same_block_commands) {
  $LaTeX_environment_commands{$environment_command} = [$environment_command];
}

# no floating material in the corresponding environment (mdframed)
my %LaTeX_non_floating_environment_commands = (
  'cartouche' => 1,
);

# no-op environment used in context where floating material is not
# allowed.
my $non_floating_float_environment = 'Texinfononfloatingfloat';

my %ignorable_space_types;
foreach my $type ('ignorable_spaces_after_command',
            'spaces_at_end',
            'spaces_after_close_brace') {
  $ignorable_space_types{$type} = 1;
}

my %ignored_types;
foreach my $type ('postamble_after_end', 'preamble_before_beginning',
            'preamble_before_setfilename') {
  $ignored_types{$type} = 1;
}

# The following code is used to define style commands with more
# complex code than a LaTeX command.
#
# It was designed initially to setup combined fonts similar to texinfo.tex
# fonts, corresponding to code like \ttsl, combining typewriter and slanted.
# The idea was to use constructs like \ttfamily\textsl to have a cumulative
# effect.  However, it seems that a constructs like \texttt{\textsl{cumulate}}
# do combine the styles, so nothing complex is needed for that case.
#
# As a side note it is not so easy to check the font type combinations
# results as they depend on the fonts.  With \usepackage[T1]{fontenc},
# used in the default case, there is no difference between typewriter
# and bold + typewriter, and \textbf{{\ttfamily\textsl{kbd in strong}}}
# seems to be in italic.  it is better to look at the results with
# \usepackage{lmodern}.

my $style_command_new_commands_prefix = 'Texinfocommandstyle';
# if new commands are setup for styles, they are in this hash
my %style_brace_format_command_new_commands;

# setup a new command
sub register_style_format_command($$$$$)
{
  my $formatting_context = shift;
  my $command = shift;
  my $formatting = shift;
  my $style_ref = shift;
  my $new_commands_ref = shift;

  # 'cmd_text' to 'text'
  my $formatting_context_text = $formatting_context;
  $formatting_context_text =~ s/^cmd_//;

  my $specific_style_command_name
   = "${style_command_new_commands_prefix}${formatting_context_text}$command";
  my $specific_style_command = '\\'.$specific_style_command_name;
  $style_ref->{$formatting_context}->{$command} = $specific_style_command;
  $new_commands_ref->{$formatting_context}->{$command}
    = "$specific_style_command\[1]{{$formatting\{#1}}}";
  return $specific_style_command_name;
}

# @-commands that stop code context
my %roman_style_commands = (
  'r' => 1,
);

# All those commands run with the text.
# math and verb are special and implemented separately.
# There is specific code for some commands, such as kbd, r
# in addition to using this hash.
my %LaTeX_style_brace_commands = (
  'cmd_text' => {
    'hyphenation' => '\\hyphenation',
    'w' => '\\hbox',
    'sub' => '\\textsubscript',
    'sup' => '\\textsuperscript',
    'r' => '\\textnormal',
    'sc' => '\\textsc',
    'sansserif' => '\\textsf',
  },
  'cmd_math' => {
    'hyphenation' => '',
    'w' => '\\hbox',
    'sub' => '_',
    'sup' => '^',
    'r' => '\\mathrm',
    'sc' => '', # no obvious way to do it in math mode, not switching to
                # text mode only for this command
    'sansserif' => '\\mathsf',
  }
);

foreach my $context (keys(%LaTeX_style_brace_commands)) {
  $style_brace_format_command_new_commands{$context} = {};
}

# embrac does not propagate in these commands.  But we want
# upside braces in these commands.  So we make them known to
# embrac.  Only locally, otherwise other commands can be broken.
my %need_known_embrac;
# other commands needed?
foreach my $LaTeX_style_command_name ('textsc', 'textbf', 'texttt') {
  $need_known_embrac{'\\'.$LaTeX_style_command_name} = $LaTeX_style_command_name;
}

# we want to keep those @-commands in roman slanted everywhere in text
# so use \normalfont{} to remove other font effects
foreach my $always_slanted_roman_commands ('cite', 'var') {
  register_style_format_command('cmd_text', $always_slanted_roman_commands,
                        '\\normalfont{}\\textsl', \%LaTeX_style_brace_commands,
                        \%style_brace_format_command_new_commands);
  # it seems better to use explicitly mathit, otherwise the space between
  # the letters in argument can be important for some letters (such as ff),
  # corresponding to letters being multiplied rather than to words, which
  # is a better interpretation for @-command arguments.
  # https://tex.stackexchange.com/questions/448069/fix-ugly-kerning-in-equation-subscript
  # In tests, \mathnormal didn't avoid the issue, and numbers
  # were small, so use \mathit, which also slants the numbers.
  $LaTeX_style_brace_commands{'cmd_math'}->{$always_slanted_roman_commands}
       = '\\mathit';
  $roman_style_commands{$always_slanted_roman_commands} = 1;
}

# specific style for kbd: slanted and typewriter.  code @-command
# formatting is used instead if needed, see _kbd_code_style.
register_style_format_command('cmd_text', 'kbd',
                        '\\ttfamily\\textsl', \%LaTeX_style_brace_commands,
                        \%style_brace_format_command_new_commands);

# FIXME headitemfont
my @asis_commands = ('asis', 'clicksequence', 'headitemfont');

foreach my $asis_command (@asis_commands) {
  $LaTeX_style_brace_commands{'cmd_text'}->{$asis_command} = '';
  $LaTeX_style_brace_commands{'cmd_math'}->{$asis_command} = '';
}

# in texinfo.tex, @dfn is slanted.
my @slanted_commands = ('dfn', 'slanted');
foreach my $slanted_command (@slanted_commands) {
  $LaTeX_style_brace_commands{'cmd_text'}->{$slanted_command} = '\\textsl';
  $LaTeX_style_brace_commands{'cmd_math'}->{$slanted_command} = '\\mathit';
}

my @emphasized_commands = ('emph');
foreach my $emphasized_command (@emphasized_commands) {
  $LaTeX_style_brace_commands{'cmd_text'}->{$emphasized_command} = '\\emph';
  $LaTeX_style_brace_commands{'cmd_math'}->{$emphasized_command} = '\\mathit';
}

my @bold_commands = ('strong', 'b');
foreach my $bold_command (@bold_commands) {
  $LaTeX_style_brace_commands{'cmd_text'}->{$bold_command} = '\\textbf';
  $LaTeX_style_brace_commands{'cmd_math'}->{$bold_command} = '\\mathbf';
}

my @italics_commands = ('i');
foreach my $italics_command (@italics_commands) {
  $LaTeX_style_brace_commands{'cmd_text'}->{$italics_command} = '\\textit';
  $LaTeX_style_brace_commands{'cmd_math'}->{$italics_command} = '\\mathit';
}

my @typewriter_commands = ('t', 'code', 'samp', 'key', 'env', 'file',
 'command', 'option', 'indicateurl');

foreach my $typewriter_command (@typewriter_commands) {
  $LaTeX_style_brace_commands{'cmd_text'}->{$typewriter_command} = '\\texttt';
  $LaTeX_style_brace_commands{'cmd_math'}->{$typewriter_command} = '\\mathtt';
}

my @quoted_commands = ('samp', 'indicateurl');

my %quotes_map;
# Quotes are reset in conversion_initialization and unicode quotes are used
# if @documentencoding utf-8 is used.
foreach my $quoted_command (@quoted_commands) {
  $quotes_map{$quoted_command} = ["`", "'"];
}

# Format in description for @*table argument

# note that if each command was formatted with format= option of
# enumitem \description, the command would need to be formatted
# with a final command, and possibly in a default bold font
# that would need to be isolated with \normalfont.  However, since
# a parbox with each items on different lines is used to avoid having
# too much spacing, there is no such constraint.  In any case, commands
# are defined for every style command if needed.
my %description_command_format;

my $description_command_new_commands_prefix = 'Texinfotablestyle';

# if new commands are setup for descriptions, they are in this hash
my %description_command_new_commands = ();

foreach my $command (keys(%{$LaTeX_style_brace_commands{'cmd_text'}})) {
  # avoids hyphenation @-command
  next if ($non_formatted_brace_command{$command});
  my $description_format = $LaTeX_style_brace_commands{'cmd_text'}->{$command};

  if ($quotes_map{$command}) {
    # Setup command used to format in tables for quoted commands.  Note that
    # the quotes used in that context are not modified by OUTPUT_ENCODING_NAME
    # nor *_QUOTE_SYMBOL.
    my $specific_format_command
      = "\\${description_command_new_commands_prefix}$command";
    # does not happen currently
    if ($description_format eq '') {
      $description_command_new_commands{$command} =
            "$specific_format_command\[1]{\\ifstrempty{#1}{}{{`#1'}}";
    } else {
      # We use \ifstrempty to avoid outputting an empty
      # quotation if there is no item.  Note that it does
      # not work as intended if there is no optional parameter
      # for item, like
      #   \item some text
      # but works for
      #   \item[] some text
      $description_command_new_commands{$command}
        = "$specific_format_command\[1]{\\ifstrempty{#1}{}{`$description_format\{#1}'}}";
    }
    $description_command_format{$command} = $specific_format_command;
  } elsif ($description_format ne '') {
    $description_command_format{$command} = $description_format;
  }
}


my %defaults = (
  # For LaTeX in general, it could make sense to have some customization,
  # for example of packages, fonts, document type, to be discussed/though
  # about how to setup this customization.

  # Customization option variables
  'OUTPUT_CHARACTERS'    => 0,
  'FORMAT_MENU'          => 'nomenu',
  'EXTENSION'            => 'tex',
  'documentlanguage'     => undef,
  'paragraphindent'      => undef, # global default is for Info/Plaintext
);


sub converter_defaults($$)
{
  return \%defaults;
}

# Converter state keys:
#
# collected_includes    Set if there is @thisfile in custom headings and
#                       @include's should be collected from source marks,
#                       holds the include file names and counter stack
# custom_heading
# description_format_commands
# extra_definitions: Texinfo specific LaTeX command definitions that
#                     need to be output based on the commands used to
#                     format the Texinfo code
# fixed_width_environments: fixed width environment used for formatting
# formatting_context: formatting context information for a whole context,
#                     for instance in a footnote.  See _push_new_context
#                     for the list of items set in formatting_context.
# index_entries
# indices_information
# list_environments
# latex_floats
# normalized_float_latex
# normalized_nodes_associated_section: associates anchor and node not already
#                     associated to section to the next or previous section.
# packages: packages needed by the LaTeX formatting of Texinfo code
# page_styles
# style_brace_format_commands

sub converter_initialize($)
{
  my $self = shift;

  %{$self->{'ignored_types'}} = %ignored_types;
  %{$self->{'ignorable_space_types'}} = %ignorable_space_types;
  %{$self->{'ignored_commands'}} = %ignored_commands;

  foreach my $format (keys(%format_raw_commands)) {
    $self->{'ignored_commands'}->{$format} = 1
       unless ($self->{'expanded_formats'}->{$format});
  }
  return $self;
}

sub conversion_initialization($;$)
{
  my $self = shift;
  my $document = shift;

  if ($document) {
    $self->set_document($document);
  }

  %{$self->{'quotes_map'}} = %quotes_map;

  # this condition means that there is no way to turn off
  # @U expansion to utf-8 characters even though this
  # could output characters that are not known in the
  # fontenc and will lead to an error.
  # This is described in the Texinfo manual, but not in
  # in a precise way.
  # FIXME add a customization variable?  Use a fontenc with more points?
  if ($self->get_conf('OUTPUT_ENCODING_NAME')
      and $self->get_conf('OUTPUT_ENCODING_NAME') eq 'utf-8') {
    # cache this to avoid redoing calls to get_conf
    $self->{'to_utf8'} = 1;

    if ($self->get_conf('OUTPUT_CHARACTERS')) {
      foreach my $quoted_command (@quoted_commands) {
        # Directed single quotes
        $self->{'quotes_map'}->{$quoted_command} = ["\x{2018}", "\x{2019}"];
      }
    }
  }
  if (defined($self->get_conf('OPEN_QUOTE_SYMBOL'))) {
    foreach my $quoted_command (@quoted_commands) {
      $self->{'quotes_map'}->{$quoted_command}->[0]
       = $self->get_conf('OPEN_QUOTE_SYMBOL');
    }
  }
  if (defined($self->get_conf('CLOSE_QUOTE_SYMBOL'))) {
    foreach my $quoted_command (@quoted_commands) {
      $self->{'quotes_map'}->{$quoted_command}->[1]
       = $self->get_conf('CLOSE_QUOTE_SYMBOL');
    }
  }
  # some caching to avoid calling get_conf
  $self->{'output_characters'} = $self->get_conf('OUTPUT_CHARACTERS');
  $self->{'output_encoding_name'} = $self->get_conf('OUTPUT_ENCODING_NAME');
  $self->{'debug'} = $self->get_conf('DEBUG');
}

my %LaTeX_floats = (
 'figure' => '\listoffigures',
 'table' => '\listoftables',
);

# associate float normalized types to latex float environment names
sub _prepare_floats($)
{
  my $self = shift;

  my $floats;
  if ($self->{'document'}) {
    $floats = $self->{'document'}->floats_information();
  }

  if ($floats) {
    $self->{'normalized_float_latex'} = {};
    $self->{'latex_floats'} = {};
    foreach my $normalized_float_type (sort(keys(%{$floats}))) {
      my $latex_variable_float_name;
      if (scalar(@{$floats->{$normalized_float_type}})) {
        my $float = $floats->{$normalized_float_type}->[0];
        $latex_variable_float_name
          = Texinfo::Convert::NodeNameNormalization::transliterate_texinfo(
           {'contents' => $float->{'args'}->[0]->{'contents'}});
      } else {
        $latex_variable_float_name = $normalized_float_type;
      }
      # note that with that transformation, some float types
      # may be put together
      $latex_variable_float_name =~ s/[^a-zA-Z]//g;
      if (exists($LaTeX_floats{lc($latex_variable_float_name)})) {
        $self->{'normalized_float_latex'}->{$normalized_float_type}
          = lc($latex_variable_float_name);
      } else {
        # for floats without type, and to avoid name clashes
        my $latex_float_name = 'TexinfoFloat'.$latex_variable_float_name;
        if (exists($self->{'latex_floats'}->{$latex_float_name})) {
          while (exists($self->{'latex_floats'}->{$latex_float_name})) {
            $latex_float_name .= 'a';
          }
        }
        $self->{'latex_floats'}->{$latex_float_name}
          = $normalized_float_type;
        $self->{'normalized_float_latex'}->{$normalized_float_type}
          = $latex_float_name;
      }
    }
  }
}

sub _prepare_indices($)
{
  my $self = shift;

  my $indices_information;
  if ($self->{'document'}) {
    $indices_information = $self->{'document'}->indices_information();
  }

  if ($indices_information) {
    $self->{'index_formatting_text_options'}
      = Texinfo::Indices::setup_index_entry_keys_formatting($self);
    my $merged_index_entries
        = $self->{'document'}->merged_indices();
    # select non empty indices
    if ($merged_index_entries) {
      $self->{'index_entries'} = {};
      foreach my $index_name (keys(%{$merged_index_entries})) {
        # print STDERR "PI $index_name\n";
        # print STDERR "".$merged_index_entries->{$index_name}."\n";
        #print STDERR " -> ".join("|", @{$merged_index_entries->{$index_name}})."\n";
        if (scalar(@{$merged_index_entries->{$index_name}})) {
          $self->{'index_entries'}->{$index_name}
               = $merged_index_entries->{$index_name};
        }
      }
    }
  }
}

sub _prepare_conversion($;$)
{
  my $self = shift;
  my $root = shift;

  # initialization for a new output
  $self->{'page_styles'} = {};
  $self->{'list_environments'} = {};
  $self->{'description_format_commands'} = {};
  $self->{'style_brace_format_commands'} = {};
  foreach my $context (keys(%style_brace_format_command_new_commands)) {
    $self->{'style_brace_format_commands'}->{$context} = {};
  }
  $self->{'packages'} = {};
  $self->{'extra_definitions'} = {};
  $self->{'fixed_width_environments'} = {};
  # something different is done for the first custom heading.
  # Not sure that values could be there, but delete anyway
  # to be clear.
  delete($self->{'custom_heading'});
  delete($self->{'index_entries'});

  my $global_commands;
  if ($self->{'document'}) {
    $global_commands = $self->{'document'}->global_commands_information();
  }

  if (defined($root)) {
    $self->_associate_other_nodes_to_sections($root);
  }

  if ($global_commands and $global_commands->{'settitle'}) {
    my $settitle_root = $global_commands->{'settitle'};
    if ($settitle_root->{'args'}->[0]
        and $settitle_root->{'args'}->[0]->{'contents'}) {
      $self->{'settitle_tree'} =
         {'contents' => $settitle_root->{'args'}->[0]->{'contents'}};
    }
  }
  $self->_prepare_floats();
  $self->_prepare_indices();
}

sub _associate_other_nodes_to_sections($$)
{
  my ($self, $root) = @_;

  # associate lone nodes with sectioning commands
  my $additional_node_section_associations = {};

  my $current_sectioning_command;
  # nodes not already associated as no section has been seen,
  # associate to the first section
  my $pending_nodes = [];

  foreach my $element_content (@{$root->{'contents'}}) {
    if ($element_content->{'cmdname'}
        and $element_content->{'cmdname'} eq 'node') {
      if ($element_content->{'extra'}
          and not $element_content->{'extra'}->{'associated_section'}
          and defined($element_content->{'extra'}->{'normalized'})) {
        if (defined($current_sectioning_command)) {
          $additional_node_section_associations
              ->{$element_content->{'extra'}->{'normalized'}}
                   = $current_sectioning_command;
        } else {
          push @$pending_nodes, $element_content->{'extra'}->{'normalized'};
        }
      }
    } elsif ($element_content->{'cmdname'}
          and $root_commands{$element_content->{'cmdname'}}) {
      $current_sectioning_command = $element_content;
      if (scalar(@$pending_nodes)) {
        foreach my $normalized_node_name (@$pending_nodes) {
          $additional_node_section_associations->{$normalized_node_name}
            = $current_sectioning_command
        }
        $pending_nodes = [];
      }
    }
  }
  # If there are no sectioning commands and there are nodes,
  # $pending_nodes won't be empty and no node is associated.
  #print STDERR "No sectioning commands but nodes\n"
  #  if (scalar(@$pending_nodes) > 0);
  $self->{'normalized_nodes_associated_section'}
    = $additional_node_section_associations;
}

# this type marks where the \begin{document} should be,
# after the @-commands in preamble.  It is not setup
# when using parse_texi_piece only.
my $latex_document_type = 'preamble_before_content';

sub output($$)
{
  my $self = shift;
  my $document = shift;

  $self->conversion_initialization($document);

  my $root = $document->tree();

  my ($output_file, $destination_directory, $output_filename)
    = $self->determine_files_and_directory(
                                  $self->get_conf('TEXINFO_OUTPUT_FORMAT'));

  my ($encoded_destination_directory, $dir_encoding)
    = $self->encoded_output_file_name($destination_directory);
  my $succeeded
    = $self->create_destination_directory($encoded_destination_directory,
                                          $destination_directory);
  return undef unless $succeeded;

  my $fh;
  my $encoded_output_file;
  if (! $output_file eq '') {
    my $path_encoding;
    ($encoded_output_file, $path_encoding)
      = $self->encoded_output_file_name($output_file);
    my $error_message;
    # the third return information, set if the file has already been used
    # in this files_information is not checked as this cannot happen.
    ($fh, $error_message) = Texinfo::Convert::Utils::output_files_open_out(
                             $self->output_files_information(), $self,
                             $encoded_output_file);
    if (!$fh) {
      $self->converter_document_error(
             sprintf(__("could not open %s for writing: %s"),
                                    $output_file, $error_message));
      return undef;
    }
  }

  my $modified_root;

  # determine if there is a Top node at the end of the document
  my $in_top_node = undef;
  foreach my $element_content (@{$root->{'contents'}}) {
    my $node_element;
    if ($element_content->{'cmdname'}) {
      my $cmdname = $element_content->{'cmdname'};
      if ($cmdname eq 'node') {
        $node_element = $element_content;
      } elsif ($cmdname eq 'part' and $element_content->{'extra'}
               and $element_content->{'extra'}->{'part_following_node'}) {
        $node_element = $element_content->{'extra'}->{'part_following_node'};
      }
      if ($node_element or $cmdname eq 'part') {
        if ($node_element and $node_element->{'extra'}
            and $node_element->{'extra'}->{'normalized'}
            and $node_element->{'extra'}->{'normalized'} eq 'Top') {
          $in_top_node = 1;
        } else {
          if ($in_top_node) {
            $in_top_node = 0;
            last;
          }
        }
      }
    }
  }
  # nothing after Top node at the end, mark that Top node is ignored
  # in a container that can be used to mark that content should not
  # be ignored anymore.
  if ($in_top_node) {
    $modified_root = {'contents' => [ @{$root->{'contents'}} ],
                      'type' => $root->{'type'}}
      if (not defined($modified_root));
    push @{$modified_root->{'contents'}},
        {'type' => 'ignored_top_node_paragraph', 'contents' => [
         {'type' => 'paragraph', 'contents' => [
          {'text' => "\n(`Top' node ignored)\n", 'type' => 'ignored_top_node'}]}]};
  }

  if (not defined($modified_root)) {
    $modified_root = $root;
  }


  $self->_prepare_conversion($modified_root);

  my $result = '';
  $result .= $self->_latex_begin_output();
  $result .= $self->convert_tree($modified_root);
  $result .= $self->_latex_footer();

  my $output = '';
  $output .= $self->write_or_return($self->_latex_header(), $fh);
  $output .= $self->write_or_return($result, $fh);

  #print STDERR "OUTPUT fh:$fh|F:$output_file|$result";
  if ($fh and $output_file ne '-') {
    Texinfo::Convert::Utils::output_files_register_closed(
                  $self->output_files_information(), $encoded_output_file);
    if (!close ($fh)) {
      $self->converter_document_error(
                   sprintf(__("error on closing %s: %s"),
                                    $output_file, $!));
    }
  }
  return $output;
}

# we allow the converter to already be in a context, but if
# not create one.
sub convert($$)
{
  my $self = shift;
  my $document = shift;

  $self->conversion_initialization($document);

  my $root = $document->tree();

  $self->_prepare_conversion($root);

  my $new_context;
  if (not exists($self->{'formatting_context'})
      or scalar(@{$self->{'formatting_context'}}) == 0) {
    _push_new_context($self, 'document');
    $new_context = 1;
  }

  my $result = $self->_convert($root);

  if ($new_context) {
    _pop_context($self);
  }
  return $result;
}

# a context should have been set by the caller
sub convert_tree($$)
{
  my $self = shift;
  my $root = shift;

  my $new_context;
  if (not exists($self->{'formatting_context'})
      or scalar(@{$self->{'formatting_context'}}) == 0) {
    _push_new_context($self, 'tree');
    $new_context = 1;
  }

  my $result = $self->_convert($root);

  if ($new_context) {
    _pop_context($self);
  }
  return $result;
}

sub copy_options_for_convert_to_latex_math($)
{
  my $self = shift;
  my %options;
  foreach my $option_name ('DEBUG', 'OUTPUT_CHARACTERS', 'OUTPUT_ENCODING_NAME',
                           'TEST') {
    $options{$option_name} = $self->get_conf($option_name)
                    if (defined($self->get_conf($option_name)));
  }
  return %options;
}

# convert texinfo tree to LaTeX math
# Errors are not passed, nor the converter.  However the errors and warnings
# generated by the LaTeX conversion are few and not relevant for math tree
# fragments.  Relevant errors should be generated when parsing the Texinfo,
# or when converting the final LaTeX.
# Document could be passed to conversion_initialization if needed.
sub convert_to_latex_math($$;$$)
{
  my $self = shift;
  my $root = shift;
  my $options = shift;
  my $math_style = shift;

  $math_style = 'one-line' if (not defined($math_style));

  if (not defined($self)) {
    $self = Texinfo::Convert::LaTeX->converter($options);
  }

  $self->conversion_initialization();

  _push_new_context($self, 'convert_to_math');

  push @{$self->{'formatting_context'}->[-1]->{'text_context'}}, 'ctx_math';
  push @{$self->{'formatting_context'}->[-1]->{'math_style'}}, $math_style;

  my $result = $self->_convert($root);

  _pop_context($self);

  return $result;
}

# associates to an inputenc and fontenc
my %LaTeX_encoding_names_map = (
  'utf-8' => ['utf8', 'T1'],
  # from https://ctan.gutenberg-asso.fr/macros/latex/base/inputenc.pdf
  # The ASCII encoding only allows characters in the range 32-127,
  'us-ascii' => ['ascii', 'T1'],
  'iso-8859-1' => ['latin1', 'T1'],
  # The ISO Latin-9 encoding file defines the characters in the ISO 8859-15
  # encoding
  'iso-8859-15' => ['latin9', 'T1'],
  # The ISO Latin-2 encoding file defines the characters in the ISO 8859-2
  # encoding.
  'iso-8859-2' => ['latin2', 'T1'],

  # requires texlive-lang-cyrillic on debian.
  # T2A seems to be the only required fontenc for Russian and Ukrainian
  # according to
  #   https://www.latex-project.org/help/documentation/cyrguide.pdf
  # Font encodings for Cyrillic languages
  'koi8-r' => ['koi8-r', 'T2A'],
  'koi8-u' => ['koi8-u', 'T2A'],
);

# book or report?
my $documentclass = 'book';

my %front_main_matter_definitions = (
  'book' =>   {'main'  => '\mainmatter',
               'front' => '\frontmatter'},
  'report' => {'main'  => '\clearpage\pagenumbering{arabic}',
               'front' => '\clearpage\pagenumbering{roman}'}
);

# not used as it is complicated to use section and chapter title
# NB this will not work any more as the \Texinfoset... macros are
# not used, and \pagestyle is used directly.
my $fancyhdr_preamble =
'% called when setting single headers
% use \nouppercase to match with Texinfo TeX style
\newcommand{\Texinfosetsingleheader}{\pagestyle{fancy}
\fancyhf{}
\lhead{\nouppercase{\leftmark}}
\rhead{\thepage}
}

% called when setting double headers
\newcommand{\Texinfosetdoubleheader}{\pagestyle{fancy}
\fancyhf{}
\fancyhead[LE,RO]{\thepage}
\fancyhead[RE]{\Texinfosettitle}
\fancyhead[LO]{\nouppercase{\leftmark}}
}

% for part and chapter, which call \thispagestyle{plain}
\fancypagestyle{plain}{ %
 \fancyhf{}
 \fancyhead[LE,RO]{\thepage}
}

% match Texinfo TeX style
\renewcommand{\headrulewidth}{0pt}%';

# TODO translation
my $default_title = 'No Title';

sub _latex_header() {
  my $self = shift;
  # LaTeX code appearing after packages.  Do it first to be able to
  # select packages based on the code output here.
  my $header_code = '';
  my $settitle;
  if ($self->{'settitle_tree'}) {
    $settitle = $self->convert_tree($self->{'settitle_tree'});
  } else {
    $settitle = $default_title;
  }
  $header_code .= "\\makeatletter\n";

  # for @thistitle and headers
  $header_code .= "\\newcommand{\\Texinfosettitle}{$settitle}%\n";
  if ($self->{'collected_includes'}) {
    $header_code .= "\\newcommand{\\Texinfotheinclude}{}%\n";
  }
  $header_code .= "\n";

  my $floats;
  if ($self->{'document'}) {
    $floats = $self->{'document'}->floats_information();
  }

  if ($floats) {
    my $floats_extension = $self->get_conf('LATEX_FLOATS_FILE_EXTENSION');
    foreach my $normalized_float_type
                           (sort(keys(%{$self->{'normalized_float_latex'}}))) {
      my $latex_float_name
        = $self->{'normalized_float_latex'}->{$normalized_float_type};
      if (not exists($LaTeX_floats{$latex_float_name})) {
        my $float_type = '';
        if ($normalized_float_type ne '') {
          _push_new_context($self, 'float_type '.$normalized_float_type);
          my $float = $floats->{$normalized_float_type}->[0];
          my $float_type = _convert($self, $float->{'args'}->[0]);
          _pop_context($self);
        }
        $header_code .= "% new float for type `$normalized_float_type'\n";
        $header_code
           .= "\\newfloat{$latex_float_name}{htb}{$floats_extension}[chapter]
\\floatname{$latex_float_name}{$float_type}
";
      }
    }
  }
  if ($self->{'index_entries'}
      and scalar(keys(%{$self->{'index_entries'}}))) {
    # FIXME with noclearpage looks more like regular Texinfo output, as indices
    # are output in the flow of the text, not as separate chapter/section-like
    # elements.  However, with noclearpage, the index may not be output if
    # it is at the end of the file, for example in latex_tests indices test.
    #$header_code .= "% no index headers or page break\n";
    #$header_code .= "\\indexsetup{level=\\relax,toclevel=section,noclearpage}%\n";
    $header_code .= "% no index headers\n";
    $header_code .= "\\indexsetup{level=\\relax,toclevel=section}%\n";

    foreach my $index_name (sort(keys(%{$self->{'index_entries'}}))) {
      $header_code .= "\\makeindex[name=$index_name,title=]%\n";
    }
    $header_code .= "\n";
  }
  # define additional commands used in @*table description format
  foreach my $command (sort(keys(%description_command_new_commands))) {
    if ($self->{'description_format_commands'}->{$command}) {
      $header_code .= '% command used in \description format for '.$command."\n";
      $header_code .= "\\newcommand"
                      .$description_command_new_commands{$command}."%\n";
      $header_code .= "\n";
    }
  }
  foreach my $command_context (sort(keys(%style_brace_format_command_new_commands))) {
    if ($self->{'style_brace_format_commands'}->{$command_context}) {
      foreach my $command
         (sort(keys(%{$style_brace_format_command_new_commands{$command_context}}))) {
        if ($self->{'style_brace_format_commands'}->{$command_context}->{$command}) {
          $header_code .= '% style command for '.$command
                          ." in '$command_context' formatting context\n";
          $header_code .= "\\newcommand"
   .$style_brace_format_command_new_commands{$command_context}->{$command}."%\n";
          $header_code .= "\n";
        }
      }
    }
  }

  if ($documentclass eq 'book') {
    $header_code .=
'% redefine the \mainmatter command such that it does not clear page
% as if in double page
\renewcommand\mainmatter{\clearpage\@mainmattertrue\pagenumbering{arabic}}
';
  }

  $header_code .=
'\newenvironment{Texinfopreformatted}{%
  \\par\\GNUTobeylines\\obeyspaces\\frenchspacing\\parskip=\\z@\\parindent=\\z@}{}
{\catcode`\^^M=13 \gdef\GNUTobeylines{\catcode`\^^M=13 \def^^M{\null\par}}}
';

  $header_code .=
'\newenvironment{Texinfoindented}{\begin{list}{}{}\item\relax}{\end{list}}

';

  if ($self->{'packages'}->{'babel'}) {
    $header_code .= '
% this allows to select languages based on bcp47 codes.  bcp47 is a superset
% of the LL_CC ISO 639-2 LL ISO 3166 CC information of @documentlanguage
\babeladjust{
  autoload.bcp47 = on,
  autoload.bcp47.options = import
}
';
  }

  # disactivate microtype for fixed-width environments
  if (scalar(keys(%{$self->{'fixed_width_environments'}}))) {
    if ($self->{'packages'}->{'microtype'}) {
      foreach my $no_microtype_environment (sort(keys(%{$self->{'fixed_width_environments'}}))) {
        $header_code .= "\\AtBeginEnvironment{$no_microtype_environment}"
                        ."{\\microtypesetup{activate=false}}\n";
      }
    }
    $header_code .= "\n";
  }

  if (scalar(keys(%{$self->{'list_environments'}}))) {
    $header_code .= "% set defaults for lists that match Texinfo TeX formatting\n";
    if ($self->{'list_environments'}->{'description'}) {
      $header_code .= "\\setlist[description]{style=nextline, font=\\normalfont}\n";
    }
    if  ($self->{'list_environments'}->{'itemize'}) {
      $header_code .= "\\setlist[itemize]{label=\\textbullet}\n";
    }
    if  ($self->{'list_environments'}->{'enumerate'}) {
      $header_code .= "\\setlist[enumerate]{label=\\arabic*.}\n";
    }
    $header_code .= "\n";
  }

  $header_code .= '% used for substitutions in commands
\newcommand{\Texinfoplaceholder}[1]{}

';

  if ($self->{'packages'}->{'caption'}) {
    $header_code .= '% environment for non floating floats
\newenvironment{'."$non_floating_float_environment".'}
  {\ignorespaces}
  {\ignorespacesafterend}

';
  }

  if ($self->{'page_styles'}->{'single'}) {
    $header_code .=
'\newpagestyle{single}{\sethead[\chaptername{} \thechapter{} \chaptertitle{}][][\thepage]
                              {\chaptername{} \thechapter{} \chaptertitle{}}{}{\thepage}}

';
  }

  if ($self->{'page_styles'}->{'double'}) {
    $header_code .=
'\newpagestyle{double}{\sethead[\thepage{}][][\Texinfosettitle]
                              {\chaptername{} \thechapter{} \chaptertitle{}}{}{\thepage}}

';
  }

  if ($self->{'page_styles'}->{'doublepagenum'}) {
    $header_code .=
'\newpagestyle{doublepagenum}{\sethead[\thepage{}][][]
                              {}{}{\thepage}}

';
  }

  if ($self->{'page_styles'}->{'singlepagenum'}) {
    $header_code .=
'\newpagestyle{singlepagenum}{\sethead[][][\thepage{}]
                              {}{}{\thepage}}

';
  }

  if ($self->{'extra_definitions'}->{'Texinfonopagebreakheading'}) {
    $header_code .=
'% avoid pagebreak and headings setting for a sectioning command
\newcommand{\Texinfonopagebreakheading}[2]{{\let\clearpage\relax \let\cleardoublepage\relax \let\thispagestyle\Texinfoplaceholder #1{#2}}}

';
  }

  if ($self->{'packages'}->{'mdframed'}) {
   $header_code .= '% the mdframed style for @cartouche
\mdfdefinestyle{Texinfocartouche}{
innertopmargin=10pt, innerbottommargin=10pt,%
roundcorner=10pt}

';
  }

  if ($self->{'packages'}->{'embrac'}) {
    # in order to have brackets and parenthese upright in slanted typewriter
    # \textsl{\texttt, \EmbracMakeKnown{texttt} is needed.  However, we only
    # set it locally, otherwise \hyperref in \texttt can break.
    $header_code .= '% braces are upright in italic and slanted only in @def*
% so it is turned off here, and turned on @def* lines
\EmbracOff{}%

'
  }

  $header_code .= '% allow line breaking at underscore
\let\Texinfounderscore\_
\renewcommand{\_}{\Texinfounderscore\discretionary{}{}{}}
';

  # this is in order to be able to run pdflatex even
  # if files do not exist, or filenames cannot be
  # processed by LaTeX
  if ($self->get_conf('TEST')) {
    $header_code .=
'\renewcommand{\includegraphics}[1]{\fbox{FIG \detokenize{#1}}}

';
  }
  $header_code .= "\\makeatother\n";

  # amsfonts for \circledR
  # amsmath for \text in math
  # T1 fontenc for \DH, \guillemotleft, ...
  # eurosym for \euro
  # textcomp for \textdegree in older LaTeX
  # graphicx for \includegraphics
  # needspace for \needspace. In texlive-latex-extra in debian
  # etoolbox for \patchcmd, \ifstrempty and \AtBeginEnvironment.
  # In texlive-latex-recommended in debian
  # fontsize for \changefontsize. In texlive-latex-extra in debian
  # mdframed is used for the formatting of @cartouche,
  # caption for float in non floating environment, namely cartouche (mdframed)
  # microtype is used for @microtype
  # microtype requires cm-super installed, or to use lmodern package.
  # In texlive-latex-recommended in debian.
  # framemethod=TikZ is needed for roundcorner.
  # Possibility for hyperref for color:
  # \usepackage[linkbordercolor={0 0 0}]{hyperref}
  # titleps is used and not fancyhdr as with fancyhdr it is hard to get
  # the section or chapter title
  my $class_and_usepackage_begin = $self->get_conf('CLASS_BEGIN_USEPACKAGE');
  if (!defined($class_and_usepackage_begin)) {
    $class_and_usepackage_begin = "\\documentclass{$documentclass}\n";
    $class_and_usepackage_begin .= '\usepackage{amsfonts}
\usepackage{amsmath}
\usepackage[gen]{eurosym}
\usepackage{textcomp}
\usepackage{graphicx}
\usepackage{etoolbox}
\usepackage{titleps}
';
    my $fontenc = 'T1';
    if ($self->{'output_encoding_name'}) {
      my $output_encoding = $self->{'output_encoding_name'};
      my $encoding = $output_encoding;
      if (defined($LaTeX_encoding_names_map{$output_encoding})) {
        ($encoding, $fontenc) = @{$LaTeX_encoding_names_map{$output_encoding}};
      }
      $class_and_usepackage_begin .= "\\usepackage[$encoding]{inputenc}\n";
    }
    $class_and_usepackage_begin .= "\\usepackage[$fontenc]{fontenc}\n";
  }
  my $usepackage_end = $self->get_conf('END_USEPACKAGE');
  if (!defined($usepackage_end)) {
    if ($self->{'index_entries'}
        and scalar(keys(%{$self->{'index_entries'}}))) {
      $usepackage_end .= "\\usepackage{imakeidx}\n";
    }
    if ($self->{'packages'}->{'needspace'}) {
      $usepackage_end .= "\\usepackage{needspace}\n";
    }
    if ($self->{'packages'}->{'microtype'}) {
      $usepackage_end .= "\\usepackage[activate=false]{microtype}\n";
    }
    if ($self->{'packages'}->{'array'}) {
      $usepackage_end .= "\\usepackage{array}\n";
    }
    if ($self->{'packages'}->{'embrac'}) {
      $usepackage_end .= "\\usepackage{embrac}\n";
      $usepackage_end .= "\\usepackage{expl3}\n";
    }
    if ($self->{'packages'}->{'tabularx'}) {
      $usepackage_end .= "\\usepackage{tabularx}\n";
    }
    if ($self->{'packages'}->{'mdframed'}) {
      # framemethod=tikz needed for roundcorners for @cartouche
      $usepackage_end .= "\\usepackage[framemethod=tikz]{mdframed}\n";
    }
    if ($self->{'packages'}->{'caption'}) {
      # capt-of gives an error for float.t float_in_block_commands test
      #$usepackage_end .= "\\usepackage{capt-of}\n";
      $usepackage_end .= "\\usepackage{caption}\n";
    }
    if ($self->{'packages'}->{'fontsize'}) {
      $usepackage_end .= "\\usepackage{fontsize}\n";
    }
    if (scalar(keys(%{$self->{'list_environments'}}))) {
      $usepackage_end .= "\\usepackage{enumitem}\n";
    }
    if ($self->{'packages'}->{'geometry'}) {
      $usepackage_end .= "\\usepackage{geometry}\n";
    }
    if ($floats) {
      $usepackage_end .= "\\usepackage{float}\n";
    }
    if ($self->{'packages'}->{'babel'}) {
      $usepackage_end .= "\\usepackage{babel}\n";
    }
    # Documentation says to include last
    $usepackage_end
     .= '% use hidelinks to remove boxes around links to be similar to Texinfo TeX
\usepackage[hidelinks]{hyperref}
';
  }
  return $class_and_usepackage_begin . $usepackage_end . "\n" . $header_code;
}

# return LaTeX output code for informative @-commands.
sub _informative_command_output($$)
{
  my $self = shift;
  my $cmdname = shift;
  my $value = shift;

  if ($cmdname eq 'documentlanguage') {
    my $language = $self->get_conf($cmdname);
    $language =~ s/_/-/;
    $self->{'packages'}->{'babel'} = 1;
    return "\\selectlanguage{$language}%\n";
  } elsif ($cmdname eq 'pagesizes') {
    my $pagesize_spec = $self->get_conf($cmdname);
    my @pagesize_args = split(/\s*,\s*/, $pagesize_spec);
    my @geometry;
    my $height = shift @pagesize_args;
    if (defined($height) and $height ne '') {
      push @geometry, "textheight=$height";
    }
    my $width = shift @pagesize_args;
    if (defined($width) and $width ne '') {
      push @geometry, "textwidth=$width";
    }
    if (scalar(@geometry)) {
      $self->{'packages'}->{'geometry'} = 1;
      return "\\newgeometry{".join(',', @geometry)."}\n";
    }
  } elsif ($cmdname eq 'paragraphindent') {
    my $indentation_spec = $self->get_conf($cmdname);
    if ($indentation_spec eq 'asis') {
      # not implemented here, same as in TeX.
      return '';
    } else {
      my $indentation_spec_arg = $indentation_spec.'em';
      if ($indentation_spec eq '0' or $indentation_spec eq 'none') {
        $indentation_spec_arg = '0pt';
      }
      return "\\setlength{\\parindent}{$indentation_spec_arg}\n";
    }
  } elsif ($cmdname eq 'firstparagraphindent') {
    my $indentation_spec = $self->get_conf($cmdname);
    my $result = "\\makeatletter\n";
    if ($indentation_spec eq 'insert') {
      # From LaTeX indentfirst package: "LaTeX uses the switch
      # \if@afterindent to decide whether to indent after a section
      # heading. We just need to make sure that this is always true."
      $result .= "\\let\\\@afterindentfalse\\\@afterindenttrue\n";
      $result .= "\\\@afterindenttrue\n";
    } elsif ($indentation_spec eq 'none') {
      # restore original definition
      $result .= '\\def\\@afterindentfalse{'
                 . "\\let\\if\@afterindent\\iffalse}\n";
    }
    $result .= "\\makeatother\n";
    return $result;
  } elsif ($cmdname eq 'frenchspacing') {
    my $frenchspacing_spec = $self->get_conf($cmdname);
    if ($frenchspacing_spec eq 'on') {
      return "\\frenchspacing\n";
    } elsif ($frenchspacing_spec eq 'off') {
      return "\\nonfrenchspacing\n";
    }
  } elsif ($cmdname eq 'setchapternewpage') {
    my $setchapternewpage_spec = $self->get_conf($cmdname);
    my ($setchapternewpage_result, $heading_set)
      = _set_chapter_new_page($self, $setchapternewpage_spec);
    return $setchapternewpage_result;
  } elsif ($cmdname eq 'headings') {
    my $headings_spec = $self->get_conf($cmdname);
    return _set_headings($self, $headings_spec);
  } elsif ($cmdname eq 'fonttextsize') {
    my $fontsize = $self->get_conf($cmdname);
    $self->{'packages'}->{'fontsize'} = 1;
    # default dimension for changefontsize is pt
    return "\\changefontsize{$fontsize}\n";
  } elsif ($cmdname eq 'microtype') {
    my $microtype_spec = $self->get_conf($cmdname);
    $self->{'packages'}->{'microtype'} = 1;
    if ($microtype_spec eq 'on') {
      return "\\microtypesetup{activate=true}%\n";
    } elsif ($microtype_spec eq 'off') {
      return "\\microtypesetup{activate=false}%\n";
    }
  } elsif ($paper_geometry_commands{$cmdname}) {
    $self->{'packages'}->{'geometry'} = 1;
    return "\\geometry{$paper_geometry_commands{$cmdname}}%\n";
  }

  return '';
}

my %LaTeX_defaults = (
  'firstparagraphindent' => 'none',
  'fonttextsize' => 11,
  'frenchspacing' => 'off',
  'microtype' => 'off',
);

sub _latex_begin_output($)
{
  my $self = shift;

  #my $header = "\n";
  my $header = "";
  # Special treatment for setchapternewpage, we want to avoid
  # a useless headings set just below
  $header .= "% set default for \@setchapternewpage\n";
  my $heading_set;
  if (defined($self->get_conf('setchapternewpage'))) {
    my $setchapternewpage_result;
    ($setchapternewpage_result, $heading_set)
      = _set_chapter_new_page($self, $self->get_conf('setchapternewpage'));
    $header .= $setchapternewpage_result;
  }
  my $heading = $self->get_conf('headings');
  if (defined($heading) and (not defined($heading_set)
                             or $heading_set ne $heading)) {
    $header .= _set_headings($self, $heading);
  }

  # only output if different from default
  foreach my $informative_cmdname (sort(keys(%LaTeX_defaults))) {
    my $conf_value = $self->get_conf($informative_cmdname);
    if (defined($conf_value)
        and $conf_value ne $LaTeX_defaults{$informative_cmdname}) {
      $header .= _informative_command_output($self, $informative_cmdname);
    }
  }
  foreach my $informative_cmdname ('documentlanguage', 'pagesizes',
                                               'paragraphindent') {
    my $conf_value = $self->get_conf($informative_cmdname);
    if (defined ($conf_value)) {
      $header .= _informative_command_output($self, $informative_cmdname);
    }
  }

  foreach my $cmdname (sort(keys(%paper_geometry_commands))) {
    if (defined($self->get_conf($cmdname))) {
      $header .= _informative_command_output($self, $cmdname);
    }
  }

  $header .= "\n";
  return $header;
}

sub _begin_document($)
{
  my $self = shift;

  my $result = '';
  $result .= '\begin{document}
';
  my $global_commands;
  if ($self->{'document'}) {
    $global_commands = $self->{'document'}->global_commands_information();
  }

  if ($global_commands
      and ($global_commands->{'titlepage'}
           or $global_commands->{'shorttitlepage'})) {
    $result .= "\n";
    $result .= $front_main_matter_definitions{$documentclass}->{'front'}."\n";
    $result .= _set_headings($self, 'off');

    if ($global_commands->{'titlepage'}) {
      my $element = $global_commands->{'titlepage'};
      # Start a group such that the changes are forgotten when front cover
      # is done.
      # Define glues dimensions that are used in front cover formatting.
      # Taken from Texinfo TeX.
      # FIXME replace \\newskip by \\newlen?
      $result .= "\\begin{titlepage}\n";
      $result .= "\\begingroup
\\newskip\\titlepagetopglue \\titlepagetopglue = 1.5in
\\newskip\\titlepagebottomglue \\titlepagebottomglue = 2pc
\\setlength{\\parindent}{0pt}\n";
      $result .= "% Leave some space at the very top of the page.
    \\vglue\\titlepagetopglue\n";
      $self->{'titlepage_formatting'} = {'in_front_cover' => 1};
      _push_new_context($self, 'titlepage');
      $result .= $self->_convert({'contents' => $element->{'contents'}});
      _pop_context($self);
      $result .= _finish_front_cover_page($self);
      $result .= "\\end{titlepage}\n";
    } else {
      my $element = $global_commands->{'shorttitlepage'};
      my $title_text = _title_font($self, $element);
      $result .= "\\begin{titlepage}\n";
      $result .= "{\\raggedright $title_text}\n";
      # first newpage ends the title page, phantom and second newpage
      # adds a blank page
      $result .= "\\newpage{}\n\\phantom{blabla}\\newpage{}\n";
      $result .= "\\end{titlepage}\n";
    }
  }

  if ($global_commands and $global_commands->{'contents'}
      and not (defined($self->get_conf('CONTENTS_OUTPUT_LOCATION'))
               and $self->get_conf('CONTENTS_OUTPUT_LOCATION') eq 'inline')) {
    my $sections_list;
    if ($self->{'document'}) {
      $sections_list = $self->{'document'}->sections_list();
    }

    if ($sections_list) {
      if ($global_commands->{'titlepage'}
          or $global_commands->{'shorttitlepage'}) {
        $result .= _set_headings($self, 'pagenum');
      }
      $result .= "\\tableofcontents\\newpage\n";
    }
  }

  if ($global_commands
      and ($global_commands->{'titlepage'}
           or $global_commands->{'shorttitlepage'})) {
    $result .= $front_main_matter_definitions{$documentclass}->{'main'}."\n";
    $result .= _set_headings($self, $self->get_conf('headings'));
  }

  return $result;
}

sub _latex_footer {
  return
'\end{document}
';
}

# all the new contexts should be created with that function
# PREFORMATTED_CONTEXT and NON_FLOATING_COMMANDS can be specified, for
# instance if the preformatted context is common with the surrounding
# context, as is the case for floats.
sub _push_new_context($$;$$)
{
  my $self = shift;
  my $context_name = shift;
  my $preformatted_context = shift;
  my $non_floating_commands = shift;

  push @{$self->{'formatting_context'}},
     {
       'code' => [0],
       'context_name' => $context_name,
       'dot_not_end_sentence' => 0,
       'embrac' => [],
       'in_quotation' => 0,
       'in_sectioning_command_heading' => 0,
       'in_skipped_node_top' => 0,
       'in_custom_heading' => 0,
       'math_style' => [],
       'no_eol' => [],
       'nr_table_items_context' => [],
       'preformatted_context' => [],
       # can be ctx_text, ctx_math or ctx_raw
       'text_context' => ['ctx_text'],
       'table_command_format' => [],
       'non_floating_commands'  => [],
     };
  $self->{'formatting_context'}->[-1]->{'preformatted_context'}
    = $preformatted_context
      if (defined($preformatted_context));
  $self->{'formatting_context'}->[-1]->{'non_floating_commands'}
    = [@$non_floating_commands]
      if (defined($non_floating_commands));
}

# for debug
sub _show_top_context_stack($)
{
  my $self = shift;

  my $top_context = $self->{'formatting_context'}->[-1];
  my @all_keys;
  foreach my $key (sort (keys (%$top_context))) {
    my $key_str = $key;
    # keep only the first letters to have something not too long
    $key_str =~ s/(.{4}).*/$1/s;
    my $context_item = $top_context->{$key};
    my $context_item_value;
    if (not defined($context_item)) {
      $context_item_value = 'UNDEF';
    } elsif (ref ($context_item) eq 'ARRAY') {
      $context_item_value = join('|', @$context_item);
    } else {
      $context_item_value = $context_item;
    }
    push @all_keys, "$key_str:$context_item_value";
  }
  return scalar(@{$self->{'formatting_context'}})." ".join('; ', @all_keys);
}

sub _pop_context($)
{
  my $self = shift;
  pop @{$self->{'formatting_context'}};
}

# FIXME should $ ~ be protected?
sub _protect_url($$)
{
  my ($self, $text) = @_;

  $text =~ s/([{}\\#%])/\\$1/g;
  return $text;
}

# in index entries !"@ have special meaning and need to be quoted with "
sub _protect_index_text($)
{
  my $text = shift;
  $text =~ s/([!|"@])/"$1/g;

  # if " is preceded by \ it does not quote the next character unless the
  # \ itself is preceded by ".
  $text =~ s/\\"/"\\"/g;
  return $text;
}

# Protect LaTeX special characters.
sub _protect_text($$)
{
  my ($self, $text) = @_;

  if ($self->{'formatting_context'}->[-1]->{'text_context'}->[-1] eq 'ctx_math') {
    # FIXME are there any special characters to protect in math mode,
    # for instance # and ~?
  } elsif ($self->{'formatting_context'}->[-1]->{'text_context'}->[-1]
             ne 'ctx_raw') {
    # temporarily replace \ with a control character
    $text =~ s/\\/\x08/g;

    # replace the other special characters
    $text =~ s/([#%&{}_\$])/\\$1/g;
    $text =~ s/~/\\~{}/g;
    $text =~ s/\^/\\^{}/g;

    $text =~ s/\x08/\\textbackslash{}/g;

    if ($self->{'formatting_context'}->[-1]->{'code'}->[-1]) {
      # Prevent extra space after punctuation.  (We could use \frenchspacing
      # in the output, but this can break in section titles with hyperref.)
      $text =~ s/([.?!:;,]) /$1\\ /g;

      # In case initial space follows punctuation from a separate element,
      # like @code{@var{?} a}.
      $text =~ s/^ /\\ /g;

      # Under T1 encoding there are several ligatures even in fixed width fonts
      $text =~ s/---/{-}{-}{-}/g;
      $text =~ s/--/{-}{-}/g;
      $text =~ s/``/{`}{`}/g;
      $text =~ s/''/{'}{'}/g;
    }
    # Disable these ligatures everywhere
    $text =~ s/,,/{,}{,}/g;
    $text =~ s/<</{<}{<}/g;
    $text =~ s/>>/{>}{>}/g;
    $text =~ s/\?`/{?}{`}/g;
    $text =~ s/!`/{!}{`}/g;

    if ($self->{'formatting_context'}->[-1]->{'dot_not_end_sentence'}) {
      $text =~ s/\./\.\\@/g;
    }
  }
  return $text;
}

# pagenum heading is not in Texinfo, it is used for the Table of Contents,
# to avoid an ugly Chapter 0 that would be there for the default page
# styles.
sub _set_headings($$)
{
  my ($self, $headings_spec) = @_;

  my $headings_type;
  if ($headings_spec eq 'on' or $headings_spec eq 'pagenum') {
    $headings_type = 'single';
    my $setchapternewpage_spec = $self->get_conf('setchapternewpage');
    if (defined($setchapternewpage_spec)
        and $setchapternewpage_spec eq 'odd') {
      $headings_type = 'double';
    }
    $headings_type .= 'pagenum' if ($headings_spec eq 'pagenum');
  } elsif ($headings_spec eq 'doubleafter') {
    $headings_type = 'double';
  } elsif ($headings_spec eq 'singleafter') {
    $headings_type = 'single';
  } elsif ($headings_spec eq 'off' or $headings_spec eq 'single'
           or $headings_spec eq 'double') {
    $headings_type = $headings_spec;
  }

  if (not defined($headings_type)) {
    confess("_set_headings no type for $headings_spec");
  }

  my $result = '';
  if ($headings_type eq 'off') {
    $result = "\\pagestyle{empty}%\n";
  } else {
    $result = "\\pagestyle{$headings_type}%\n";
  }
  $self->{'page_styles'}->{$headings_type} = 1;
  return $result;
}

my %custom_headings_map = (
  'everyheading' => ['head', ''],
  'everyfooting' => ['foot', ''],
  'evenheading'  => ['head', 'E'],
  'evenfooting'  => ['foot', 'E'],
  'oddheading',  => ['head', 'O'],
  'oddfooting'   => ['foot', 'O'],
);

# this function converts the specification to LaTex and add or
# replace the footing or heading specifications.
sub _set_custom_headings($$$)
{
  my ($self, $cmdname, $headings_spec_element) = @_;
  my ($head_or_foot, $page_spec) = @{$custom_headings_map{$cmdname}};

  my $location_index = -1;
  my @headings = ('', '', '');
  _push_new_context($self, 'custom_heading');
  $self->{'formatting_context'}->[-1]->{'in_custom_heading'} = 1;
  if ($headings_spec_element) {
    foreach my $location_heading_spec (@{$headings_spec_element->{'contents'}}) {
      $location_index++;
      my $heading = $self->_convert($location_heading_spec);
      $heading =~ s/^\s*//;
      $heading =~ s/\s*$//;
      $headings[$location_index] = $heading;
    }
  }
  _pop_context($self);

  my @replaced_specs;
  if ($page_spec eq '') {
    @replaced_specs = ('E', 'O');
  } else {
    @replaced_specs = ($page_spec);
  }
  my $first_custom_heading;
  if (not exists($self->{'custom_heading'})) {
    $first_custom_heading = 1;
    $self->{'custom_heading'} = {$head_or_foot => {}};
  } elsif (!exists($self->{'custom_heading'}->{$head_or_foot})) {
    $self->{'custom_heading'}->{$head_or_foot} = {};
  }
  foreach my $spec (@replaced_specs) {
    $self->{'custom_heading'}->{$head_or_foot}->{$spec} = \@headings;
  }
  return _format_heading_command($self, $first_custom_heading);
}

my @head_foot_order = ('head', 'foot');
my @even_odd_order = (['E', 'bracket'], ['O', 'brace']);
sub _format_heading_command($$)
{
  my $self = shift;
  my $first_custom_heading = shift;

  my $result = '';
  if ($first_custom_heading) {
    $result .= "\\newpagestyle{custom}{%\n";
  } else {
    $result .= "\\renewpagestyle{custom}{%\n";
  }
  foreach my $head_or_foot (@head_foot_order) {
    if (exists($self->{'custom_heading'}->{$head_or_foot})) {
      my $head_or_foot_spec = $self->{'custom_heading'}->{$head_or_foot};
      $result .= '\set' . $head_or_foot;
      foreach my $even_odd_and_separator (@even_odd_order) {
        my ($even_or_odd, $separator) = @{$even_odd_and_separator};
        my $headings;
        if (exists($head_or_foot_spec->{$even_or_odd})) {
          $headings = $head_or_foot_spec->{$even_or_odd};
        } else {
          $headings = ['', '', ''];
        }
        foreach my $heading (@{$headings}) {
          if ($separator eq 'bracket') {
            $result .= '['.$heading.']';
          } else {
            $result .= '{'.$heading.'}';
          }
        }
        $result .= "%\n";
      }
    }
  }
  $result .= "}%\n";
  $result .= "\\pagestyle{custom}%\n";
  return $result;
}


# to change the chapter we substitute in the \chapter command.
# REMARK it is fragile as it depends on the LaTeX codes. It is also
# most probably specific of the documentclass.  It is present in both
# report and book document classes in 2021
my $odd_chapter_new_page_code = '\if@openright\cleardoublepage\else\clearpage\fi';
my $default_chapter_page_code = $odd_chapter_new_page_code;
# To make sure that we substitute the right code, we add a
# distinctive code that does nothing.  This is needed when
# code is simply removed or when simple code is substituted.
my $chapter_new_page_marking_placeholder
   = '\Texinfoplaceholder{setchapternewpage placeholder}';

my %setchapternewpage_new_page_spec_code = (
  'on' => $chapter_new_page_marking_placeholder.'\clearpage',
  'off' => $chapter_new_page_marking_placeholder.'',
  'odd' => $odd_chapter_new_page_code,
);

# Note that the code should probably be different if the default code
# was not distinctive enough
sub _set_chapter_new_page($$)
{
  my ($self, $setchapternewpage_spec) = @_;

  my $substituted_code;
  if (defined($self->{'prev_chapter_new_page_substitution'})) {
    $substituted_code = $self->{'prev_chapter_new_page_substitution'};
  } else {
    $substituted_code = $default_chapter_page_code;
  }
  my $new_code = $setchapternewpage_new_page_spec_code{$setchapternewpage_spec};

  my $result = '';
  # do not substitute if it is the same, for instance
  # if setting the same as document class default or setting twice
  if ($new_code ne $substituted_code) {
    $result .= '\makeatletter
\patchcmd{\chapter}{'.$substituted_code.'}{'.$new_code.'}{}{}
\makeatother
';
  }

  my $heading_set = 'on';
  if ($setchapternewpage_spec eq 'off') {
    $heading_set = 'off';
  }
  $result .= _set_headings($self, $heading_set);

  $self->{'prev_chapter_new_page_substitution'} = $new_code;

  return $result, $heading_set;
}

my %small_font_preformatted_commands;
foreach my $small_font_preformatted_command (
     grep {/^small/} keys(%preformatted_commands)) {
  $small_font_preformatted_commands{$small_font_preformatted_command} = 1;
}

sub _open_preformatted($$)
{
  my $self = shift;
  my $element = shift;

  my $command
      = $self->{'formatting_context'}->[-1]->{'preformatted_context'}->[-1];

  if ($preformatted_code_commands{$command}) {
    push @{$self->{'formatting_context'}->[-1]->{'code'}}, 1;
  }

  my $result = '';
  $result .= '\\begin{Texinfopreformatted}%'."\n";
  $self->{'fixed_width_environments'}->{'Texinfopreformatted'} = 1;
  # The % comments out the newline to avoid extra vertical space.

  if ($preformatted_code_commands{$command}) {
    $result .= '\\ttfamily ';
  }
  if ($small_font_preformatted_commands{$command}) {
    $result .= "\\$small_font_size ";
  }
  return $result;
}

sub _close_preformatted($$)
{
  my $self = shift;
  my $element = shift;

  my $command
     = $self->{'formatting_context'}->[-1]->{'preformatted_context'}->[-1];
  if ($preformatted_code_commands{$command}) {
    pop @{$self->{'formatting_context'}->[-1]->{'code'}};
  }
  return '\\end{Texinfopreformatted}'."\n";
}

sub _open_preformatted_command($$)
{
  my $self = shift;
  my $command = shift;

  push @{$self->{'formatting_context'}->[-1]->{'preformatted_context'}},
         $command;
  return '';
}

sub _close_preformatted_command($$)
{
  my $self = shift;
  my $command = shift;

  my $old_context
    = pop @{$self->{'formatting_context'}->[-1]->{'preformatted_context'}};
  die if ($old_context ne $command);
  return '';
}

sub _open_preformatted_stack($$)
{
  my $self = shift;
  my $stack = shift;

  my $result = '';
  foreach my $preformatted_command (@$stack) {
    $result .= _open_preformatted_command($self, $preformatted_command);
  }
  return $result;
}

sub _close_preformatted_stack($$)
{
  my $self = shift;
  my $stack = shift;

  my $result = '';
  foreach my $preformatted_command (reverse @$stack) {
    $result .= _close_preformatted_command($self, $preformatted_command);
  }
  return $result;
}

sub _title_font($$)
{
  my $self = shift;
  my $element = shift;

  if ($element->{'args'} and $element->{'args'}->[0]->{'contents'}) {
    # in Texinfo TeX seems a bit smaller, but LARGE seems too small
    my $result = "{\\huge \\bfseries ";
    $result .= _convert($self, $element->{'args'}->[0]);
    $result .= '}';
    return $result;
  }
  return '';
}

sub _set_environment_options($$$)
{
  my $self = shift;
  my $command = shift;
  my $element = shift;

  if (exists($LaTeX_environment_options{$command})) {
   my $option = $LaTeX_environment_options{$command};
   if ($command eq 'cartouche'
       and $element->{'args'} and $element->{'args'}->[0]
       and $element->{'args'}->[0]->{'contents'}
       and @{$element->{'args'}->[0]->{'contents'}}) {
      $option
        = {'mdframed' => $option->{'mdframed'}
                      . ', frametitle={' . $self->_convert({'contents'
                           => $element->{'args'}->[0]->{'contents'}}) .'}'};
    }
    return $option;
  }

  if ($command eq 'enumerate') {
    my $environment = $LaTeX_environment_commands{$command}[0];
    if ($element->{'extra'} and
        exists($element->{'extra'}->{'enumerate_specification'})) {
      my $specification = $element->{'extra'}->{'enumerate_specification'};
      if ($specification eq 'a') {
        return {$environment => 'label=\alph*.'};
      } elsif ($specification eq 'A') {
        return {$environment => 'label=\Alph*.'};
      }
      if ($specification =~ /^[a-z]+$/) {
        return {$environment
             => 'label=\alph*.,start='.(ord($specification) - ord('a') + 1)};
      } elsif ($specification =~ /^[A-Z]+$/) {
        return {$environment
             => 'label=\Alph*.,start='.(ord($specification) - ord('A') + 1)};
      } else {
        return {$environment => "start=$specification"};
      }
    }
  } elsif ($command eq 'itemize') {
    my $environment = $LaTeX_environment_commands{$command}[0];
    if ($element->{'extra'} and $element->{'extra'}->{'command_as_argument'}
        and $element->{'extra'}->{'command_as_argument'}->{'cmdname'} eq 'w') {
      # the result with \hbox{} would probably have been the same,
      # but using an empty label is more consistent with the Texinfo manual
      return {$environment => 'label={}'};
    } elsif ($element->{'args'} and $element->{'args'}->[0]->{'contents'}) {
      # NOTE when @itemize is in a preformatted environment (@example...),
      # we are not in a preformatted type here, such that the conversion
      # does not take into account the preformatted environment.  Ok or best.
      my $itemize_label = _convert($self, $element->{'args'}->[0]);
      if ($itemize_label ne '') {
        return {$environment => 'label='.$itemize_label};
      }
    }
  }
  return undef;
}

sub _xtable_description_command_format($$)
{
  my $self = shift;
  my $element = shift;

  if ($element->{'extra'}
      and $element->{'extra'}->{'command_as_argument'}) {
    my $command_as_argument
      = $element->{'extra'}->{'command_as_argument'}->{'cmdname'};
    $command_as_argument = 'code' if ($command_as_argument eq 'kbd'
                                      and _kbd_code_style($self));
    if (exists($description_command_format{$command_as_argument})
        and $description_command_format{$command_as_argument} ne '') {
      # gather for outputting in the preamble if associated to a new command
      if (exists($description_command_new_commands{$command_as_argument})) {
        $self->{'description_format_commands'}->{$command_as_argument} = 1;
      } elsif ($style_brace_format_command_new_commands{'cmd_text'}
                                                     ->{$command_as_argument}) {
        $self->{'style_brace_format_commands'}->{'cmd_text'}
                                                 ->{$command_as_argument} = 1;
      }
      return $description_command_format{$command_as_argument}
    }
  }
  return undef;
}

sub _kbd_code_style($)
{
  my $self = shift;
  my $kbdinputstyle = $self->get_conf('kbdinputstyle');
  return (defined($kbdinputstyle)
          and ($kbdinputstyle eq 'code'
            or ($kbdinputstyle eq 'example'
              and (not (scalar(@{$self->{'formatting_context'}->[-1]
                                                   ->{'preformatted_context'}})
                        and $preformatted_code_commands{
                                       $self->{'formatting_context'}->[-1]
                                         ->{'preformatted_context'}->[-1]})))));
}

sub _finish_front_cover_page($)
{
  my $self = shift;
  my $result = '';
  if ($self->{'titlepage_formatting'}
      and $self->{'titlepage_formatting'}->{'in_front_cover'}) {
    # add a rule if there was a @title (same as in Texinfo TeX)
    if ($self->{'titlepage_formatting'}->{'title'}) {
      delete $self->{'titlepage_formatting'}->{'title'};
      $result .= '\vskip4pt \hrule height 2pt width \hsize
  \vskip\titlepagebottomglue
';
    }
    $result .= "\\endgroup\n";
    $self->{'titlepage_formatting'}->{'in_front_cover'} = 0;
  }
  return $result;
}

sub _tree_anchor_label {
  my $node_content = shift;

  my $label = Texinfo::Convert::NodeNameNormalization::convert_to_identifier
    ({'contents' => $node_content});
  return "anchor:$label";
}

my %LaTeX_see_index_commands_text = (
  'seeentry' => 'see',
  'seealso' => 'seealso'
);

sub _index_entry($$)
{
  my $self = shift;
  my $element = shift;
  if ($element->{'extra'} and $element->{'extra'}->{'index_entry'}) {
    my $indices_information;
    if ($self->{'document'}) {
      $indices_information = $self->{'document'}->indices_information();
    }

    my ($entry, $index_info)
     = Texinfo::Common::lookup_index_entry($element->{'extra'}->{'index_entry'},
                                           $indices_information);
    my $entry_index_name = $entry->{'index_name'};
    my $index_name = $entry_index_name;
    if ($index_info->{'merged_in'}) {
      $index_name
        = $index_info->{'merged_in'};
    }
    my $in_code = 0;
    if ($index_info->{'in_code'}) {
      $in_code = 1;
    }
    my @subindex_commands = ($element);
    my $current_element = $element;
    while ($current_element->{'extra'}
      and $current_element->{'extra'}->{'subentry'}) {
      $current_element = $current_element->{'extra'}->{'subentry'};
      push @subindex_commands, $current_element;
    }
    _push_new_context($self, 'index_entry');
    $self->{'formatting_context'}->[-1]->{'index'} = 1;
    my @result;
    foreach my $subindex_command (@subindex_commands) {
      my $content
         = Texinfo::Common::index_content_element($subindex_command, 1);
      if ($in_code) {
        push @{$self->{'formatting_context'}->[-1]->{'code'}}, 1;
      }
      my $index_entry = _convert($self, $content);
      if ($in_code) {
        pop @{$self->{'formatting_context'}->[-1]->{'code'}};
      }
      # always setup a string to sort with as we may use commands
      if ($in_code) {
        Texinfo::Convert::Text::set_options_code(
          $self->{'index_formatting_text_options'});
      }
      # NOTE in XS code, the $self->{'index_formatting_text_options'}
      # argument is ignored, instead the $self converter is used to find C
      # text options data setup by setup_index_entry_keys_formatting.
      my $sort_string
           = Texinfo::Indices::index_entry_element_sort_string(
                                          $self, $entry,
                                          $subindex_command,
                            $self->{'index_formatting_text_options'}, 1);
      my $result = '';
      if (defined($sort_string)) {
        # | in sort key breaks with hyperref
        $sort_string =~ s/\|//g;
        $result = _protect_text($self, $sort_string);
        $result =~ s/\\[{}]//g; # cannot have unmatched braces in index entry
        $result = _protect_index_text($result).'@';
      }
      if ($in_code) {
        Texinfo::Convert::Text::reset_options_code(
                                 $self->{'index_formatting_text_options'});
        $result .= "\\texttt{" . _protect_index_text($index_entry) . "}";
      } else {
        $result .= _protect_index_text($index_entry);
      }
      push @result, $result;
    }
    my $seeresult = '';
    foreach my $seecommand (('seeentry', 'seealso')) {
      if ($element->{'extra'}->{$seecommand}
          and $element->{'extra'}->{$seecommand}->{'args'}->[0]) {
        my $seeconverted = _convert($self,
                 $element->{'extra'}->{$seecommand}->{'args'}->[0]);
        $seeresult = '|'.$LaTeX_see_index_commands_text{$seecommand}.'{'
                   .$seeconverted.'}';
         last;
      }
    }
    _pop_context($self);
    return "\\index[$index_name]{".join('!',@result).$seeresult."}%\n";
  }
  return '';
}

# turn off embrac for an opening @-command
sub _stop_embrac
{
  my $self = shift;
  my $result = shift;
  my $did_stop_embrac = 0;

  if ($self->{'formatting_context'}->[-1]->{'embrac'}
      and $self->{'formatting_context'}->[-1]->{'embrac'}->[-1]
      and $self->{'formatting_context'}->[-1]->{'embrac'}->[-1]->{'status'} == 1) {
    $result .= '\EmbracOff{}';
    $self->{'formatting_context'}->[-1]->{'embrac'}->[-1]->{'status'} = 0;
    $did_stop_embrac = 1;
  }
  return ($result, $did_stop_embrac)
}

# turn on embrac, should be after closing an @-command that lead
# to turning off embrac
sub _restart_embrac_if_needed
{
  my $self = shift;
  my $result = shift;
  my $did_stop_embrac = shift;

  if ($did_stop_embrac) {
    $self->{'formatting_context'}->[-1]->{'embrac'}->[-1]->{'status'} = 1;
    $result .= '\EmbracOn{}';
  }
  return $result;
}

sub _include_file_name($$)
{
  my $self = shift;
  my $source_mark = shift;
  my $file_name;
  if ($source_mark->{'element'} and $source_mark->{'element'}->{'args'}
      and scalar (@{$source_mark->{'element'}->{'args'}})) {
    _push_new_context($self, 'include');
    $file_name = $self->_convert($source_mark->{'element'}->{'args'}->[0]);
    _pop_context($self);
    $file_name = undef if ($file_name !~ /\S/);
  }
  return $file_name;
}

sub _convert_def_line($$)
{
  my $self = shift;
  my $element =shift;

  my $result = '';
  my ($category_element, $class_element,
      $type_element, $name_element, $arguments)
        = Texinfo::Convert::Utils::definition_arguments_content($element);
  if (defined($category_element) or defined($class_element)
      or defined($type_element) or defined($name_element)) {
    my $command;
    if ($Texinfo::Common::def_aliases{$element->{'extra'}->{'def_command'}}) {
      $command
       = $Texinfo::Common::def_aliases{$element->{'extra'}->{'def_command'}};
    } else {
      $command = $element->{'extra'}->{'def_command'};
    }

    my $deftypefnnewline = ($self->get_conf('deftypefnnewline')
           and $self->get_conf('deftypefnnewline') eq 'on'
           and ($command eq 'deftypefn' or $command eq 'deftypeop'));

    my $def_space = ' ';
    if ($element->{'extra'}->{'omit_def_name_space'}) {
      $def_space = '';
    }

    my $converted_category;
    my $category
      = Texinfo::Convert::Utils::definition_category_tree($self, $element);
    if (defined($category)) {
      # category is converted in normal text context
      my $converted = _convert($self, $category);
      $converted_category = "[$converted]";
    }

    $self->{'packages'}->{'tabularx'} = 1;
    my $def_line_result = '';
    # First column (X) is as wide as possible, second column (r) is for
    # category.  @{} removes space at left side of table.
    # Without \noindent, a def* after a section beginning is indented
    $def_line_result .= "\\noindent\\begin{tabularx}{\\linewidth}{\@{}Xr}\n";

    # This stops the definition line overlapping the category in
    # case it is hard to break the first line.
    $def_line_result .= "\\rightskip=5em plus 1 fill ";

    # In case definition "line" doesn't fit on one line.
    $def_line_result .= "\\hangindent=2em ";

    # turn off hyphenation
    $def_line_result .= "\\hyphenpenalty=10000\n";

    $def_line_result .= '\texttt{';

    # no end of line in tabularx
    push @{$self->{'formatting_context'}->[-1]->{'no_eol'}}, 1;
    # the def* line except for the category is converted in code context
    push @{$self->{'formatting_context'}->[-1]->{'code'}}, 1;

    if ($type_element) {
      $def_line_result .= _convert($self, $type_element);
      if ($deftypefnnewline) {
       if (defined($converted_category)) {
          $def_line_result .= "}& $converted_category\\\\\n\\texttt{"
        } else {
          $def_line_result .= "}\\\\\n\\texttt{";
        }
      } else {
        $def_line_result .= ' ';
      }
    }
    $def_line_result .= _convert($self, $name_element) if $name_element;
    # will contain the command names that have been made known to
    # embrac, like texttt and need to have the symbol undefined
    # such that they can be redefined later
    my $known_embrac_commands;
    if ($arguments) {
      $def_line_result .= $def_space;
      if ($Texinfo::Common::def_no_var_arg_commands{$command}) {
        $def_line_result .= _convert($self, $arguments);
      } else {
        $self->{'packages'}->{'embrac'} = 1;
        # we want slanted roman and not slanted typewriter, including
        # ligatures, as if @r{@slanted{...}} had been used, so output
        # \textnormal and push 0 on 'code' context.
        $def_line_result .= '\EmbracOn{}\textnormal{\textsl{';
        push @{$self->{'formatting_context'}->[-1]->{'code'}}, 0;
        push @{$self->{'formatting_context'}->[-1]->{'embrac'}},
          {'status' => 1, 'made_known' => {}};

        $def_line_result .= _convert($self, $arguments);

        # \EmbracOff{} is probably not really needed here as \EmbracOn{}
        # should be local to the texttt
        $def_line_result .= '}}\EmbracOff{}'; # \textnormal \textsl
        pop @{$self->{'formatting_context'}->[-1]->{'code'}};
        my $closed_embrac
          = pop @{$self->{'formatting_context'}->[-1]->{'embrac'}};
        if (scalar(keys(%{$closed_embrac->{'made_known'}}))) {
          $known_embrac_commands
            = [sort(keys(%{$closed_embrac->{'made_known'}}))]
        }
      }
    }

    pop @{$self->{'formatting_context'}->[-1]->{'code'}};
    $def_line_result .= '}'; # \texttt
    pop @{$self->{'formatting_context'}->[-1]->{'no_eol'}};

    $def_line_result .= "& $converted_category\n"
      if (defined($converted_category) and not $deftypefnnewline);

    $def_line_result .= "\\end{tabularx}\n";
    # Add commands associated to embrac, prepended to be before tabularx.
    # If done in tabularx there are redefinition errors, cells are
    # probably expanded more than once.
    #
    # also postpend undefine symbols associated with commands that have
    # been made known to embrac, such that they can be redefined later
    #
    # TODO currently setting EmbracMakeKnown twice leads to an error.
    # this is triggered by the tests layout formatting_latex test.
    # So do not use it for now.
    if (0 and defined($known_embrac_commands)) {
      $def_line_result .= "\\ExplSyntaxOn%\n";
      foreach my $defined_style_embrac (@{$known_embrac_commands}) {
        # before the tabularx
        $def_line_result = '\EmbracMakeKnown{'.$defined_style_embrac.'}'
                           ."%\n" .$def_line_result;
        $def_line_result
          .= '\cs_undefine:N{\embrac_'.$defined_style_embrac.':nn}'.
    '\cs_undefine:N{\embrac_orig_'.$defined_style_embrac.':n}'.
    '\cs_undefine:N{\__embrac_'.$defined_style_embrac.':n}%
';
      }
      $def_line_result .= "\\ExplSyntaxOff%\n";
    }
    $result .= "\n".$def_line_result;
  }
  $result .= "\n";
  $result .= _index_entry($self, $element);
}

sub _convert($$);

# Convert the Texinfo tree under $ELEMENT
sub _convert($$)
{
  my ($self, $element) = @_;

  if ($self->{'debug'}) {
    print STDERR "CONVLTX "
         .Texinfo::Common::debug_print_element($element)."\n";
    if ($self->{'debug'} > 4) {
      print STDERR "    CTX "._show_top_context_stack($self)."\n";
    }
  }

  my $result = '';

  if ($self->{'collected_includes'}) {
    if ($element->{'source_marks'}) {
      foreach my $source_mark (@{$element->{'source_marks'}}) {
        if ($source_mark->{'sourcemark_type'} eq 'include') {
          my $file_name;
          if ($source_mark->{'status'} eq 'start') {
            my $start_counter = $source_mark->{'counter'};
            $file_name = _include_file_name($self, $source_mark);
            push @{$self->{'collected_includes'}},
                    [$start_counter, $file_name];
          } else {
            my $end_counter = $source_mark->{'counter'};
            if (! scalar(@{$self->{'collected_includes'}})
                or $self->{'collected_includes'}->[-1]->[0] != $end_counter) {
              print STDERR "BUG: unsync include files: $end_counter\n";
              while (scalar(@{$self->{'collected_includes'}})
               and $self->{'collected_includes'}->[-1]->[0] != $end_counter) {
                my $include_file_info = pop @{$self->{'collected_includes'}};
                print STDERR "   $include_file_info->[0]: $include_file_info->[1]\n";
              }
            }
            if (scalar(@{$self->{'collected_includes'}})) {
              my $revious_include_info = pop @{$self->{'collected_includes'}};
            }
            if (scalar(@{$self->{'collected_includes'}})) {
              $file_name = $self->{'collected_includes'}->[-1]->[1];
            } else {
              # top-level
              $file_name = '';
            }
          }
          if (defined($file_name)) {
            $result .= "\\renewcommand{\\Texinfotheinclude}{$file_name}%\n";
          }
        }
      }
    }
  }

  my $type = $element->{'type'};
  my $cmdname = $element->{'cmdname'};

  if ((defined($type) and $self->{'ignored_types'}->{$type})
      # ignore command as argument inserted in order to use the default
      # setting for @itemize if there is no argument
      or ($element->{'info'} and $element->{'info'}->{'inserted'}
          and $element->{'parent'} and $element->{'parent'}->{'parent'}
          and $element->{'parent'}->{'parent'}->{'cmdname'}
          and $element->{'parent'}->{'parent'}->{'cmdname'} eq 'itemize')
       or (defined($cmdname)
            and ($self->{'ignored_commands'}->{$cmdname}
                 or ($Texinfo::Commands::brace_commands{$cmdname}
                     and $Texinfo::Commands::brace_commands{$cmdname} eq 'inline'
                     and $cmdname ne 'inlinefmtifelse'
                     and (($inline_format_commands{$cmdname}
                          and (!$element->{'extra'}
                               or !$element->{'extra'}->{'format'}
                               or !$self->{'expanded_formats'}
                                      ->{$element->{'extra'}->{'format'}}))
                         or (!$inline_format_commands{$cmdname}
                             and (!$element->{'extra'}
                     or !defined($element->{'extra'}->{'expand_index'})))))))) {
    return $result;
  }

  if ($self->{'formatting_context'}->[-1]->{'in_skipped_node_top'}) {
    my $node_element;
    if (defined($cmdname) and $cmdname eq 'node') {
      $node_element = $element;
    } elsif (defined($cmdname) and $cmdname eq 'part' and $element->{'extra'}
             and $element->{'extra'}->{'part_following_node'}) {
      $node_element = $element->{'extra'}->{'part_following_node'};
    }
    if (($node_element
         and not ($node_element->{'extra'}
                  and $node_element->{'extra'}->{'normalized'}
                  and $node_element->{'extra'}->{'normalized'} eq 'Top'))
         or (defined($type) and $type eq 'ignored_top_node_paragraph')
        or (defined($cmdname) and $cmdname eq 'part')) {
      $self->{'formatting_context'}->[-1]->{'in_skipped_node_top'} = 0;
    } elsif (not ((defined($cmdname)
                   and ($informative_commands{$cmdname}
                        or $sectioning_heading_commands{$cmdname}
                        or $cmdname eq 'float'
                        or $cmdname eq 'anchor'))
                   or ($type and $type eq 'paragraph'))) {
      return '';
    }
  }

  # in ignorable spaces, keep only form feeds.
  if ($type and $self->{'ignorable_space_types'}->{$type}) {
    if ($type eq 'spaces_after_close_brace') {
      if ($element->{'text'} =~ /\f/) {
        $result = '\par{}';
      }
    }
    return $result;
  }

  if ($type and ($type eq 'empty_line')) {
    if ($element->{'text'} =~ /\f/) {
      $result .= '\par{}';
    }
    return $result."\n";
  }

  # process text
  if (defined($element->{'text'})) {
    $result .= _protect_text($self, $element->{'text'});
    return $result;
  }

  # for displaymath that closes the preformatted
  my $preformatted_to_reopen;
  if ($cmdname) {
    my $unknown_command;
    my $command_format_context = 'cmd_text';
    if ($self->{'formatting_context'}->[-1]->{'text_context'}->[-1] eq 'ctx_math') {
      $command_format_context = 'cmd_math';
    }
    my $did_stop_embrac;
    if (defined($nobrace_symbol_text{$cmdname})) {
      if ($cmdname eq ':') {
        if ($command_format_context ne 'cmd_math') {
          $result .= "\\\@";
        }
      } elsif ($cmdname eq '*') {
        if ($command_format_context ne 'cmd_math') {
          if ($self->{'formatting_context'}->[-1]->{'no_eol'}
              and $self->{'formatting_context'}->[-1]->{'no_eol'}->[-1]) {
            # in tabularx in @def* we ignore @*
            $result .= ' ';
          } else {
            # FIXME \leavevmode{} is added to avoid
            # ! LaTeX Error: There's no line here to end.
            # but it is not clearly correct
            $result .= "\\leavevmode{}\\\\";
            #$result = "\\linebreak[4]\n";
          }
        } else {
          if ($self->{'formatting_context'}->[-1]->{'math_style'}->[-1]
              eq 'one-line') {
            $result .= "";
          } else {
            # no such case for now, but could be in the future
            $result .= "\\\\";
          }
        }
      } elsif ($cmdname eq '.' or $cmdname eq '?' or $cmdname eq '!') {
        if ($command_format_context ne 'cmd_math') {
          $result .= "\\\@";
        }
        $result .= $cmdname;
      } elsif ($cmdname eq ' ' or $cmdname eq "\n" or $cmdname eq "\t") {
        $result .= "\\ {}";
      } elsif ($cmdname eq '-') {
        $result .= "\\-{}";

      } elsif ($cmdname eq '{' or $cmdname eq '}') {
        # Index entries need balanced braces so we can't use \{ and \}.
        if ($self->{'formatting_context'}->[-1]->{'index'}) {
          if ($cmdname eq '{') {
            if ($self->{'formatting_context'}->[-1]->{'text_context'}->[-1]
                 eq 'ctx_math') {
                $result .= '\\lbrace{}';
            } else {
                $result .= '\\textbraceleft{}';
            }
          } elsif ($cmdname eq '}') {
            if ($self->{'formatting_context'}->[-1]->{'text_context'}->[-1]
                 eq 'ctx_math') {
                $result .= '\\rbrace{}';
            } else {
                $result .= '\\textbraceright{}';
            }
          }
        } else {
          # always protect, even in math mode
          $result .= "\\$cmdname";
        }
      } elsif ($cmdname eq '\\'
             and $self->{'formatting_context'}->[-1]->{'text_context'}->[-1]
                 eq 'ctx_math') {
        $result .= '\\backslash{}';
      } else {
        $result .= _protect_text($self, $nobrace_symbol_text{$cmdname});
      }
      return $result;
    } elsif (exists($brace_no_arg_commands{$cmdname})) {
      my $converted_command = $cmdname;
      if ($cmdname eq 'click' and $element->{'extra'}
        and exists($element->{'extra'}->{'clickstyle'})) {
        $converted_command = $element->{'extra'}->{'clickstyle'};
      }
      if ($self->{'output_characters'}) {
        my $encoding = $self->{'output_encoding_name'};
        if ($letter_no_arg_commands{$converted_command}) {
          my $conversion
           = Texinfo::Convert::Unicode::brace_no_arg_command($converted_command,
                                                             $encoding);
          if (defined($conversion)) {
            $result .= $conversion;
            return $result;
          }
        }
      }
      if (exists($LaTeX_no_arg_brace_commands{$command_format_context}
                                                     ->{$converted_command})) {
        if ($converted_command eq 'error'
            and $self->{'formatting_context'}->[-1]
                                         ->{'in_sectioning_command_heading'}) {
          # in a sectioning command, the contents bookmark is also generated,
          # and some commands do not play well with the contents bookmark.
          # In particular \fbox.
          # \texorpdfstring allows to specify a different output for
          # the string in contents bookmark.
          #
          # TODO Note that other commands than @error are not perfect in
          # contents bookmarks, in particular all the commands formatted
          # in math disappear.  However the other commands have no clear
          # string representations, being removed in the contents bookmark
          # strings is not so bad until a better solution is found
          #
          # See also
          # https://github.com/latex3/hyperref/issues/207#issuecomment-920712424
          $result .= '\texorpdfstring{'.
            $LaTeX_no_arg_brace_commands{$command_format_context}
                                                          ->{$converted_command}
            # TODO translation
            .'}{error}'
        } else {
          $result .= $LaTeX_no_arg_brace_commands{$command_format_context}
                                                         ->{$converted_command};
        }
      } else {
        die "BUG: unknown brace_no_arg_commands $cmdname $converted_command\n";
      }
      return $result;
    # commands with braces
    } elsif ($accent_commands{$cmdname}) {
      if ($self->{'output_characters'}) {
        my $encoding = $self->{'output_encoding_name'};
        my $sc;
        my $accented_text
           = Texinfo::Convert::Text::text_accents($element, $encoding, $sc);
        $result .= _protect_text($self, $accented_text);
      } else {
        my $accent_arg = '';

        if ($LaTeX_accent_commands{$command_format_context}->{$cmdname}) {
          $result
           .= "\\$LaTeX_accent_commands{$command_format_context}->{$cmdname}\{";
          if ($element->{'args'}) {
            $accent_arg = _convert($self, $element->{'args'}->[0]);
          }
          $result .= $accent_arg;
          $result .= '}';
        } elsif ($cmdname eq 'dotless') {
          if ($element->{'args'}) {
            $accent_arg = _convert($self, $element->{'args'}->[0]);
          }
          if ($accent_arg eq 'i' or $accent_arg eq 'j') {
            if ($command_format_context eq 'cmd_math') {
              $result .= "\\${accent_arg}math{}";
            } else {
              $result .= "\\${accent_arg}{}";
            }
          } else {
            # should be an error, but we do not care, it is better if it is
            # handled during parsing
            $result .= _protect_text($self, $accent_arg);
          }
          return $result;
        # accent without math mode command, use slanted text
        } elsif ($command_format_context eq 'cmd_math'
                 and $LaTeX_accent_commands{'cmd_text'}->{$cmdname}) {
          $result
               .= "\\textsl{\\$LaTeX_accent_commands{'cmd_text'}->{$cmdname}\{";
          # we do not want accents within to be math accents
          if ($element->{'args'}) {
            push @{$self->{'formatting_context'}->[-1]->{'text_context'}},
                 'ctx_text';
            $accent_arg = _convert($self, $element->{'args'}->[0]);
            my $old_context
              = pop @{$self->{'formatting_context'}->[-1]->{'text_context'}};
          }
          $result .= $accent_arg;
          $result .= '}}';
        }
      }
      return $result;
    } elsif (exists($LaTeX_style_brace_commands{'cmd_text'}->{$cmdname})
         or ($element->{'type'}
             and $element->{'type'} eq 'definfoenclose_command')) {
      my $did_stop_embrac = 0;
      ($result, $did_stop_embrac) = _stop_embrac($self, $result)
         if ($cmdname eq 'r');
      my $formatted_cmdname;
      if ($cmdname eq 'kbd' and _kbd_code_style($self)) {
        # use code for kbd formatting if needed
        $formatted_cmdname = 'code';
      } else {
        $formatted_cmdname = $cmdname;
      }
      if ($brace_code_commands{$cmdname}) {
        push @{$self->{'formatting_context'}->[-1]->{'code'}}, 1;
      } elsif ($roman_style_commands{$cmdname}) {
        push @{$self->{'formatting_context'}->[-1]->{'code'}}, 0;
      }
      if ($self->{'quotes_map'}->{$formatted_cmdname}) {
        $result .= $self->{'quotes_map'}->{$formatted_cmdname}->[0];
      }
      my $command_format_context = $command_format_context;
      # gather for outputting in the preamble if associated to a new command
      if ($style_brace_format_command_new_commands{$command_format_context}
                                                     ->{$formatted_cmdname}) {
        $self->{'style_brace_format_commands'}->{$command_format_context}
                                                     ->{$formatted_cmdname} = 1;
      }
      if ($LaTeX_style_brace_commands{$command_format_context}
                                                       ->{$formatted_cmdname}) {
        my $LaTeX_style_command
          = $LaTeX_style_brace_commands{$command_format_context}
                                                 ->{$formatted_cmdname};
        if ($need_known_embrac{$LaTeX_style_command}
            and $self->{'formatting_context'}->[-1]->{'embrac'}
            and $self->{'formatting_context'}->[-1]->{'embrac'}->[-1]
            and $self->{'formatting_context'}->[-1]->{'embrac'}->[-1]->{'status'} == 1) {
          my $defined_style_embrac = $need_known_embrac{$LaTeX_style_command};
          if (not $self->{'formatting_context'}->[-1]->{'embrac'}->[-1]
                ->{'made_known'}->{$defined_style_embrac}) {
            $self->{'formatting_context'}->[-1]->{'embrac'}->[-1]
                       ->{'made_known'}->{$defined_style_embrac} = 1;
          }
        }
        $result .= "$LaTeX_style_command\{";
      }
      if ($element->{'args'}) {
        $result .= _convert($self, $element->{'args'}->[0]);
      }
      if ($LaTeX_style_brace_commands{$command_format_context}
                                                   ->{$formatted_cmdname}) {
        $result .= '}';
      }
      if ($self->{'quotes_map'}->{$formatted_cmdname}) {
        $result .= $self->{'quotes_map'}->{$formatted_cmdname}->[1];
      }
      if ($brace_code_commands{$cmdname}) {
        pop @{$self->{'formatting_context'}->[-1]->{'code'}};
      } elsif ($roman_style_commands{$cmdname}) {
        pop @{$self->{'formatting_context'}->[-1]->{'code'}};
      }
      $result = _restart_embrac_if_needed($self, $result, $did_stop_embrac);
      return $result;
    } elsif ($def_line_commands{$cmdname}) {
      $result .= _convert_def_line($self, $element);
    } elsif ($cmdname eq 'dmn') {
      $result .= '\\thinspace ';
      if ($element->{'args'}) {
        $result .= _convert($self, $element->{'args'}->[0]);
      }
    } elsif ($cmdname eq 'verb') {
      # NOTE \verb is forbidden in other macros in LaTeX.  We do
      # not enforce this constraint here, nor warn.  Checking
      # whether we are in another LaTeX macro would probably be a pain.
      # It should be ok, though, as it is described as an error in the manual:
      #   It is not reliable to use @verb inside other Texinfo constructs
      my $delim;
      if ($element->{'info'}
          and defined($element->{'info'}->{'delimiter'})) {
        $delim = $element->{'info'}->{'delimiter'};
      } else {
        # delimiter also tried below
        $delim = '|';
      }
      my $contents = '';
      my @lines;

      push @{$self->{'formatting_context'}->[-1]->{'text_context'}}, 'ctx_raw';
      if ($element->{'args'}) {
        $contents = _convert($self, $element->{'args'}->[0]);
        @lines = split /\n/, $contents, -1;
      }
      my $old_context
         = pop @{$self->{'formatting_context'}->[-1]->{'text_context'}};
      die if ($old_context ne 'ctx_raw');

      my @lines_out;
    LINE:
      for my $line (@lines) {
        # Check delimiter is not in contents.  If it is, try other characters.
        for my $char ($delim, '|', '!', ':', '@') {
          if (index($line, $char) == -1) {
            push @lines_out, "\\verb$char$line$char";
            next LINE;
          }
        }
        $self->converter_line_warn(
           sprintf(__("\\verb delimiter `%s' (for LaTeX) used in text `%s'"),
                      $delim, $line),
           $element->{'source_info'});
        push @lines_out, "\\verb$delim$delim";
      }
      $result .= join "\\\\\n", @lines_out;
      return $result;
    } elsif ($cmdname eq 'image') {
      if ($element->{'args'}
          and $element->{'args'}->[0]->{'contents'}) {
        # distinguish text basefile used to find the file and
        # converted basefile with special characters escaped
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

        # warn if no file is found, even though the basefile is used
        # in any case.
        my $image_file_found;
        foreach my $extension (@LaTeX_image_extensions) {
          my ($file_name, $file_name_encoding)
             = $self->encoded_input_file_name("$basefile.$extension");
          my $located_file =
            Texinfo::Common::locate_include_file($file_name,
                                  $self->get_conf('INCLUDE_DIRECTORIES'));
          if (defined($located_file)) {
            $image_file_found = 1;
            last;
          }
        }
        if (not $image_file_found) {
          $self->converter_line_warn(
                         sprintf(__("\@image file `%s' (for LaTeX) not found"),
                                 $basefile),
                           $element->{'source_info'});
        }
        # Use the basename and not the file found.  It is agreed that it is
        # better, since in any case the files are moved.
        # If the file path found was to be used it should be decoded to perl
        # codepoints too.
        # using basefile with escaped characters, no extension to let LaTeX
        # choose the extension
        # FIXME not clear at all what can be in filenames here,
        # what should be escaped and how
        my $converted_basefile = $basefile;
        # for now minimal protection.  Not sure that % is problematic
        $converted_basefile =~ s/([%{}\\])/\\$1/g;
        my $image_file = $converted_basefile;
        my $width;
        if ((@{$element->{'args'}} >= 2)
              and defined($element->{'args'}->[1])
              and $element->{'args'}->[1]->{'contents'}
              and @{$element->{'args'}->[1]->{'contents'}}){
          push @{$self->{'formatting_context'}->[-1]->{'text_context'}},
               'ctx_raw';
          $width = _convert($self, {'contents'
                         => $element->{'args'}->[1]->{'contents'}});
          my $old_context
            = pop @{$self->{'formatting_context'}->[-1]->{'text_context'}};
          die if ($old_context ne 'ctx_raw');
          if ($width !~ /\S/) {
            $width = undef;
          }
        }
        my $height;
        if ((@{$element->{'args'}} >= 3)
              and defined($element->{'args'}->[2])
              and $element->{'args'}->[2]->{'contents'}
              and @{$element->{'args'}->[2]->{'contents'}}) {
          push @{$self->{'formatting_context'}->[-1]->{'text_context'}},
               'ctx_raw';
          $height = _convert($self, {'contents'
                         => $element->{'args'}->[2]->{'contents'}});
          my $old_context
             = pop @{$self->{'formatting_context'}->[-1]->{'text_context'}};
          die if ($old_context ne 'ctx_raw');
          if ($height !~ /\S/) {
            $height = undef;
          }
        }
        $result .= "\\includegraphics";
        if (defined($width) or defined($height)) {
          $result .= "[";
          if (defined($width)) {
            $result .= "width=$width";
            if (defined($height)) {
              $result .= ",";
            }
          }
          if (defined($height)) {
            $result .= "height=$height";
          }
          $result .= "]";
        }
        $result .= "{$image_file}";
      }
      return $result;
    } elsif ($cmdname eq 'email') {
      if ($element->{'args'}) {
        my $name;
        my $converted_name;
        my $email_arg;
        my $email_text;
        if (scalar (@{$element->{'args'}}) == 2
            and $element->{'args'}->[1]->{'contents'}) {
          $name = $element->{'args'}->[1];
          $converted_name = _convert($self, $name);
        }
        if ($element->{'args'}->[0]->{'contents'}) {
          $email_arg = $element->{'args'}->[0];
          Texinfo::Convert::Text::set_options_code(
                          $self->{'convert_text_options'});
          $email_text
            = $self->_protect_url(Texinfo::Convert::Text::convert_to_text(
                                                    $email_arg,
                                       $self->{'convert_text_options'}));
          Texinfo::Convert::Text::reset_options_code(
                                         $self->{'convert_text_options'});
        }
        if ($name and $email_arg) {
          $result .= "\\href{mailto:$email_text}{$converted_name}";
        } elsif ($email_arg) {
          $result .= "\\href{mailto:$email_text}{\\nolinkurl{$email_text}}";
        } elsif ($name) {
          $result .= $converted_name;
        }
      }
      return $result;
    } elsif ($cmdname eq 'uref' or $cmdname eq 'url') {
      if ($element->{'args'}) {
        if (scalar(@{$element->{'args'}}) == 3
             and $element->{'args'}->[2]->{'contents'}) {
          unshift @{$self->{'current_contents'}->[-1]},
                     $element->{'args'}->[2];
        } elsif ($element->{'args'}->[0]->{'contents'}) {
          my $url_arg = $element->{'args'}->[0];
          Texinfo::Convert::Text::set_options_code(
                                   $self->{'convert_text_options'});
          my $url_text = $self->_protect_url(
            Texinfo::Convert::Text::convert_to_text($url_arg,
                                 $self->{'convert_text_options'}));
          Texinfo::Convert::Text::reset_options_code(
                                   $self->{'convert_text_options'});
          if (scalar(@{$element->{'args'}}) == 2
              and $element->{'args'}->[1]->{'contents'}) {
            my $description_text = _convert($self, $element->{'args'}->[1]);
            my $text = $self->cdt_string('{text} ({url})',
              {'text' => $description_text, 'url' => "\\nolinkurl{$url_text}"});
            $result .= "\\href{$url_text}{$text}";
            return $result;
          } else {
            $result .= "\\url{$url_text}";
            return $result;
          }
        } elsif (scalar(@{$element->{'args'}}) == 2
                 and defined($element->{'args'}->[1])
                 and $element->{'args'}->[1]->{'contents'}
                 and @{$element->{'args'}->[1]->{'contents'}}) {
          unshift @{$self->{'current_contents'}->[-1]},
            {'contents' => $element->{'args'}->[1]->{'contents'}};
        }
      }
      return $result;
    } elsif ($cmdname eq 'footnote') {
      _push_new_context($self, 'footnote');
      $result .= '\footnote{';
      if ($element->{'args'}) {
        $result .= $self->_convert($element->{'args'}->[0]);
      }
      $result .= '}';
      _pop_context($self);
      return $result;
    } elsif ($cmdname eq 'anchor') {
      if ($element->{'args'}) {
        my $anchor_label
           = _tree_anchor_label($element->{'args'}->[0]->{'contents'});
        $result .= "\\label{$anchor_label}%\n";
      }
      return $result;
    } elsif ($ref_commands{$cmdname}) {
      if ($element->{'args'} and scalar(@{$element->{'args'}})) {
        my @args;
        for my $arg (@{$element->{'args'}}) {
          if (defined $arg->{'contents'} and @{$arg->{'contents'}}) {
            push @args, $arg;
          } else {
            push @args, undef;
          }
        }
        my $node_arg = $element->{'args'}->[0];
        if (($cmdname eq 'link' or $cmdname eq 'inforef')
            and scalar(@args) == 3) {
          $args[3] = $args[2]; # use as the manual argument
          $args[2] = undef;
        }
        my $book = '';
        if (defined($args[4])) {
          $book = _convert($self, $args[4]);
        }

        my $file_element;
        # FIXME not sure if Texinfo TeX uses the external node manual
        # specified as part of the node name with manual name prepended
        # in parentheses
        if (defined($args[3])) {
          $file_element = $args[3];
        } elsif ($node_arg and $node_arg->{'extra'}
                 and defined($node_arg->{'extra'}->{'normalized'})
                 and $node_arg->{'extra'}->{'manual_content'}) {
          $file_element = $node_arg->{'extra'}->{'manual_content'};
        }
        my $filename = '';
        if ($file_element) {
          push @{$self->{'formatting_context'}->[-1]->{'code'}}, 1;
          $filename = _convert($self, $file_element);
          pop @{$self->{'formatting_context'}->[-1]->{'code'}};
        }

        my $identifiers_target;
        if ($self->{'document'}) {
          $identifiers_target = $self->{'document'}->labels_information();
        }

        if ($cmdname ne 'inforef' and $book eq '' and $filename eq ''
            and $node_arg and $node_arg->{'extra'}
            and defined($node_arg->{'extra'}->{'normalized'})
            and !$node_arg->{'extra'}->{'manual_content'}
            and $identifiers_target
            and $identifiers_target->{$node_arg->{'extra'}->{'normalized'}}) {
          # internal reference
          my $reference
           = $identifiers_target->{$node_arg->{'extra'}->{'normalized'}};
          my $label_element = Texinfo::Common::get_label_element($reference);
          my $reference_node_content = $label_element->{'contents'};

          my $section_command;
          if ($reference->{'extra'}->{'associated_section'}) {
            $section_command = $reference->{'extra'}->{'associated_section'};
          } elsif ($reference->{'cmdname'} ne 'float') {
            my $normalized_name
              = $node_arg->{'extra'}->{'normalized'};
            if ($self->{'normalized_nodes_associated_section'}
                and $self->{'normalized_nodes_associated_section'}
                                                         ->{$normalized_name}) {
              $section_command
                = $self->{'normalized_nodes_associated_section'}
                                                        ->{$normalized_name};
            } elsif ($reference->{'cmdname'} eq 'node') {
              # can only happen if there is no sectioning commands at all,
              # otherwise it would have been associated in
              # _associate_other_nodes_to_sections.  Nothing to do in that case.
            } else {
              # an anchor.  Find associated section using top level parent
              # @-command.
              my $current = $reference;
              while ($current->{'parent'}) {
                $current = $current->{'parent'};
                if ($current->{'cmdname'}
                    and $root_commands{$current->{'cmdname'}}) {
                  if ($current->{'cmdname'} ne 'node') {
                    $section_command = $current;
                  } else {
                    if ($current->{'extra'}->{'associated_section'}) {
                      $section_command
                           = $current->{'extra'}->{'associated_section'};
                    } elsif (exists($current->{'extra'}->{'normalized'})
                             and $self->{'normalized_nodes_associated_section'}
                                        ->{$current->{'extra'}->{'normalized'}}) {
                      $section_command
                        = $self->{'normalized_nodes_associated_section'}
                                           ->{$current->{'extra'}->{'normalized'}};
                    }
                  }
                  last;
                } elsif ($current->{'type'}
                         and $current->{'type'} eq 'before_node_section') {
                  # anchor before Top node, can be in copying, titlepage,
                  # or directly in the main document.
                  # Could also be before setfilename.
                  last;
                }
              }
              if (defined($section_command)) {
                # set the association with anchor
                $self->{'normalized_nodes_associated_section'}->{$normalized_name}
                  = $section_command;
              } elsif (not defined($current->{'parent'})) {
                # that means that it is an anchor, but we did not find an root
                # sectioning command nor 'before_node_section' type, which
                # should not be possible.
                print STDERR "BUG/TODO assoc ".$reference->{'cmdname'}
                       .": $normalized_name: "
                       .join("|", sort(keys(%{$reference->{'extra'}})))."\n";
              }
            }
          }
          # reference to a float with a label
          my $float_type;
          if (exists($reference->{'cmdname'})
              and $reference->{'cmdname'} eq 'float') {
            if ($reference->{'extra'}->{'float_type'} ne '') {
              $float_type = _convert($self, $reference->{'args'}->[0]);
            } else {
              $float_type = '';
            }
          }
          my $text_representation;
          if ($self->{'formatting_context'}->[-1]
                                    ->{'in_sectioning_command_heading'}) {
            # hyperref leads, understandably to some errors in a heading for
            # the table of content.  In that case, setup a text representation.
            $text_representation = '';
          }
          # TODO translation
          my $reference_result = '';
          if ($cmdname eq 'xref') {
            $reference_result = "See ";
          } elsif ($cmdname eq 'pxref') {
            $reference_result = "see ";
          } elsif ($cmdname eq 'ref') {
          }
          $text_representation .= $reference_result
            if defined($text_representation);
          my $name;
          if ($cmdname eq 'link' and defined($args[1])) {
            $name = $args[1];
          } elsif (defined($args[2])) {
            $name = $args[2];
          } elsif (not defined($float_type)) {
            if (defined($self->get_conf('xrefautomaticsectiontitle'))
                and $self->get_conf('xrefautomaticsectiontitle') eq 'on'
                and $section_command) {
              $name = $section_command->{'args'}->[0];
            } else {
              $name = {'contents' => $reference_node_content};
            }
          }
          my $reference_label = _tree_anchor_label($reference_node_content);

          my $name_text;
          if (defined($name)) {
            $name_text = _convert($self, $name);
            $text_representation .= $name_text if (defined($text_representation));
          }

          if ($cmdname eq 'link') {
            if (defined($name_text)) {
              $reference_result .= "\\hyperref[$reference_label]{$name_text}";
            }
          } elsif (defined($float_type)) {
            # no page for float reference in Texinfo TeX
            if (defined($name_text)) {
              $reference_result .= "\\hyperref[$reference_label]{$name_text}";
            } else {
              if ($float_type ne '') {
                $reference_result
                  .= "\\hyperref[$reference_label]{$float_type~\\ref*{$reference_label}}";
                $text_representation .= $float_type
                     if (defined($text_representation));
              } else {
                $reference_result
                  .= "\\hyperref[$reference_label]{\\ref*{$reference_label}}";
              }
            }
          } else {
            # FIXME seems like a , should be added last, but only if not
            # followed by punctuation which means a painful look ahead
            # code to do...  From the Texinfo manual:
            # When processing with TeX, a comma is automatically inserted after the page number
            # for cross-references to within the same manual, unless the closing brace of the argument
            # is followed by non-whitespace (such as a comma or period).
            #
            # If an unwanted comma is added, follow the argument with a command such as @:
            if ($reference->{'cmdname'} and $reference->{'cmdname'} eq 'node'
                and $section_command) {
              if ($section_command->{'extra'}->{'section_level'} > 1) {
                # TODO command that could be used for translation \sectionname
                # does not exist in the default case.  it is defined in the
                # pagenote package together with \pagename which is page in
                # the default case, but it is unclear if this can be used as
                # a basis for translations.
                $reference_result
  .= "\\hyperref[$reference_label]{Section~\\ref*{$reference_label} [$name_text], page~\\pageref*{$reference_label}}";
              } else {
                # TODO translation
                $reference_result
  .= "\\hyperref[$reference_label]{\\chaptername~\\ref*{$reference_label} [$name_text], page~\\pageref*{$reference_label}}";
              }
            } else {
              # anchor or document without sectioning commands
              # TODO translation
              $reference_result
  .= "\\hyperref[$reference_label]{[$name_text], page~\\pageref*{$reference_label}}";
            }
          }
          if (not defined($text_representation)) {
            $result .= $reference_result;
          } else {
            $result .= '\texorpdfstring{'.$reference_result.'}{'
                             .$text_representation.'}';
          }
          return $result;
        } elsif ($cmdname ne 'link') {
          # external ref
          # TODO hyper reference to manual file which seems to be implemented
          # in recent Texinfo TeX
          # TODO translation
          if ($cmdname eq 'xref') {
            $result .= "See ";
          } elsif ($cmdname eq 'pxref') {
            $result .= "see ";
          } elsif ($cmdname eq 'ref') {
          }
          my $name;
          if (defined($args[2])) {
            $name = $args[2];
          } elsif (defined($args[0])) {
            $name = $args[0];
          }
          my $name_text;
          if (defined($name)) {
            $name_text = _convert($self, $name);
          }

          if ($book ne '') {
            if (defined ($name_text)) {
              # TODO translation
              $result .= "Section ``$name_text'' in \\textsl{$book}";
            } else {
              $result .= "\\textsl{$book}";
            }
          } elsif ($filename ne '') {
            if (defined ($name_text)) {
              # TODO translation
              $result .= "Section ``$name_text'' in \\texttt{$filename}";
            } else {
              $result .= "\\texttt{$filename}";
            }
          } elsif ($name_text) {
            $result .= $name_text;
          }
        } else {
          # external @link - just produce non-working text.
          my $name;
          if (defined($args[1])) {
            $name = $args[1];
          } elsif (defined($args[0])) {
            $name = $args[0];
          }

          my $name_text;
          if (defined($name)) {
            $name_text = _convert($self, $name);
            $result .= $name_text;
          }
        }
        return $result;
      }
      return $result;
    } elsif ($explained_commands{$cmdname}) {
      if ($element->{'args'}
          and $element->{'args'}->[0]->{'contents'}) {
        # in abbr spaces never end a sentence.
        my $argument;
        if ($cmdname eq 'abbr') {
          $argument = {'type' => '_dot_not_end_sentence',
                       'contents' => [$element->{'args'}->[0]]};
        } else {
        # TODO in TeX, acronym is in a smaller font (1pt less).
          $argument = $element->{'args'}->[0];
        }
        if (scalar (@{$element->{'args'}}) == 2
            and defined($element->{'args'}->[-1])
            and $element->{'args'}->[-1]->{'contents'}
            and @{$element->{'args'}->[-1]->{'contents'}}) {
          my $prepended
           = $self->cdt('{abbr_or_acronym} ({explanation})',
                        {'abbr_or_acronym' => $argument,
                         'explanation'
                                   => $element->{'args'}->[-1]});
          $result .= _convert($self, $prepended);
        } else {
          $result .= _convert($self, $argument);
        }
      }
      return $result;
    } elsif ($Texinfo::Commands::brace_commands{$cmdname}
             and $Texinfo::Commands::brace_commands{$cmdname} eq 'inline') {
      my $arg_index = 1;
      if ($cmdname eq 'inlinefmtifelse'
          and (!$element->{'extra'}->{'format'}
               or !$self->{'expanded_formats'}
                                        ->{$element->{'extra'}->{'format'}})) {
        $arg_index = 2;
      }
      if (scalar(@{$element->{'args'}}) > $arg_index
         and defined($element->{'args'}->[$arg_index])
         and $element->{'args'}->[$arg_index]->{'contents'}
         and scalar(@{$element->{'args'}->[$arg_index]->{'contents'}})) {
        if ($cmdname eq 'inlineraw') {
          push @{$self->{'formatting_context'}->[-1]->{'text_context'}},
               'ctx_raw';
        }
        $result .= _convert($self, {'contents'
                         => $element->{'args'}->[$arg_index]->{'contents'}});
        if ($cmdname eq 'inlineraw') {
          my $old_context
              = pop @{$self->{'formatting_context'}->[-1]->{'text_context'}};
          die if ($old_context ne 'ctx_raw');
        }
      }
      return $result;
    } elsif ($math_commands{$cmdname}) {
      push @{$self->{'formatting_context'}->[-1]->{'text_context'}}, 'ctx_math';
      if (not exists($block_commands{$cmdname})) {
        push @{$self->{'formatting_context'}->[-1]->{'math_style'}}, 'one-line';
        if ($cmdname eq 'math') {
          if ($element->{'args'}) {
            $result .= '$';
            $result .= _convert($self, $element->{'args'}->[0]);
            $result .= '$';
          }
        }
        my $old_context
            = pop @{$self->{'formatting_context'}->[-1]->{'text_context'}};
        die if ($old_context ne 'ctx_math');
        my $old_math_style
            = pop @{$self->{'formatting_context'}->[-1]->{'math_style'}};
        die if ($old_math_style ne 'one-line');
        return $result;
      } else {
        if ($cmdname eq 'displaymath') {
          push @{$self->{'formatting_context'}->[-1]->{'math_style'}}, 'one-line';
          # close all preformatted formats
          $preformatted_to_reopen
              = [@{$self->{'formatting_context'}->[-1]->{'preformatted_context'}}];
          $result .= _close_preformatted_stack($self, $preformatted_to_reopen);
          $result .= "\\[\n";
        }
      }
    } elsif ($cmdname eq 'caption' or $cmdname eq 'shortcaption') {
      if (not defined($element->{'extra'})
          or not defined($element->{'extra'}->{'float'})) {
        return $result;
      }
      my $float = $element->{'extra'}->{'float'};
      my $shortcaption;
      if ($cmdname eq 'shortcaption') {
        if ($float->{'extra'}->{'caption'}) {
          # nothing to do, will use @shortcaption when converting @caption
          return $result;
        } else {
          # shortcaption used as caption;
        }
      } else {
        if ($float->{'extra'}->{'shortcaption'}) {
          $shortcaption = $float->{'extra'}->{'shortcaption'};
        }
      }
      my $caption_text = '';
      if ($element->{'args'}->[0]->{'contents'}) {
        _push_new_context($self, 'latex_caption');
        $caption_text = _convert($self, $element->{'args'}->[0]);
        _pop_context($self);
      }

      if (scalar(@{$self->{'formatting_context'}->[-1]
                                               ->{'non_floating_commands'}})) {
        my $normalized_float_type = $float->{'extra'}->{'float_type'};
        if (not exists($self->{'normalized_float_latex'}
                                                 ->{$normalized_float_type})) {
          cluck("caption \@float $normalized_float_type: not found\n");
          return '';
        }
        my $latex_float_name
          = $self->{'normalized_float_latex'}->{$normalized_float_type};

        $result .= "\\captionof{$latex_float_name}";
      } else {
        $result .= '\caption';
      }

      if (defined($shortcaption)
          and $shortcaption->{'args'}->[0]->{'contents'}) {
        _push_new_context($self, 'latex_shortcaption');
        my $shortcaption_text = _convert($self, $shortcaption->{'args'}->[0]);
        _pop_context($self);
        $result .= '['.$shortcaption_text.']';
      }
      $result .= "{$caption_text}\n";
      return $result;
    } elsif ($cmdname eq 'titlefont') {
      $result .= _title_font($self, $element);
      return $result;
    } elsif ($cmdname eq 'U') {
      if ($element->{'args'}
          and $element->{'args'}->[0]->{'contents'}
          and $element->{'args'}->[0]->{'contents'}->[0]->{'text'}) {
        my $arg_text = $element->{'args'}->[0]->{'contents'}->[0]->{'text'};

        if (defined($arg_text)) {
          # Syntactic checks on the value were already done in Parser.pm,
          # but we have one more thing to test: since this is the one
          # place where we might output actual UTF-8 binary bytes, we have
          # to check that it is possible.  If not, silently fall back to
          # plain text, on the theory that the user wants something.
          # Note that being able to output an unicode point as encoded
          # character does not mean that LaTeX will be able to process it.
          my $res;
          if ($self->{'to_utf8'}) {
            my $possible_conversion
            = Texinfo::Convert::Unicode::check_unicode_point_conversion(
                                                  $arg_text, $self->{'debug'});
            if ($possible_conversion) {
              $res = chr(hex($arg_text)); # ok to call chr
            } else {
              $res = "U+$arg_text";
            }
          } else {
            $res = "U+$arg_text";  # not outputting UTF-8
          }
          $result .= _protect_text($self, $res);
        }
      }
      return $result;
    } elsif ($cmdname eq 'value') {
      my $expansion = $self->cdt('@{No value for `{value}\'@}',
                                 {'value'
                                    => $element->{'args'}->[0]});
      $expansion = {'type' => 'paragraph',
                    'contents' => [$expansion]};
      $result .= _convert($self, $expansion);
      return $result;
    # block commands
    } elsif (exists($block_commands{$cmdname})) {
      if ($LaTeX_environment_commands{$cmdname}) {
        push @{$self->{'formatting_context'}->[-1]->{'non_floating_commands'}},
          $cmdname
            if ($LaTeX_non_floating_environment_commands{$cmdname});
        my $environment_options = _set_environment_options($self, $cmdname,
                                                           $element);
        foreach my $environment (@{$LaTeX_environment_commands{$cmdname}}) {
          $self->{'fixed_width_environments'}->{$environment} = 1
            if ($LaTeX_fixed_width_environments{$environment});
          $result .= "\\begin{".$environment."}";
          if (defined($environment_options) and
              exists($environment_options->{$environment})) {
            $result .= '['.$environment_options->{$environment}.']';
          }
          # For @flushright and @flushleft, which don't use 'preformatted'
          # elements, unlike @display and @format.  This comments out the
          # newline.
          $result .= '%' if $environment eq 'Texinfopreformatted';
          $result .= "\n";
        }
        if ($LaTeX_environment_packages{$cmdname}) {
          foreach my $package (@{$LaTeX_environment_packages{$cmdname}}) {
            $self->{'packages'}->{$package} = 1;
          }
        }
        if ($LaTeX_list_environments{$cmdname}) {
          $self->{'list_environments'}->{$LaTeX_list_environments{$cmdname}} = 1;
        }
      }
      if ($preformatted_commands{$cmdname}) {
        _open_preformatted_command($self, $cmdname);
      } elsif ($block_raw_commands{$cmdname}) {
        push @{$self->{'formatting_context'}->[-1]->{'text_context'}}, 'ctx_raw';
      }
      if ($block_commands{$cmdname}
          and $block_commands{$cmdname} eq 'item_line') {
        # may be undef, in particular if the command is not a style command,
        # for example @email
        my $description_command_format
          = _xtable_description_command_format($self, $element);
        push @{$self->{'formatting_context'}->[-1]->{'table_command_format'}},
                $description_command_format;
      }
      if ($cmdname eq 'quotation' or $cmdname eq 'smallquotation') {
        # this is only used to avoid @author converted as
        # a @titlepage author, for a @quotation in @titlepage @author
        $self->{'formatting_context'}->[-1]->{'in_quotation'} += 1;
        if ($element->{'args'} and $element->{'args'}->[0]
            and $element->{'args'}->[0]->{'contents'}
            and @{$element->{'args'}->[0]->{'contents'}}) {
          my $prepended = $self->cdt('@b{{quotation_arg}:} ',
                      {'quotation_arg' => $element->{'args'}->[0]});
          $result .= $self->_convert($prepended);
        }
      } elsif ($cmdname eq 'multitable') {
        # for m{} in tabular header
        $self->{'packages'}->{'array'} = 1;
        $result .= '\begin{tabular}{';
        my @fractions;
        if ($element->{'extra'}->{'columnfractions'}) {
          @fractions
      = @{$element->{'extra'}->{'columnfractions'}->{'extra'}->{'misc_args'}};
        } elsif ($element->{'args'} and scalar(@{$element->{'args'}})
                 and $element->{'args'}->[0]->{'contents'}) {
          my @prototypes_length;
          my $total_length = 0.;
          foreach my $content (@{$element->{'args'}->[0]->{'contents'}}) {
            if ($content->{'type'} and $content->{'type'} eq 'bracketed_arg') {
              my $prototype_text = '';
              if ($content->{'contents'}) {
                $prototype_text
                    = Texinfo::Convert::Text::convert_to_text(
                                 $content,
                                 $self->{'convert_text_options'});
              }
              my $length
                 = Texinfo::Convert::Unicode::string_width($prototype_text);
              $total_length += $length;
              push @prototypes_length, $length;
            }
          }
          if ($total_length > 0.) {
            foreach my $length (@prototypes_length) {
              push @fractions, $length / $total_length;
            }
          }
        }
        $result .= join(' ', map {'m{'.$_.'\textwidth}'} @fractions);
        $result .= "}%\n";
      } elsif ($cmdname eq 'float') {
        if (not $self->{'formatting_context'}->[-1]->{'in_skipped_node_top'}) {
          my $normalized_float_type = $element->{'extra'}->{'float_type'};
          if (not exists($self->{'normalized_float_latex'}
                                                 ->{$normalized_float_type})) {
            cluck("\@float $normalized_float_type: not found\n");
            return '';
          }
          my $latex_float_name
            = $self->{'normalized_float_latex'}->{$normalized_float_type};
          _push_new_context($self, 'float'.$latex_float_name,
              $self->{'formatting_context'}->[-1]->{'preformatted_context'},
              $self->{'formatting_context'}->[-1]->{'non_floating_commands'});
          my $latex_float_environment;
          if (scalar(@{$self->{'formatting_context'}->[-1]->
                                                 {'non_floating_commands'}})) {
            $self->{'packages'}->{'caption'} = 1;
            $latex_float_environment = $non_floating_float_environment;
          } else {
            $latex_float_environment = $latex_float_name;
          }
          $result .= "\\begin{$latex_float_environment}\n";
        }
      }
    } elsif ($cmdname eq 'node' or $sectioning_heading_commands{$cmdname}) {
      my $node_element;
      if ($cmdname eq 'node') {
        $node_element = $element;
      } elsif ($cmdname eq 'part' and $element->{'extra'}
               and $element->{'extra'}->{'part_following_node'}) {
        $node_element = $element->{'extra'}->{'part_following_node'};
      }
      if ($node_element and $node_element->{'extra'}
          and $node_element->{'extra'}->{'normalized'}
          and $node_element->{'extra'}->{'normalized'} eq 'Top') {
        $self->{'formatting_context'}->[-1]->{'in_skipped_node_top'} = 1;
      }
      if ($cmdname eq 'node') {
        # add the label only if not associated with a section
        if (!$element->{'extra'}
            or not $element->{'extra'}->{'associated_section'}) {
          my $node_label
            = _tree_anchor_label($element->{'args'}->[0]->{'contents'});
          $result .= "\\label{$node_label}%\n";
        }
      } else {
        if ($cmdname eq 'appendix' and not $self->{'appendix_done'}) {
          $result .= "\\appendix\n";
          $self->{'appendix_done'} = 1;
        }
        if (not $self->{'formatting_context'}->[-1]->{'in_skipped_node_top'}) {
          my $heading = '';
          if ($element->{'args'}->[0]->{'contents'}) {
            # It is useful to know that this is a heading formatting as
            # the formatted heading is in the table of content, and some
            # formatting may be different for that case, for instance with
            # \texorpdfstring
            $self->{'formatting_context'}->[-1]
                                  ->{'in_sectioning_command_heading'} = 1;
            $heading = $self->_convert(
                        {'contents' => $element->{'args'}->[0]->{'contents'}});
            $self->{'formatting_context'}->[-1]
                                  ->{'in_sectioning_command_heading'} = 0;
          }
          my $section_cmd = $section_map{$cmdname};
          die "BUG: no section_map for $cmdname"
                     if (not defined($section_map{$cmdname}));
          if ($cmdname ne 'centerchap') {
            $result .= "\\".$section_cmd."{{$heading}}\n";
          } else {
            $result .= "\\".$section_cmd."{{\\centering $heading}}\n";
          }
          # NOTE we used an extra layer of { } to avoid buggy interactions with
          # square brackets when the titleps package is being used.
          $self->{'extra_definitions'}->{'Texinfonopagebreakheading'} = 1
            if $section_cmd =~ /^Texinfonopagebreakheading\{/;
        }
        # we add a label even if in_skipped_node_top (should only
        # be for the Top node, as another node ends in_skipped_node_top).
        if ($element->{'extra'} and $element->{'extra'}->{'associated_node'}) {
          my $associated_node = $element->{'extra'}->{'associated_node'};
          my $node_label
            = _tree_anchor_label($associated_node->{'args'}->[0]->{'contents'});
          $result .= "\\label{$node_label}%\n";
        }
      }
    } elsif (($cmdname eq 'item' or $cmdname eq 'itemx')
            and $element->{'args'} and $element->{'args'}->[0]
            and $element->{'args'}->[0]->{'type'}
            and $element->{'args'}->[0]->{'type'} eq 'line_arg') {
      # item in @*table
      my $last_item = 0;
      if ($element->{'args'}->[0]->{'contents'}) {
        my $code_style = 0;
        my $table_command = $element->{'parent'}->{'parent'}->{'parent'};
        if ($table_command->{'extra'}
            and $table_command->{'extra'}->{'command_as_argument'}) {
          my $command_as_argument
            = $table_command->{'extra'}->{'command_as_argument'}->{'cmdname'};
          if ($brace_code_commands{$command_as_argument}) {
            $code_style = 1;
          }
        }
        if ($code_style) {
          push @{$self->{'formatting_context'}->[-1]->{'code'}}, 1;
        }
        my $converted_arg = _convert($self, $element->{'args'}->[0]);
        if ($code_style) {
          pop @{$self->{'formatting_context'}->[-1]->{'code'}};
        }
        $self->{'formatting_context'}->[-1]->{'nr_table_items_context'}->[-1] -= 1;
        my $description_format_command
          = $self->{'formatting_context'}->[-1]->{'table_command_format'}->[-1];
        if (defined($description_format_command)) {
          $converted_arg = "${description_format_command}\{${converted_arg}\}";
        }
        $result .= $converted_arg;
        if ($self->{'formatting_context'}->[-1]->{'nr_table_items_context'}->[-1] > 0) {
          $result .= '\\\\'."\n";
        } else {
          $last_item = 1;
        }
      }
      my $index_entry = _index_entry($self, $element);
      if ($index_entry ne '' and $last_item) {
        $result .= "\n";
      }
      $result .= $index_entry;
    } elsif ($cmdname eq 'item' and $element->{'parent'}->{'cmdname'}
             and $block_commands{$element->{'parent'}->{'cmdname'}}
             and $block_commands{$element->{'parent'}->{'cmdname'}}
                                                    eq 'item_container') {
      # item in @enumerate and @itemize
      $result .= '\item ';
    } elsif ($cmdname eq 'headitem' or $cmdname eq 'item'
             or $cmdname eq 'tab') {
      # nothing to do here.  The condition ensures that the commands are not
      # considered as unknown commands in the else below.
    } elsif ($cmdname eq 'center') {
      if ($element->{'args'}->[0]->{'contents'}) {
        $result .= "\\begin{center}\n";
        $result .= $self->_convert (
                       {'contents' => $element->{'args'}->[0]->{'contents'}});
        $result .= "\n\\end{center}\n";
      }
      return $result;
    } elsif ($cmdname eq 'exdent') {
      if ($element->{'args'}->[0]->{'contents'}) {
        # FIXME \leavevmode{} is added to avoid
        # ! LaTeX Error: There's no line here to end.
        # but it is not clearly correct
        $result .= "\\leavevmode{}\\\\\n";
        $result .= "\\hbox{\\kern -\\leftmargin}%\n";
        $result .= $self->_convert(
                   {'contents' => $element->{'args'}->[0]->{'contents'}})."\n";
        $result .= "\\\\\n";
      }
      return $result;
    } elsif ($cmdname eq 'verbatiminclude') {
      my $expansion = Texinfo::Convert::Utils::expand_verbatiminclude(
                                                              $self, $element);
      unshift @{$self->{'current_contents'}->[-1]}, $expansion
        if ($expansion);
      return $result;
    } elsif ($cmdname eq 'insertcopying') {
      my $global_commands;
      if ($self->{'document'}) {
        $global_commands = $self->{'document'}->global_commands_information();
      }

      if ($global_commands and $global_commands->{'copying'}) {
        unshift @{$self->{'current_contents'}->[-1]},
           {'contents' => $global_commands->{'copying'}->{'contents'}};
      }
      return $result;
    } elsif ($cmdname eq 'printindex') {
      my $index_name;
      if ($element->{'extra'} and $element->{'extra'}->{'misc_args'}
          and defined($element->{'extra'}->{'misc_args'}->[0])) {
        $index_name = $element->{'extra'}->{'misc_args'}->[0];
        if (exists($self->{'index_entries'})
            and exists($self->{'index_entries'}->{$index_name})) {
          $result .= "\\printindex[$index_name]\n";
        }
      }
      return $result;
    } elsif ($cmdname eq 'listoffloats') {
      my $normalized_float_type = $element->{'extra'}->{'float_type'};
      my $floats;
      if ($self->{'document'}) {
        $floats = $self->{'document'}->floats_information();
      }

      if ($floats
          and $floats->{$normalized_float_type}
          and @{$floats->{$normalized_float_type}}) {
        if (not exists($self->{'normalized_float_latex'}
                                                 ->{$normalized_float_type})) {
          cluck("\@listoffloats $normalized_float_type: not found\n");
          return $result;
        }
        my $latex_float_name
            = $self->{'normalized_float_latex'}->{$normalized_float_type};
        # a listoffigures in @example leads to an error in the
        # lof file.  So stop and restart preformatted environments
        $preformatted_to_reopen
            = [@{$self->{'formatting_context'}->[-1]->{'preformatted_context'}}];
        $result .= _close_preformatted_stack($self, $preformatted_to_reopen);
        if (exists($LaTeX_floats{$latex_float_name})) {
          $result .= $LaTeX_floats{$latex_float_name}."\n";
        } else {
          $result .= "\\listof{$latex_float_name}{}\n";
        }
        $result .= _open_preformatted_stack($self, $preformatted_to_reopen);
      }
      return $result;
    } elsif ($cmdname eq 'page') {
      $result .= _finish_front_cover_page($self);
      # the phantom is added such that successive new pages create blank pages
      $result .= "\\newpage{}%\n\\phantom{blabla}%\n";
      return $result;
    } elsif ($cmdname eq 'indent') {
      # TODO it seems that \indent only works with \setlength{\parindent}{0pt}
      # which makes it quite different from Texinfo @indent
      #$result .= "\\indent{}";
    } elsif ($cmdname eq 'noindent') {
      # spaces after noindent are in ignorable_space_types and are therefore
      # munged which is ok as otherwise it could add a leading space
      $result .= "\\noindent{}";
      return $result;
    } elsif ($cmdname eq 'sp') {
      my $sp_nr = '';
      if ($element->{'extra'}
          and $element->{'extra'}->{'misc_args'}) {
        $sp_nr = $element->{'extra'}->{'misc_args'}->[0];
      }
      # NOTE \vskip is a TeX primitive that does what we need here,
      # stop any paragraph and add vertical space.
      # The code output here is the same as the code used in Texinfo TeX.
      $result .= "\\vskip $sp_nr\\baselineskip %\n";
      return $result;
    } elsif ($cmdname eq 'need') {
      $self->{'packages'}->{'needspace'} = 1;
      if ($element->{'extra'}->{'misc_args'}->[0]) {
        my $need_value = 0.001 * $element->{'extra'}->{'misc_args'}->[0];
        $result .= "\\needspace{${need_value}pt}%\n";
      }
      return $result;
    } elsif (defined($LaTeX_in_heading_commands_formatting{$cmdname})) {
      $result .= $LaTeX_in_heading_commands_formatting{$cmdname};
      if ($cmdname eq 'thisfile'
          and $self->{'formatting_context'}->[-1]->{'in_custom_heading'}) {
        $self->{'collected_includes'} = [] unless ($self->{'collected_includes'});
      }
      return $result;
    } elsif ($cmdname eq 'title') {
      my $title_text = _title_font($self, $element);
      # FIXME In Texinfo TeX the interline space seems more even
      $result .= "{\\raggedright $title_text}\n";
      # same formatting for the rule as in Texinfo TeX
      $result .= "\\vskip 4pt \\hrule height 4pt width \\hsize \\vskip 4pt\n";
      # TODO warn if not in titlepage?  Or even not in
      # $self->{'titlepage_formatting'}->{'in_front_cover'}
      $self->{'titlepage_formatting'}->{'title'} = 1
         if ($self->{'titlepage_formatting'});
    } elsif ($cmdname eq 'subtitle') {
      if ($element->{'args'}->[0]->{'contents'}) {
        my $subtitle_text = _convert($self,
               {'contents' => $element->{'args'}->[0]->{'contents'}});
        # too much vertical spacing with flushright environment
        #$result .= "\\begin{flushright}\n";
        #$result .= $subtitle_text."\n";
        #$result .= "\\end{flushright}\n";
        $result .= "\\rightline{$subtitle_text}\n";
      }
    } elsif ($cmdname eq 'author') {
      if (not $self->{'formatting_context'}->[-1]->{'in_quotation'}) {
        if ($element->{'args'}->[0]->{'contents'}) {
          my $author_name = _convert($self,
                       {'contents' => $element->{'args'}->[0]->{'contents'}});
          if ($self->{'titlepage_formatting'}
              and $self->{'titlepage_formatting'}->{'in_front_cover'}) {
            if (not $self->{'titlepage_formatting'}->{'author'}) {
              # first author, add space before
              $self->{'titlepage_formatting'}->{'author'} = 1;
              $result .= "\\vskip 0pt plus 1filll\n";
            }
            # use \leftline as in Texinfo TeX
            # FIXME In Texinfo TeX the interline space between @author lines
            # seems better
            $result .= "\\leftline{\\Large \\bfseries $author_name}%\n";
          } else {
            # author in regular text.  Should not happen
            $result .= "{\\bfseries $author_name}%\n";
          }
        }
        return $result;
      }
    } elsif ($cmdname eq 'vskip') {
      if ($element->{'args'}) {
        # no need for space in front and end of line they are in the
        # argument
        $result .= "\\vskip$element->{'args'}->[0]->{'text'}";
      }
      return $result;
    } elsif ($cmdname eq 'contents') {
      my $sections_list;
      if ($self->{'document'}) {
        $sections_list = $self->{'document'}->sections_list();
      }

      if (defined($self->get_conf('CONTENTS_OUTPUT_LOCATION'))
          and $self->get_conf('CONTENTS_OUTPUT_LOCATION') eq 'inline'
          and $sections_list
          and not $self->{'formatting_context'}->[-1]->{'in_skipped_node_top'}) {
        $result .= "\\tableofcontents\\newpage\n";
      }
      return $result;
    } elsif ($cmdname eq 'shortcontents' or $cmdname eq 'summarycontents') {
      my $sections_list;
      if ($self->{'document'}) {
        $sections_list = $self->{'document'}->sections_list();
      }

      if ($sections_list) {
        # TODO see notes at the beginning
        $result .= '';
      }
      return $result;
    } elsif ($heading_spec_commands{$cmdname}) {
      if ($element->{'args'} and $element->{'args'}->[0]
          and $element->{'args'}->[0]->{'contents'}) {
        my $custom_headings_specification
         = Texinfo::Common::split_custom_heading_command_contents(
                                             $element->{'args'}->[0]);
        $result .= _set_custom_headings($self, $cmdname,
                                        $custom_headings_specification);
      }
      return $result;
    # @-commands that have an information for the formatting
    } elsif ($informative_commands{$cmdname}) {

      my $set = Texinfo::Common::set_informative_command_value($self, $element);

      if ($set) {
        $result .= _informative_command_output($self, $cmdname);
      }
      return $result;
    } else {
      $unknown_command = 1;
    }
    if ($unknown_command
        and !($element->{'type'}
                and ($element->{'type'} eq 'index_entry_command'))
        # commands like def*x are not processed above, since only the def_line
        # associated is processed. If they have no name and no category they
        # are not considered as index entries either so they have a specific
        # condition
        and !($def_commands{$cmdname}
              and ($cmdname eq 'defline'
                   or $cmdname eq 'deftypeline'
                   or $cmdname =~ /x$/))) {
      warn "Unhandled $cmdname\n";
      #$result .= "!!!!!!!!! Unhandled $cmdname !!!!!!!!!\n";
    }
  }

  # open 'type' constructs.
  if ($element->{'type'}) {

    if ($container_ignored_if_empty{$element->{'type'}}
        and !$element->{'contents'}) {
      return $result;
    }


    if ($element->{'type'} eq 'index_entry_command') {
      $result .= _index_entry($self, $element);
    }
    if ($element->{'type'} eq 'def_line') {
      $result .= _convert_def_line($self, $element);
    } elsif ($element->{'type'} eq 'def_item') {
      $result .= "\\begin{quote}\n";
      # Remove vertical space and start paragaph, avoiding adding
      # more vertical space.
      $result .= "\\unskip{\\parskip=0pt\\noindent}%\n";
    } elsif ($element->{'type'} eq 'table_term') {
      $result .= '\item[{\parbox[b]{\linewidth}{%'."\n";
      # count @item/@itemx to add //\n to each except for the last
      my $nr_item = 0;
      foreach my $content (@{$element->{'contents'}}) {
        if ($content->{'cmdname'} and
            ($content->{'cmdname'} eq 'item'
             or $content->{'cmdname'} eq 'itemx')) {
          $nr_item++;
        }
      }
      push @{$self->{'formatting_context'}->[-1]->{'nr_table_items_context'}},
             $nr_item;
    } elsif ($element->{'type'} eq 'inter_item') {
      # the whole @item/@itemx formatting is put in a parbox, in which
      # there should not be paragraphs, so we remove empty lines from
      # inter_item.  We format directly here while ignoring the empty lines
      # for performance reasons, and not below like all the contents, to
      # avoid needing to check if in table items using a context information,
      # we know that only comments and index entries or a lone preformatted
      # should be in inter_item.
      if ($element->{'contents'}) {
        my $contents;
        # if in an preformatted context, ie in @example, the inter_item
        # content is within a preformatted.  In that case we use content
        # from within the preformatted.  We do not do anything that is done
        # in _open_preformatted/_close_preformatted as the only things
        # that should be in inter_item, besides empty lines we want to
        # remove, are comments and index entries, which formatting should
        # not be affected.
        if ($element->{'contents'}->[0]->{'type'}
            and $element->{'contents'}->[0]->{'type'} eq 'preformatted') {
          $contents = $element->{'contents'}->[0]->{'contents'}
            if $element->{'contents'}->[0]->{'contents'};
        } else {
          $contents = $element->{'contents'};
        }
        foreach my $content (@$contents) {
          $result .= _convert($self, $content)
            unless ($content->{'type'} and $content->{'type'} eq 'empty_line');
        }
      }
      return $result;
    } elsif ($element->{'type'} eq 'preformatted') {
      $result .= _open_preformatted($self, $element);
    } elsif ($element->{'type'} eq '_dot_not_end_sentence') {
      $self->{'formatting_context'}->[-1]->{'dot_not_end_sentence'} += 1;
    } elsif ($element->{'type'} eq 'untranslated_def_line_arg') {
      my $tree;
      if ($element->{'extra'}
          and $element->{'extra'}->{'translation_context'}) {
        $tree = $self->pcdt($element->{'extra'}->{'translation_context'},
                            $element->{'contents'}->[0]->{'text'});
      } else {
        $tree = $self->cdt($element->{'contents'}->[0]->{'text'});
      }
      my $converted = _convert($self, $tree);
      return $converted;
    }
  }

  # The processing of contents is done here.
  if ($element->{'contents'}) {
    my @contents = @{$element->{'contents'}};
    push @{$self->{'current_contents'}}, \@contents;
    while (@contents) {
      my $content = shift @contents;
      my $text = _convert($self, $content);
      $result .= $text;
      if ($self->{'debug'} and $self->{'debug'} > 2) {
        my @str_contents = ();
        foreach my $item_content (@contents) {
          push @str_contents,
               Texinfo::Common::debug_print_element($item_content);
        }
        print STDERR "C "
           .Texinfo::Common::debug_print_element($element)
                                     .": ".join("|", @str_contents)."\n";
      }
    }
    pop @{$self->{'current_contents'}};
  }

  # now closing. First, close types.
  if ($type) {
    if ($type eq '_dot_not_end_sentence') {
      $self->{'formatting_context'}->[-1]->{'dot_not_end_sentence'} -= 1;
    } elsif ($type eq 'def_item') {
      $result .= "\\end{quote}\n";
    } elsif ($type eq 'table_term') {
      $result .= '}}]'."\n";
      pop @{$self->{'formatting_context'}->[-1]->{'nr_table_items_context'}};
    } elsif ($type eq 'preformatted') {
      $result .= _close_preformatted($self, $element);
    } elsif ($type eq 'before_item') {
      # LaTeX environments do not accept text before the first item, add
      # an item:
      if ($result =~ /\S/) {
        # FIXME if there is only an index element it is content and
        # triggers an empty \item.  It is mitigated by
        # move_index_entries_after_items for enumerate and itemize, but not
        # for @*table.
        if ($block_commands{$element->{'parent'}->{'cmdname'}}
            and $block_commands{$element->{'parent'}->{'cmdname'}} eq 'item_line') {
          # it is important to have an empty optional argument otherwise
          # a quoted command will output the quotes, even with a detection
          # of empty argument (tested with diverse possibilities)
          $result = '\item[] '.$result;
        } else {
          $result = '\item '.$result;
        }
      }
    } elsif ($type eq 'row') {
      chomp($result);
      # can happen with diverse added @-command, in particular index commands
      if ($result =~ /%$/) {
        $result .= "\n";
      }
      $result .= '\\\\'."\n";
    } elsif ($type eq $latex_document_type) {
      # type marking the beginning of content
      $result .= _begin_document($self);
    }
  }

  # close commands
  if ($cmdname) {
    if ($block_commands{$cmdname} and $block_commands{$cmdname} eq 'item_line') {
      pop @{$self->{'formatting_context'}->[-1]->{'table_command_format'}};
    }
    if ($LaTeX_environment_commands{$cmdname}) {
      foreach my $environment (reverse @{$LaTeX_environment_commands{$cmdname}}) {
        $result .= "\\end{".$environment."}\n";
      }
    }
    pop @{$self->{'formatting_context'}->[-1]->{'non_floating_commands'}},
      if ($LaTeX_non_floating_environment_commands{$cmdname});
    if ($preformatted_commands{$cmdname}) {
      _close_preformatted_command($self, $cmdname);
    }
    if ($cmdname eq 'float') {
      # do that at the end of the float to be sure that it is after
      # the caption
      if ($element->{'args'} and scalar(@{$element->{'args'}}) >= 2
          and $element->{'args'}->[1]->{'contents'}) {
        my $float_label
          = _tree_anchor_label($element->{'args'}->[1]->{'contents'});
        $result .= "\\label{$float_label}%\n";
      }
      if (not $self->{'formatting_context'}->[-1]->{'in_skipped_node_top'}) {
        my $latex_float_environment;
        if (scalar(@{$self->{'formatting_context'}->[-1]
                                              ->{'non_floating_commands'}})) {
          $latex_float_environment = $non_floating_float_environment;
        } else {
          my $normalized_float_type = $element->{'extra'}->{'float_type'};
          # this should never happen as we returned at the command
          # open.  If this happens it means that the tree has been modified...
          if (not exists($self->{'normalized_float_latex'}
                                                 ->{$normalized_float_type})) {
            confess("\@float $normalized_float_type: not found\n");
          }
          $latex_float_environment
             = $self->{'normalized_float_latex'}->{$normalized_float_type};
        }
        $result .= "\\end{$latex_float_environment}\n";
        _pop_context($self);
      }
    } elsif ($cmdname eq 'quotation'
               or $cmdname eq 'smallquotation') {
      if ($element->{'extra'} and $element->{'extra'}->{'authors'}) {
        # NOTE when @quotation is in a preformatted environment (@example...),
        # we are not in a preformatted type here, such that the conversion
        # does not take into account the preformatted environment.
        # Probably best.
        foreach my $author (@{$element->{'extra'}->{'authors'}}) {
          if ($author->{'args'}->[0]->{'contents'}) {
            $result .= _convert($self,
                 # TRANSLATORS: quotation author
                 $self->cdt('@center --- @emph{{author}}',
                    {'author' => $author->{'args'}->[0]}));
          }
        }
      }
      $self->{'formatting_context'}->[-1]->{'in_quotation'} -= 1;
    } elsif ($cmdname eq 'multitable') {
      $result .= '\end{tabular}%'."\n";
    }

    # close the contexts and register the cells
    if ($block_raw_commands{$cmdname}) {
      my $old_context
          = pop @{$self->{'formatting_context'}->[-1]->{'text_context'}};
      die if ($old_context ne 'ctx_raw');
    } elsif ($block_math_commands{$cmdname}) {
      my $old_context
          = pop @{$self->{'formatting_context'}->[-1]->{'text_context'}};
      die if ($old_context ne 'ctx_math');
      if ($cmdname eq 'displaymath') {
        $result .= "\\]\n";
        # reopen all preformatted commands
        $result .= _open_preformatted_stack($self, $preformatted_to_reopen);
      }
      my $old_math_style
         = pop @{$self->{'formatting_context'}->[-1]->{'math_style'}};
      die if ($old_math_style ne 'one-line');
    } elsif ($element->{'parent'}->{'type'}
             and $element->{'parent'}->{'type'} eq 'row') {
      my $cell_nr = $element->{'extra'}->{'cell_number'};
      my $multitable = $element->{'parent'}->{'parent'}->{'parent'};
      my $max_columns = $multitable->{'extra'}->{'max_columns'};
      my $add_eol = 0;
      $add_eol = 1 if (chomp($result));
      if ($cell_nr < $max_columns) {
        $result .= '&';
      }
      $result .= "\n" if ($add_eol);
    }
  }

  return $result;
}

1;
