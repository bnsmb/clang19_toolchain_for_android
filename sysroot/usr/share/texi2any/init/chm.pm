# -*-perl-*-

#+##############################################################################
#
# chm.pm: convert to chm intermediate formats hhp, hhc, hhk and html files
#
#    Copyright 2004, 2006, 2009, 2011-2024 Free Software Foundation, Inc.
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

# loading with -d:TraceUse leads to an error like
# texi2any: warning: error loading ../init/chm.pm: Undefined subroutine &Devel::TraceUse::texinfo_set_format_from_init_file called at ../init/chm.pm line 43.
# defining the package here avoids this error.
package Texinfo::Config;

use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use File::Spec;

# Also for __(
use Texinfo::Common;

# load modules to make sure that they are loaded before use
use Texinfo::Convert::Unicode;
use Texinfo::Convert::Utils;
use Texinfo::Convert::Text;

texinfo_set_format_from_init_file('html');

texinfo_set_from_init_file('TOP_FILE', undef);

texinfo_set_from_init_file('contents', 1);

# remove navigation information, it is done by the viewer, and remove
# anything that gets in the way of the navigation.
texinfo_set_from_init_file('FORMAT_MENU', 'nomenu');
texinfo_set_from_init_file('SPLIT', 'node');

texinfo_set_from_init_file('DEFAULT_RULE', '');
texinfo_set_from_init_file('BIG_RULE', '');
texinfo_set_from_init_file('HEADERS', 0);

texinfo_set_from_init_file('footnotestyle', 'end');

texinfo_set_from_init_file('PROGRAM_NAME_IN_FOOTER', 0);

texinfo_register_formatting_function('format_navigation_header', \&chm_noop);
texinfo_register_formatting_function('format_navigation_panel', \&chm_noop);

my %chm_languages = (
    'en'         => '0x409 English (United States)',
    'sq'         => '0x041c Albanian',
#    'ar'         => '0x1401 Arabic (ALGERIA)',
#    'es'         => '0x2c0a Spanish (ARGENTINA)',
#    'en'         => '0x0c09 English (AUSTRALIA)',
#    'de'         => '0x0c07 German (AUSTRIA)',
#    'ar'         => '0x3c01 Arabic (BAHRAIN)',
    'be'         => '0x0423 Byelorussian',
#    'fr'         => '0x080c French (BELGIUM)',
#    'en'         => '0x2809 English (BELIZE)',
#    'es'         => '0x400a Spanish (BOLIVIA)',
#    'pt'         => '0x0416 Portuguese (BRAZIL)',
#    'ms'         => '0x083e Malay (BRUNEI DARUSSALAM)',
    'bg'         => '0x0402 Bulgarian',
#    'fr'         => '0x0c0c French (CANADA)',
#    'es'         => '0x340a Spanish (CHILE)',
    'zh'         => '0x0804 Chinese (CHINA)',
#    'es'         => '0x240a Spanish (COLOMBIA)',
#    'es'         => '0x140a Spanish (COSTA RICA)',
    'hr'         => '0x041a Croatian',
    'cs'         => '0x0405 Czech',
    'da'         => '0x0406 Danish',
#    'es'         => '0x1c0a Spanish (DOMINICAN REPUBLIC)',
#    'es'         => '0x300a Spanish (ECUADOR)',
#    'ar'         => '0x0c01 Arabic (EGYPT)',
#    'es'         => '0x440a Spanish (EL SALVADOR)',
    'et'         => '0x0425 Estonian',
    'fo'         => '0x0438 Faeroese',
    'fi'         => '0x040b Finnish',
    'fr'         => '0x040c French (FRANCE)',
    'de'         => '0x0407 German (GERMANY)',
    'el'         => '0x0408 Greek',
#    'es'         => '0x100a Spanish (GUATEMALA)',
#    'es'         => '0x480a Spanish (HONDURAS)',
#    'zh'         => '0x0c04 Chinese (HONG KONG)',
    'hu'         => '0x040e Hungarian',
    'is'         => '0x040f Icelandic',
    'hi'         => '0x0439 Hindi',
    'in'         => '0x04',
    'fa'         => '0x0429 Farsi',
#    'ar'         => '0x0801 Arabic (IRAQ)',
#    'en'         => '0x1809 English (IRELAND)',
    'iw'         => '0x04',
    'it'         => '0x0410 Italian',
#    'en'         => '0x2009 English (JAMAICA)',
    'ja'         => '0x0411 Japanese',
#    'ar'         => '0x2c01 Arabic (JORDAN)',
    'sw'         => '0x0441 Swahili',
    'ko'         => '0x0412 Korean',
#    'ar'         => '0x3401 Arabic (KUWAIT)',
    'al'         => '0x0426 Latvian (Lettish)',
#    'ar'         => '0x3001 Arabic (LEBANON)',
#    'ar'         => '0x1001 Arabic (LIBYAN ARAB JAMAHIRIYA)',
#    'de'         => '0x1407 German (LIECHTENSTEIN)',
    'lt'         => '0x0427 Lithuanian',
#    'de'         => '0x1007 German (LUXEMBOURG)',
#    'zh'         => '0x1404 Chinese (MACAU)',
    'mk'         => '0x042f Macedonian',
#    'ms'         => '0x043e Malay (MALAYSIA)',
#    'es'         => '0x080a Spanish (MEXICO)',
#    'fr'         => '0x180c French (MONACO)',
#    'ar'         => '0x1801 Arabic (MOROCCO)',
    'nl'         => '0x0413 Dutch',
#    'en'         => '0x1409 English (NEW ZEALAND)',
#    'es'         => '0x4c0a Spanish (NICARAGUA)',
    'no'         => '0x0414 Norwegian',
#    'ar'         => '0x2001 Arabic (OMAN)',
    'ur'         => '0x0420 Urdu',
#    'es'         => '0x180a Spanish (PANAMA)',
#    'es'         => '0x3c0a Spanish (PARAGUAY)',
#    'es'         => '0x280a Spanish (PERU)',
#    'en'         => '0x3409 English (PHILIPPINES)',
    'pl'         => '0x0415 Polish',
    'pt'         => '0x0816 Portuguese (PORTUGAL)',
#    'es'         => '0x500a Spanish (PUERTO RICO)',
#    'ar'         => '0x4001 Arabic (QATAR)',
    'ro'         => '0x0418 Romanian',
    'ru'         => '0x0419 Russian',
    'ar'         => '0x0401 Arabic (SAUDI ARABIA)',
#    'zh'         => '0x1004 Chinese (SINGAPORE)',
    'sk'         => '0x041b Slovak',
    'sl'         => '0x0424 Slovenian',
    'af'         => '0x0436 Afrikaans',
    'ca'         => '0x0403 Catalan',
    'sv'         => '0x041d Swedish',
#    'de'         => '0x0807 German (SWITZERLAND)',
#    'ar'         => '0x2801 Arabic (SYRIAN ARAB REPUBLIC)',
#    'zh'         => '0x0404 Chinese (TAIWAN, PROVINCE OF CHINA)',
    'th'         => '0x041e Thai',
#    'en'         => '0x2c09 English (TRINIDAD AND TOBAGO)',
#    'ar'         => '0x1c01 Arabic (TUNISIA)',
    'tr'         => '0x041f Turkish',
    'uk'         => '0x0422 Ukrainian',
#    'ar'         => '0x3801 Arabic (UNITED ARAB EMIRATES)',
#    'en'         => '0x0809 English (UNITED KINGDOM)',
#    'en'         => '0x0409 English (UNITED STATES)',
#    'es'         => '0x380a Spanish (URUGUAY)',
#    'es'         => '0x200a Spanish (VENEZUELA)',
    'vi'         => '0x242a Vietnamese',
#    'ar'         => '0x2401 Arabic (YEMEN)',
#    'en'         => '0x3009 English (ZIMBABWE)',
    #''         => '',
);

my %hhk_global_property = (
   'ImageType' => 'Folder',
);

my %hhc_global_property = (
   'ImageType' => 'Folder',
);


# at least kchmviewer has trouble with the corresponding textual entities
foreach my $thing ('OE', 'oe', 'euro') {
  texinfo_register_no_arg_command_formatting($thing, undef,
                   $Texinfo::Convert::Unicode::unicode_entities{$thing});
}

sub chm_noop($$)
{
  return '';
}

sub _chm_convert_tree_to_text($$)
{
  my $converter = shift;
  my $tree = shift;

  return &{$converter->formatting_function('format_protect_text')}($converter,
    Texinfo::Convert::Text::convert_to_text($tree,
                                 $converter->{'convert_text_options'}));
}

sub chm_init($)
{
  my $self = shift;

  return 0 if (defined($self->get_conf('OUTFILE'))
        and $Texinfo::Common::null_device_file{$self->get_conf('OUTFILE')});

  my $verbose = $self->get_conf('VERBOSE');

  my $document_name = $self->get_info('document_name');
  my $outdir = $self->get_info('destination_directory');
  $outdir = File::Spec->curdir() if ($outdir eq '');

  my $hhk_filename = $document_name . ".hhk";
  my $hhk_file_path_name = join('/', ($outdir, $hhk_filename));
  my ($encoded_hhk_file_path_name, $hhk_path_encoding)
    = $self->encoded_output_file_name($hhk_file_path_name);
  my ($hhk_fh, $hhk_error_message)
     = Texinfo::Convert::Utils::output_files_open_out(
                      $self->output_files_information(), $self,
                      $encoded_hhk_file_path_name);
  if (!defined($hhk_fh)) {
    $self->converter_document_error(
         sprintf(__("chm.pm: could not open %s for writing: %s\n"),
                  $hhk_file_path_name, $hhk_error_message));
    return 1;
  }
  print STDERR "# chm: writing HTML Help index in $hhk_file_path_name...\n"
     if ($verbose);
  print $hhk_fh "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML//EN\">\n<HTML>\n";
  print $hhk_fh "<HEAD>\n<meta name=\"GENERATOR\" content=\""
   .$self->get_conf('PROGRAM') ."\">\n";
  print $hhk_fh "<!-- Sitemap 1.0 -->\n</HEAD>\n<BODY>\n";
  print $hhk_fh "<OBJECT type=\"text/site properties\">\n";
  foreach my $property (sort(keys(%hhk_global_property))) {
    print $hhk_fh "<param name=\"$property\" value=\"$hhk_global_property{$property}\">\n";
  }
  print $hhk_fh "</OBJECT>\n";

  my $document = $self->get_info('document');
  my $indices_information;
  my $sections_list;
  if ($document) {
    $indices_information = $document->indices_information();
    $sections_list = $document->sections_list();
  }

  my $index_entries;
  if ($indices_information) {
    $index_entries = $self->get_converter_indices_sorted_by_index();
  }

  if ($index_entries) {
    foreach my $index_name (sort(keys(%$index_entries))) {
      foreach my $index_entry_ref (@{$index_entries->{$index_name}}) {
        my $main_entry_element = $index_entry_ref->{'entry_element'};
        my $entry_index_name = $index_entry_ref->{'index_name'};
        # do not register index entries that do not point to the document
        next if ($main_entry_element->{'extra'}
                 and ($main_entry_element->{'extra'}->{'seeentry'}
                      or $main_entry_element->{'extra'}->{'seealso'}));
        my $origin_href = $self->command_href($main_entry_element, '');
        my $entry_content_element
              = Texinfo::Common::index_content_element($main_entry_element);
        my $in_code = 0;
        $in_code = 1
          if ($indices_information->{$index_entry_ref->{'index_name'}}->{'in_code'});
        if ($in_code) {
          Texinfo::Convert::Text::set_options_code(
                                 $self->{'convert_text_options'});
        }
        my $entry = _chm_convert_tree_to_text($self,
                                              $entry_content_element);
        if ($in_code) {
          Texinfo::Convert::Text::reset_options_code(
                                 $self->{'convert_text_options'});
        }
        print $hhk_fh "<LI> <OBJECT type=\"text/sitemap\">\n"
                      ."<param name=\"Name\" value=\"$entry\">\n"
                      ."<param name=\"Local\" value=\"$origin_href\">\n"
                      ."</OBJECT> </LI>\n"
         if ($entry =~ /\S/);
      }
    }
  }
  print $hhk_fh "</BODY>\n</HTML>\n";
  Texinfo::Convert::Utils::output_files_register_closed(
    $self->output_files_information(), $encoded_hhk_file_path_name);
  if (!close ($hhk_fh)) {
    $self->converter_document_error(
           sprintf(__("chm.pm: error on closing %s: %s"),
                          $hhk_file_path_name, $!));
    return 1;
  }

  my $hhc_filename = $document_name . ".hhc";
  my $hhc_file_path_name = join('/', ($outdir, $hhc_filename));
  my ($encoded_hhc_file_path_name, $hhc_path_encoding)
    = $self->encoded_output_file_name($hhc_file_path_name);
  my ($hhc_fh, $hhc_error_message)
       = Texinfo::Convert::Utils::output_files_open_out(
                      $self->output_files_information(), $self,
                      $encoded_hhc_file_path_name);
  if (!defined($hhc_fh)) {
    $self->converter_document_error(
         sprintf(__("chm.pm: could not open %s for writing: %s\n"),
                  $hhc_file_path_name, $hhc_error_message));
    return 1;
  }

  print STDERR "# chm: writing HTML Help project in $hhc_file_path_name...\n"
     if ($verbose);

  print $hhc_fh "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML//EN\">\n<HTML>\n";
  print $hhc_fh "<HEAD>\n<meta name=\"GENERATOR\" content=\""
   .$self->get_conf('PROGRAM') ."\">\n";
  print $hhc_fh "<!-- Sitemap 1.0 -->\n</HEAD>\n<BODY>\n";
  print $hhc_fh "<OBJECT type=\"text/site properties\">\n";
  foreach my $property (sort(keys(%hhc_global_property))) {
    print $hhc_fh "<param name=\"$property\" value=\"$hhc_global_property{$property}\">\n";
  }
  print $hhc_fh "</OBJECT>\n";

  if ($sections_list) {
    my $section_root = $sections_list->[0]
                                         ->{'extra'}->{'sectioning_root'};
    my $upper_level = $section_root->{'extra'}->{'section_childs'}->[0]
                                               ->{'extra'}->{'section_level'};
    foreach my $top_section (@{$section_root->{'extra'}->{'section_childs'}}) {
      $upper_level = $top_section->{'extra'}->{'section_level'}
      if ($top_section->{'extra'}->{'section_level'} < $upper_level);
    }
    $upper_level = 1 if ($upper_level <= 0);
    my $root_level = $upper_level - 1;
    my $level = $root_level;
    foreach my $section (@{$sections_list}) {
      next if ($section->{'cmdname'} eq 'part');
      my $section_level = $section->{'extra'}->{'section_level'};
      $section_level = 1 if ($section_level == 0);
      if ($level < $section_level) {
        while ($level < $section_level) {
          print $hhc_fh "<UL>\n";
          $level++;
        }
      } elsif ($level > $section->{'extra'}->{'section_level'}) {
        while ($level > $section_level) {
          print $hhc_fh "</UL>\n";
          $level--;
        }
      }
      my $text = _chm_convert_tree_to_text($self, $section->{'args'}->[0]);
      # should not be needed as end of lines are not converted, end of line
      # can be added with invalid nestings.
      chomp($text);
      $text
        = Texinfo::Convert::Utils::add_heading_number($self,$section, $text,
                                         $self->get_conf('NUMBER_SECTIONS'));
      # the empty string as second argument makes sure that the
      # source file is different from the target file.
      my $origin_href = $self->command_href($section, '');
      print $hhc_fh "<LI> <OBJECT type=\"text/sitemap\">\n<param name=\"Name\" value=\"$text\">\n<param name=\"Local\" value=\"$origin_href\">\n</OBJECT> </LI>\n";
    }
    while ($level > $root_level) {
      print $hhc_fh "</UL>\n";
      $level--;
    }
  }
  print $hhc_fh "</HTML>\n</BODY>\n";
  Texinfo::Convert::Utils::output_files_register_closed(
    $self->output_files_information(), $encoded_hhc_file_path_name);
  if (!close ($hhc_fh)) {
    $self->converter_document_error(
           sprintf(__("chm.pm: error on closing %s: %s"),
                          $hhc_file_path_name, $!));
    return 1;
  }

  my $hhp_filename = $document_name . ".hhp";
  my $hhp_file_path_name = join('/', ($outdir, $hhp_filename));
  my ($encoded_hhp_file_path_name, $hhp_path_encoding)
    = $self->encoded_output_file_name($hhp_file_path_name);
  my ($hhp_fh, $hhp_error_message)
       = Texinfo::Convert::Utils::output_files_open_out(
                      $self->output_files_information(), $self,
                      $encoded_hhp_file_path_name);
  if (!defined($hhp_fh)) {
    $self->converter_document_error(
           $self, sprintf(__("chm.pm: could not open %s for writing: %s\n"),
                  $hhp_file_path_name, $hhp_error_message));
    return 1;
  }
  print STDERR "# chm: writing HTML Help project in $hhp_file_path_name...\n"
     if ($verbose);
  my $language = $chm_languages{'en'};
  my $documentlanguage = $self->get_conf('documentlanguage');
  $documentlanguage =~ s/_.*//;
  if (exists ($chm_languages{$documentlanguage})) {
    $language = $chm_languages{$documentlanguage};
  }
  my $title = _chm_convert_tree_to_text($self, $self->get_info('title_tree'));
  my $top_file = '';
  my $top_element = $self->global_direction_unit('Top');
  if ($top_element) {
    $top_file = $top_element->{'unit_filename'};
  }

  print $hhp_fh <<EOT;
[OPTIONS]
Compatibility=1.1 or later
Compiled file=$document_name.chm
Contents file=$hhc_filename
Default Window=Default
Default topic=$top_file
Display compile progress=No
Full-text search=Yes
Index file=$hhk_filename
Language=$language
Title=$title

[WINDOWS]
Default=,"$hhc_filename","$hhk_filename","$top_file","$top_file",,,,,0x22520,,0x384e,,,,,,,,0

[FILES]
EOT

  my %chm_files;
  if ($self->{'document_units'}) {
    foreach my $element (@{$self->{'document_units'}}) {
      if (!$chm_files{$element->{'unit_filename'}}) {
        print $hhp_fh "$element->{'unit_filename'}\n";
        $chm_files{$element->{'unit_filename'}} = 1;
      }
    }
  }

  Texinfo::Convert::Utils::output_files_register_closed(
    $self->output_files_information(), $encoded_hhp_file_path_name);
  if (!close ($hhp_fh)) {
    $self->converter_document_error(
         sprintf(__("chm.pm: error on closing %s: %s"),
                          $hhp_file_path_name, $!));
    return 1;
  }

  return 0;
}
texinfo_register_handler('init', \&chm_init);


1;
