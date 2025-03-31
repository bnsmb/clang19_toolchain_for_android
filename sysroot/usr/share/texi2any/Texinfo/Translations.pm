# Translations.pm: translate strings in output.
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

# This code is used for output documents strings translations, not for
# error messages translations.

package Texinfo::Translations;

use 5.006;
use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Encode;
use POSIX qw(setlocale LC_ALL LC_MESSAGES);
#use Carp qw(confess);
use Carp qw(cluck);
use Locale::Messages;

# note that there is a circular dependency with the parser module, as
# the parser uses complete_indices() from this modules, while this module
# uses a parser.  This is not problematic, however, as the
# modules do not setup data such that their order of loading is not
# important, as long as they load after their dependencies.

use Texinfo::DocumentXS;

use Texinfo::Convert::Unicode;

# to load a parser
use Texinfo::Parser;

use Texinfo::ManipulateTree;

our $VERSION = '7.2';

# we want a reliable way to switch locale for the document
# strings translations so we don't use the system gettext.
Locale::Messages->select_package ('gettext_pp');

our $module_loaded = 0;
sub import {
  if (!$module_loaded) {
    Texinfo::XSLoader::override(
      "Texinfo::Translations::_XS_configure",
      "Texinfo::DocumentXS::configure_output_strings_translations");
    # Example of how gdt could be overriden.  Not used because
    # the approach is flawed as there won't be any substitution if the trees in
    # $replaced_substrings are not registered in C data, as is the case in
    # general.
    #Texinfo::XSLoader::override(
    #  "Texinfo::Translations::gdt",
    #  "Texinfo::DocumentXS::gdt");
    $module_loaded = 1;
  }
  # The usual import method
  goto &Exporter::import;
}

# i18n

my $DEFAULT_LANGUAGE = 'en';

my $messages_textdomain = 'texinfo';
my $strings_textdomain = 'texinfo_document';

sub _XS_configure($;$$)
{
  # do nothing if there is no XS code loaded
}

sub configure($;$)
{
  my $localesdir = shift;
  my $in_strings_textdomain = shift;

  if (defined($in_strings_textdomain)) {
    $strings_textdomain = $in_strings_textdomain;
  }
  if (defined($localesdir)) {
    Locale::Messages::bindtextdomain($strings_textdomain, $localesdir);
    # set the directory for the XS code too
    _XS_configure($localesdir, $strings_textdomain);
  } else {
    warn 'WARNING: string textdomain directory undefined'."\n";
  }
}

# libintl converts between encodings but doesn't decode them into the
# perl internal format.
sub _decode_i18n_string($$)
{
  my $string = shift;
  my $encoding = shift;
  #if (!defined($encoding)) {
  #  confess("_decode_i18n_string $string undef encoding\n");
  #}
  return Encode::decode($encoding, $string);
}

sub _switch_messages_locale
{
  my $locale;
  our $working_locale;
  if ($working_locale) {
    $locale = POSIX::setlocale(LC_MESSAGES, $working_locale);
  }
  if (!$locale) {
    $locale = POSIX::setlocale(LC_MESSAGES, "en_US.UTF-8");
  }
  if (!$locale) {
    $locale = POSIX::setlocale(LC_MESSAGES, "en_US")
  }
  # try the output of 'locale -a' (but only once)
  our $locale_command;
  if (!$locale and !$locale_command) {
    $locale_command = "locale -a";
    my @local_command_locales = split("\n", `$locale_command`);
    if ($? == 0) {
      foreach my $try (@local_command_locales) {
        next if $try eq 'C' or $try eq 'POSIX';
        $locale = POSIX::setlocale(LC_MESSAGES, $try);
        last if $locale;
      }
    }
  }
  $working_locale = $locale;
}

# Return a translated string.
# $LANG set the language if set.  If undef, the $DEFAULT_LANGUAGE variable
# is used.
# NOTE If called from a converter, $LANG will in general be set from the
# document documentlanguage when it is encountered.  Before the first
# @documentlanguage, it depends on the converter.  Some do not set
# @documentlanguage before it is encountered.  Some set some default
# based on @documentlanguage if in the preamble, some set some default
# language (in general en) in any case.
# Can be replaced by a call to a user-supplied function in gdt* with a
# different prototype.
sub translate_string($$;$)
{
  my ($string, $lang, $translation_context) = @_;

  # language is not checked if set as a customization variable, in that
  # case it could be the empty string or any other string.
  $lang = $DEFAULT_LANGUAGE if (!defined($lang) or $lang eq '');

  my ($saved_LC_MESSAGES, $saved_LANGUAGE);

  # We need to set LC_MESSAGES to a valid locale other than "C" or "POSIX"
  # for translation via LANGUAGE to work.  (The locale is "C" if the
  # tests are being run.)
  #   LC_MESSAGES was reported not to exist for Perl on MS-Windows.  We
  # could use LC_ALL instead, but (a) it's not clear if this would help,
  # and (b) this could interfere with the LC_CTYPE setting in XSParagraph.

  if ($^O ne 'MSWin32') {
    $saved_LC_MESSAGES = POSIX::setlocale(LC_MESSAGES);
    _switch_messages_locale();
  }
  $saved_LANGUAGE = $ENV{'LANGUAGE'};

  Locale::Messages::textdomain($strings_textdomain);

  Locale::Messages::bind_textdomain_codeset($strings_textdomain, 'UTF-8');
  Locale::Messages::bind_textdomain_filter($strings_textdomain,
                          \&_decode_i18n_string, 'UTF-8');
  # Previously we used the encoding used for input or output to be converted
  # to and then decoded to the perl internal encoding.  But it should be safer
  # to use UTF-8 as we cannot know in advance if the encoding actually used
  # is compatible with the specified encoding, while it should be compatible
  # with UTF-8.  If there are actually characters that cannot be encoded in the
  # output encoding issues will still show up when encoding to output, though.
  # Should be more similar with code used in XS modules, too.
  # As a side note, the best could have been to directly decode using the
  # charset used in the po/gmo files, but it does not seems to be available.

  my @langs = ($lang);
  if ($lang =~ /^([a-z]+)_([A-Z]+)/) {
    my $main_lang = $1;
    my $region_code = $2;
    push @langs, $main_lang;
  }

  my $locales = join(':', @langs);

  Locale::Messages::nl_putenv("LANGUAGE=$locales");

  my $translated_string;

  if (defined($translation_context)) {
    $translated_string = Locale::Messages::pgettext($translation_context,
                                                     $string);
  } else {
    $translated_string = Locale::Messages::gettext($string);
  }

  Locale::Messages::textdomain($messages_textdomain);

  if (!defined($saved_LANGUAGE)) {
    delete ($ENV{'LANGUAGE'});
  } else {
    $ENV{'LANGUAGE'} = $saved_LANGUAGE;
  }

  if ($^O ne 'MSWin32') {
    if (defined($saved_LC_MESSAGES)) {
      POSIX::setlocale(LC_MESSAGES, $saved_LC_MESSAGES);
    } else {
      POSIX::setlocale(LC_MESSAGES, '');
    }
  }
  #print STDERR "_GDT '$string' '$translated_string'\n";
  return $translated_string;
}

# Get document translation - handle translations of in-document strings.
# Return a parsed Texinfo tree.
# $TRANSLATED_STRING_METHOD is optional.  If set, it is called instead
# of translate_string.  $TRANSLATED_STRING_METHOD takes
# $CUSTOMIZATION_INFORMATION as first argument in addition to other
# translate_string arguments.
sub gdt($;$$$$$$)
{
  my ($string, $lang, $replaced_substrings, $debug_level,
      $translation_context, $customization_information,
      $translate_string_method) = @_;

  my $translated_string;
  if ($translate_string_method) {
    $translated_string = &$translate_string_method($customization_information,
                                       $string, $lang, $translation_context);
  } else {
    $translated_string = translate_string($string, $lang, $translation_context);
  }

  my $result_tree
    = _replace_convert_substrings($translated_string, $replaced_substrings,
                                  $debug_level);
  #print STDERR "GDT '$string' '$translated_string' '".
  #     Texinfo::Convert::Texinfo::convert_to_texinfo($result_tree)."'\n";
  return $result_tree;
}

# Get document translation - handle translations of in-document strings.
# In general for already converted strings that do not need to go through
# a Texinfo tree.
sub gdt_string($;$$$$$)
{
  my ($string, $lang, $replaced_substrings, $translation_context,
      $customization_information, $translate_string_method) = @_;

  my $translated_string;
  if ($translate_string_method) {
    $translated_string = &$translate_string_method($customization_information,
                                       $string, $lang, $translation_context);
  } else {
    $translated_string = translate_string($string, $lang, $translation_context);
  }

  return _replace_substrings ($translated_string, $replaced_substrings);
}

sub _replace_substrings($;$)
{
  my $translated_string = shift;
  my $replaced_substrings = shift;

  my $translation_result = $translated_string;

  if (defined($replaced_substrings) and ref($replaced_substrings)) {
    my $re = join '|', map { quotemeta $_ } keys %$replaced_substrings;
    $translation_result
  =~ s/\{($re)\}/defined $replaced_substrings->{$1} ? $replaced_substrings->{$1} : "{$1}"/ge;
  }
  return $translation_result;
}

sub _replace_convert_substrings($;$$)
{
  my $translated_string = shift;
  my $replaced_substrings = shift;
  my $debug_level = shift;

  my $texinfo_line = $translated_string;

  # we change the substituted brace-enclosed strings to internal
  # values marked by @txiinternalvalue such that their location
  # in the Texinfo tree can be marked.  They are substituted
  # after the parsing in the final tree.
  # Using a special command that is invalid unless a special
  # configuration is set means that there should be no clash
  # with @-commands used in translations.
  if (defined($replaced_substrings) and ref($replaced_substrings)) {
    my $re = join '|', map { quotemeta $_ } keys %$replaced_substrings;
    $texinfo_line =~ s/\{($re)\}/\@txiinternalvalue\{$1\}/g;
  }

  # accept @txiinternalvalue as a valid Texinfo command, used to mark
  # location in tree of substituted brace enclosed strings.
  my $parser_conf = {'accept_internalvalue' => 1,
           # Ignore index and user-defined commands.
                     'NO_INDEX' => 1,
                     'NO_USER_COMMANDS' => 1,};

  # set parser debug level to one less than $debug_level
  if (defined($debug_level)) {
    my $parser_debug_level = $debug_level;
    if ($parser_debug_level > 0) {
      $parser_debug_level--;
    }
    $parser_conf->{'DEBUG'} = $parser_debug_level;
  }
  my $parser = Texinfo::Parser::parser($parser_conf);

  if ($debug_level) {
    print STDERR "IN TR PARSER '$texinfo_line'\n";
  }

  my $tree = $parser->parse_texi_line($texinfo_line, undef, 1);
  my ($errors, $errors_count) = $parser->errors();
  if ($errors_count) {
    warn "translation $errors_count error(s)\n";
    warn "translated string: $translated_string\n";
    warn "Error messages: \n";
    foreach my $error_message (@$errors) {
      warn $error_message->{'error_line'};
    }
  }
  $tree = _substitute($tree, $replaced_substrings);
  if ($debug_level) {
    print STDERR "RESULT GDT: '".
       Texinfo::Convert::Texinfo::convert_to_texinfo($tree)."'\n";
  }
  return $tree;
}

sub _substitute($$);
sub _substitute_element_array($$) {
  my $array = shift;
  my $replaced_substrings = shift;

  my $nr = scalar(@$array);

  for (my $idx = 0; $idx < $nr; $idx++) {
    my $element = $array->[$idx];
    if (!defined($element->{'text'})) {
      if ($element->{'cmdname'}
          and $element->{'cmdname'} eq 'txiinternalvalue') {
        my $name = $element->{'args'}->[0]->{'contents'}->[0]->{'text'};
        if ($replaced_substrings->{$name}) {
          $array->[$idx] = $replaced_substrings->{$name};
        }
      } else {
        _substitute($element, $replaced_substrings);
      }
    }
  }
}

# Recursively substitute @txiinternalvalue elements in $TREE with
# their values given in $CONTEXT.
sub _substitute($$) {
  my $tree = shift;
  my $replaced_substrings = shift;

  if ($tree->{'contents'}) {
    _substitute_element_array($tree->{'contents'}, $replaced_substrings);
  }

  if ($tree->{'args'}) {
    _substitute_element_array($tree->{'args'}, $replaced_substrings);
  }

  return $tree;
}

# Same as gdt but with mandatory translation context, used for marking
# of strings with translation contexts
sub pgdt($$;$$$)
{
  my ($translation_context, $string,
      $lang, $replaced_substrings, $debug_level) = @_;
  return gdt($string, $lang, $replaced_substrings, $debug_level,
             $translation_context, $debug_level);
}

# For some @def* commands, we delay storing the contents of the
# index entry until now to avoid needing Texinfo::Translations::gdt
# in the main code of ParserNonXS.pm.
sub complete_indices($;$)
{
  my $index_names = shift;
  my $debug_level = shift;

  foreach my $index_name (sort(keys(%{$index_names}))) {
    next if (not defined($index_names->{$index_name}->{'index_entries'}));
    foreach my $entry (@{$index_names->{$index_name}->{'index_entries'}}) {
      my $main_entry_element = $entry->{'entry_element'};
      if ($main_entry_element->{'extra'}
          and $main_entry_element->{'extra'}->{'def_command'}
          and not $main_entry_element->{'extra'}->{'def_index_element'}) {
        my ($name, $class);
        if ($main_entry_element->{'args'}->[0]->{'contents'}) {
          foreach my $arg (@{$main_entry_element->{'args'}->[0]->{'contents'}}) {
            my $type = $arg->{'type'};
            if ($type eq 'def_name') {
              $name = $arg;
            } elsif ($type eq 'def_class') {
              $class = $arg;
            } elsif ($type eq 'def_arg' or $type eq 'def_typearg'
                     or $type eq 'delimiter') {
              last;
            }
          }
        }

        if ($name and $class) {
          my ($index_entry, $text_element);
          my $index_entry_normalized = {};

          my $def_command = $main_entry_element->{'extra'}->{'def_command'};

          my $class_copy = Texinfo::ManipulateTree::copy_treeNonXS($class);
          my $name_copy = Texinfo::ManipulateTree::copy_treeNonXS($name);
          my $ref_class_copy = Texinfo::ManipulateTree::copy_treeNonXS($class);
          my $ref_name_copy = Texinfo::ManipulateTree::copy_treeNonXS($name);

          # Use the document language that was current when the command was
          # used for getting the translation.
          my $entry_language
             = $main_entry_element->{'extra'}->{'documentlanguage'};
          if ($def_command eq 'defop'
              or $def_command eq 'deftypeop'
              or $def_command eq 'defmethod'
              or $def_command eq 'deftypemethod') {
  # TRANSLATORS: association of a method or operation name with a class
  # in descriptions of object-oriented programming methods or operations.
            $index_entry = gdt('{name} on {class}', $entry_language,
                               {'name' => $name_copy, 'class' => $class_copy},
                               $debug_level);
            $text_element = {'text' => ' on ',
                             'parent' => $index_entry_normalized};
          } elsif ($def_command eq 'defcv'
                   or $def_command eq 'defivar'
                   or $def_command eq 'deftypeivar'
                   or $def_command eq 'deftypecv') {
  # TRANSLATORS: association of a variable or instance variable with
  # a class in descriptions of object-oriented programming variables or
  # instance variable.
            $index_entry = gdt('{name} of {class}', $entry_language,
                               {'name' => $name_copy, 'class' => $class_copy},
                               $debug_level);
            $text_element = {'text' => ' of ',
                             'parent' => $index_entry_normalized};
          }
          $ref_name_copy->{'parent'} = $index_entry_normalized;
          $ref_class_copy->{'parent'} = $index_entry_normalized;
          $index_entry_normalized->{'contents'}
              = [$ref_name_copy, $text_element, $ref_class_copy];

          # prefer a type-less container rather than 'root_line' returned by gdt
          delete $index_entry->{'type'};

          $main_entry_element->{'extra'}->{'def_index_element'} = $index_entry;
          $main_entry_element->{'extra'}->{'def_index_ref_element'}
                                                  = $index_entry_normalized;
        }
      }
    }
  }
}



1;

__END__

=head1 NAME

Texinfo::Translations - Translations of output documents strings for Texinfo modules

=head1 SYNOPSIS

  @ISA = qw(Texinfo::Translations);

  Texinfo::Translations::configure('LocaleData');

  my $tree_translated
    = Texinfo::Translations::gdt('See {reference} in @cite{{book}}',
                           $converter->get_conf('documentlanguage'),
                          {'reference' => $tree_reference,
                           'book'  => {'text' => $book_name}});


=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

The C<Texinfo::Translations> module helps with translations
in output documents.

Translation of error messages is not described here, some
elements are in L<Texinfo::Common C<__> and C<__p>|Texinfo::Common/$translated_string = __($msgid)>.

=head1 METHODS

No method is exported.

The C<configure> method sets the translation files base directory.  If not
called, system defaults are used.

=over

=item configure($localesdir, $strings_textdomain)

I<$localesdir> is the directory where translation files are found. The
directory structure and files format should follow the L<conventions expected
for gettext based
internationalization|https://www.gnu.org/software/gettext/manual/html_node/Locating-Catalogs.html>.
The I<$strings_textdomain> is optional, if set, it determines the translation
domain.

=back

The C<gdt> and C<pgdt> methods are used to translate strings to be output in
converted documents, and return a Texinfo tree.  The C<gdt_string> is similar
but returns a simple string, for already converted strings.

=over

=item $tree = gdt($string, $lang, $replaced_substrings, $translation_context, $debug_level, $object, $translate_string_method)

=item $string = gdt_string($string, $lang, $replaced_substrings, $translation_context, $object, $translate_string_method)

X<C<gdt>> X<C<gdt_string>>

The I<$string> is a string to be translated.  With C<gdt>
the function returns a Texinfo tree, as the string is interpreted
as Texinfo code after translation.  With C<gdt_string> a string
is returned.

I<$lang> is the language used for the translation.

I<$replaced_substrings> is an optional hash reference specifying
some substitution to be done after the translation.  The key of the
I<$replaced_substrings> hash reference identifies what is to be substituted.
In the string to be translated word in brace matching keys of
I<$replaced_substrings> are replaced.
For C<gdt>, the value is a Texinfo tree element that is substituted in the
resulting Texinfo tree. For C<gdt_string>, the value is a string that
is replaced in the resulting string.

I<$debug_level> is an optional debugging level supplied to C<gdt>, similar to
the C<DEBUG> customization variable.  If set, the debug level minus one is
passed to the Texinfo string parser called in C<gdt>.

The I<$translation_context> is optional.  If not C<undef> this is a translation
context string for I<$string>.  It is the first argument of C<pgettext>
in the C API of Gettext.

For example, in the following call, the string
C<See {reference} in @cite{{book}}> is translated, then
parsed as a Texinfo string, with I<{reference}> substituted by
I<$tree_reference> in the resulting tree, and I<{book}>
replaced by the associated Texinfo tree text element:

  $tree = gdt('See {reference} in @cite{{book}}', "ca",
              {'reference' => $tree_reference,
               'book'  => {'text' => $book_name}});

By default, C<gdt> and C<gdt_string> call C<translate_string> to use a
gettext-like infrastructure to retrieve the translated strings, using the
I<texinfo_document> domain.  You can change the method used to retrieve the
translated strings by providing a I<$translate_string_method> argument.  If not
undef it should be a reference on a function that is called instead of
C<translate_string>.  The I<$object> is passed as first argument of the
I<$translate_string_method>, the other arguments are the same as
L<< C<translate_string>|/$translated_string = translate_string($string, $lang, $translation_context) >>
arguments.

=item $tree = pgdt($translation_context, $string, $lang, $replaced_substrings, $debug_level)
X<C<pgdt>>

Same to C<gdt> except that the I<$translation_context> is not optional.
Calls C<gdt>.  This function is useful to mark strings with a
translation context for translation.  This function is similar to pgettext
in the Gettext C API.

=back

By default, in C<gdt>, C<gdt_string> and C<pgdt> a string is translated with
C<translate_string>.

=over

=item $translated_string = translate_string($string, $lang, $translation_context)
X<C<translate_string>>

The I<$string> is a string to be translated.  I<$lang> is the language used for
the translation.  The I<$translation_context> is optional.  If not C<undef>
this is a translation context string for I<$string>.  It is the first argument
of C<pgettext> in the C API of Gettext.

C<translate_string> uses a gettext-like infrastructure to retrieve the
translated strings, using the I<texinfo_document> domain.

=back

=head1 SEE ALSO

L<GNU gettext utilities manual|https://www.gnu.org/software/gettext/manual/>.

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
