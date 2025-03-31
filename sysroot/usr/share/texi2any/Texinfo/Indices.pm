# Indices.pm: merge and sort indices
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
#
# Most methods in that module are called from documents or
# converters methods that cache the results.  Therefore, the relevant
# interface is, in the general case, with the document or converter
# when possible.

package Texinfo::Indices;

use 5.006;

# See comment at start of HTML.pm
use if $] >= 5.012, feature => 'unicode_strings';

# Cannot do that because of sort_indices_by_letter, probably for uc().
# stop \s from matching non-ASCII spaces, etc.  \p{...} can still be
# used to match Unicode character classes.
#use if $] >= 5.014, re => '/a';

use strict;

# Can be used to check that there is no incorrect autovivfication
#no autovivification qw(fetch delete exists store strict);

use Carp qw(cluck confess);

use Unicode::Normalize;

use Texinfo::IndicesXS;

use Texinfo::XSLoader;

use Texinfo::Common;
use Texinfo::Convert::Text;

# In general, Texinfo::Document depends on this here module, but there
# is also a dependence to Texinfo::Document through the call to
# Texinfo::Document::indices_sort_strings call, hence a circular dependency.
# It is more natural to have Texinfo::Document import the here module,
# so we do not load Texinfo::Document here.  If we did, there should not be any
# issue, though, as the modules do not setup data such that their order of
# loading is not important.
#use Texinfo::Document;

our $VERSION = '7.2';

# The methods that are usefully called directly (outside of tests) are:
# index_entry_element_sort_string
# setup_index_entry_keys_formatting
# index_entry_first_letter_text_or_command

# There is therefore a full XS coverage of the module as
# index_entry_first_letter_text_or_command has a C implementation, but no
# XS override, because it is only a helper function, if needed the calling
# functions should have XS interfaces.

my $XS_convert = Texinfo::XSLoader::XS_convert_enabled();

# used in conversion only, and should only be loaded with XS converters
my %XS_convert_overrides = (
  "Texinfo::Indices::index_entry_element_sort_string"
    => "Texinfo::IndicesXS::index_entry_element_sort_string",
  "Texinfo::Indices::setup_index_entry_keys_formatting",
    => "Texinfo::IndicesXS::setup_index_entry_keys_formatting",
);

our $module_loaded = 0;
sub import {
  if (!$module_loaded) {
    if ($XS_convert) {
      for my $sub (keys %XS_convert_overrides) {
        Texinfo::XSLoader::override ($sub, $XS_convert_overrides{$sub});
      }
    }
    $module_loaded = 1;
  }
  # The usual import method
  goto &Exporter::import;
}

sub _sort_key($$)
{
  my $a = shift;
  my $b = shift;
  my ($a_value, $a_alpha) = @$a;
  my ($b_value, $b_alpha) = @$b;
  if ($a_alpha == $b_alpha) {
    return ($a_value cmp $b_value);
  }
  return $a_alpha <=> $b_alpha;
}

sub _sort_index_entries($$)
{
  my $key1 = shift;
  my $key2 = shift;

  my $key_index = 0;
  # the keys array corresponds to the main entry and subentries
  foreach my $key1_str (@{$key1->{'keys'}}) {
    my $res = _sort_key($key1_str,
                           $key2->{'keys'}->[$key_index]);
    if ($res != 0) {
      return $res;
    }
    $key_index ++;
    if (scalar(@{$key2->{'keys'}}) <= $key_index) {
      last;
    }
  }
  my $res = (scalar(@{$key1->{'keys'}}) <=> scalar(@{$key2->{'keys'}}));
  if ($res == 0) {
    $res = ($key1->{'number'} <=> $key2->{'number'});
  }
  # This may happen if 2 indices are merged as the number is per
  # index name.
  if ($res == 0) {
    $res = ($key1->{'index_name'} cmp $key2->{'index_name'});
  }
  return $res;
}

# Only called from converters
sub setup_index_entry_keys_formatting($)
{
  my $customization_information = shift;

  my $text_options;

  my $additional_options = {};

  if (not $customization_information->get_conf('ENABLE_ENCODING')
      or ($customization_information->get_conf('OUTPUT_ENCODING_NAME')
          and lc($customization_information->get_conf('OUTPUT_ENCODING_NAME'))
                  ne 'utf-8')) {
    $additional_options->{'sort_string'} = 1;
  }

  $text_options
    = Texinfo::Convert::Text::copy_options_for_convert_text(
                             $customization_information, $additional_options);
  return $text_options;
}

# can be used for subentries.
# $DOCUMENT_INFO is used in XS to retrieve the document.
sub index_entry_element_sort_string($$$$;$)
{
  my $document_info = shift;
  my $main_entry = shift;
  my $index_entry_element = shift;
  my $options = shift;
  my $prefer_reference_element = shift;

  my $sort_string;
  if ($index_entry_element->{'extra'}
      and defined($index_entry_element->{'extra'}->{'sortas'})) {
    $sort_string = $index_entry_element->{'extra'}->{'sortas'};
  } else {
    my $entry_tree_element
      = Texinfo::Common::index_content_element($index_entry_element,
                                               $prefer_reference_element);
    $sort_string = Texinfo::Convert::Text::convert_to_text(
                              $entry_tree_element, $options);
    # TODO do that for sortas too?
    if (defined($main_entry->{'entry_element'}
                       ->{'extra'}->{'index_ignore_chars'})) {
      my $ignore_chars = quotemeta($main_entry->{'entry_element'}
                                  ->{'extra'}->{'index_ignore_chars'});
      if ($ignore_chars ne '') {
        $sort_string =~ s/[$ignore_chars]//g;
      }
    }
  }
  return $sort_string;
}

# This is a stub for the Unicode::Collate module.  Although this module is
# a core Perl module, some distributions may install a stripped-down Perl
# that doesn't include it, so providing this fall-back allows texi2any
# to run in such cases.  Using this fall-back will change index sorting,
# especially of punctuation characters and in non-English manuals.
#
# This fall-back also allows checking the performance impact of
# Unicode::Collate (last checked as about a 5% increase in runtime for
# typical Info output).

package Texinfo::CollateStub;

sub new($%) {
  my $class = shift;
  my %options = @_;

  my $self = {};
  bless $self, $class;
  return $self;
}

sub getSortKey($$) {
  my $self = shift;
  my $string = shift;

  return $string;
}

package Texinfo::Indices;

sub _setup_collator($$)
{
  my $use_unicode_collation = shift;
  my $locale_lang = shift;

  my $collator;

  # The 'Non-Ignorable' for variable collation elements means that they are
  # treated as normal characters.   This allows to have spaces and punctuation
  # marks sort before letters.
  # http://www.unicode.org/reports/tr10/#Variable_Weighting
  my %collate_options = ( 'variable' => 'Non-Ignorable' );

  # The Unicode::Collate sorting changes often, based on the UCA version.
  # To test the result with a specific version, the UCA_Version should be set,
  # and, more importantly the table should correspond to that version.
  # To test a specific table, in tp, do
  # wget -N http://www.unicode.org/Public/UCA/6.2.0/allkeys.txt
  # mkdir -p Unicode/Collate/
  # mv allkeys.txt Unicode/Collate/allkeys-6.2.0.txt
  # The table argument leads to a very important slowdown, so the argument
  # should only be used for checks.
  # The test results seem to be consistent with 6.2.0, corresponding
  # to the perl 5.18.0 Unicode::Collate

  # to test for 6.2.0
  #%collate_options = (%collate_options,
  #                    'UCA_Version' => 24,
  #                    'table' => 'allkeys-6.2.0.txt');
  # To test files affected for UCA corresponding to perl 5.8.1
  # wget -N http://www.unicode.org/Public/UCA/3.1.1/allkeys-3.1.1.txt
  #%collate_options = (%collate_options,
  #                   'UCA_Version' => 9,
  #                   'table' => 'allkeys-3.1.1.txt');

  if (!(defined($use_unicode_collation) and !$use_unicode_collation)) {
    # Unicode::Collate::Locale is present in perl core since perl major
    # version 5.14 released in 2011.
    if (defined($locale_lang)) {
      eval { require Unicode::Collate::Locale;
             Unicode::Collate::Locale->import; };
      my $unicode_collate_locale_loading_error = $@;
      if ($unicode_collate_locale_loading_error eq '') {
        $collator = Unicode::Collate::Locale->new('locale' => $locale_lang,
                                                  %collate_options);
      }
    }

    if (!defined($collator)) {
      eval { require Unicode::Collate; Unicode::Collate->import; };
      my $unicode_collate_loading_error = $@;
      if ($unicode_collate_loading_error eq '') {
        $collator = Unicode::Collate->new(%collate_options);
      }
    }
  }
  # Fall back to stub if Unicode::Collate not wanted or not available.
  $collator = Texinfo::CollateStub->new() if (!defined($collator));

  return $collator;
}

# Not documented, as, in general, it should not be called directly, but
# through Texinfo::Document::indices_sort_strings that caches the
# result in the document, itself, in general, called through sorting functions.
sub setup_index_entries_sort_strings($$$$;$)
{
  my $registrar = shift;
  my $customization_information = shift;
  my $index_entries = shift;
  my $indices_information = shift;
  my $prefer_reference_element = shift;

  return undef unless ($index_entries);

  # convert index entries to sort string using unicode when possible
  # independently of input and output encodings
  my $convert_text_options = {};
  $convert_text_options->{'enabled_encoding'} = 'utf-8';
  # It could be possible to set INCLUDE_DIRECTORIES, but there is no
  # point doing so, as it is only useful for @verbatiminclude, which
  # cannot appear in index entries.
  #$convert_text_options->{'INCLUDE_DIRECTORIES'}
  #   = $customization_information->get_conf('INCLUDE_DIRECTORIES');

  my $indices_sort_strings = {};
  foreach my $index_name (keys(%$index_entries)) {
    my $index_entries_sort_strings = [];
    foreach my $index_entry (@{$index_entries->{$index_name}}) {
      my $entry_index_name = $index_entry->{'index_name'};
      my $main_entry_element = $index_entry->{'entry_element'};
      my $in_code = $indices_information->{$entry_index_name}->{'in_code'};
      if ($in_code) {
        Texinfo::Convert::Text::set_options_code($convert_text_options);
      }
      my $entry_sort_string
        = index_entry_element_sort_string($customization_information,
                               $index_entry, $main_entry_element,
                           $convert_text_options, $prefer_reference_element);
      my $non_empty_index_subentries = 0;
      my @entry_sort_strings;
      if ($entry_sort_string !~ /\S/) {
        my $entry_cmdname = $main_entry_element->{'cmdname'};
        $entry_cmdname
          = $main_entry_element->{'extra'}->{'original_def_cmdname'}
           if (!defined($entry_cmdname));
        Texinfo::Common::converter_or_registrar_line_warn($registrar,
                                   $customization_information,
                       sprintf(__("empty index key in \@%s"),
                                  $entry_cmdname),
                               $main_entry_element->{'source_info'});
        push @entry_sort_strings, '';
      } else {
        push @entry_sort_strings, $entry_sort_string;
        $non_empty_index_subentries++;
      }
      my $subentry_nr = 0;
      my $subentry = $main_entry_element;
      while ($subentry->{'extra'} and $subentry->{'extra'}->{'subentry'}) {
        $subentry_nr ++;
        $subentry = $subentry->{'extra'}->{'subentry'};
        my $subentry_sort_string
              = index_entry_element_sort_string($customization_information,
                             $index_entry, $subentry, $convert_text_options);
        if ($subentry_sort_string !~ /\S/) {
          my $entry_cmdname = $main_entry_element->{'cmdname'};
          $entry_cmdname
            = $main_entry_element->{'extra'}->{'original_def_cmdname'}
              if (!defined($entry_cmdname));
          Texinfo::Common::converter_or_registrar_line_warn($registrar,
                                $customization_information,
                         sprintf(__("empty index sub entry %d key in \@%s"),
                                    $subentry_nr, $entry_cmdname),
                                  $main_entry_element->{'source_info'});
          push @entry_sort_strings, '';
        } else {
          push @entry_sort_strings, $subentry_sort_string;
          $non_empty_index_subentries++;
        }
      }
      if ($non_empty_index_subentries > 0) {
        my $subentries_alpha_strings;
        for (my $i = 0; $i < scalar (@entry_sort_strings); $i++) {
          my $alpha = 0;
          if ($entry_sort_strings[$i] =~ /^[[:alpha:]]/) {
            $alpha = 1;
          }
          push @$subentries_alpha_strings,
             {'sort_string' => $entry_sort_strings[$i], 'alpha' => $alpha};
        }
        push @{$index_entries_sort_strings}, {'entry' => $index_entry,
                              'sort_strings' => $subentries_alpha_strings,
                                 'number' => $index_entry->{'entry_number'},
                              'index_name' => $entry_index_name};
      }
      if ($in_code) {
        Texinfo::Convert::Text::reset_options_code($convert_text_options);
      }
    }
    $indices_sort_strings->{$index_name} = $index_entries_sort_strings;
  }

  return $indices_sort_strings;
}

# Returns a hash reference associating the index entries with the strings
# that were used to sort them.
# Used in tests, but not documented, as it is unlikely for this function
# to be of any direct use for users.
sub format_index_entries_sort_strings($)
{
  my $indices_sort_strings = shift;
  my $index_entries_sort_strings = {};

  return $index_entries_sort_strings unless ($indices_sort_strings);

  foreach my $index_name (keys(%$indices_sort_strings)) {
    foreach my $index_entry (@{$indices_sort_strings->{$index_name}}) {
      $index_entries_sort_strings->{$index_entry->{'entry'}}
         = join(', ', map {$_->{'sort_string'}}
                          @{$index_entry->{'sort_strings'}});
    }
  }
  return $index_entries_sort_strings;
}

sub _setup_sortable_index_entries($$)
{
  my $collator = shift;
  my $indices_sort_strings = shift;

  return undef unless ($indices_sort_strings);

  my $index_sortable_index_entries = {};
  foreach my $index_name (keys(%$indices_sort_strings)) {
    my $sortable_index_entries = [];
    foreach my $index_entry (@{$indices_sort_strings->{$index_name}}) {
      my @keys_and_alpha;
      foreach my $sort_string_alpha (@{$index_entry->{'sort_strings'}}) {
        my $sort_string = $sort_string_alpha->{'sort_string'};
        # TODO $sort_string is never used directly to sort anymore, so
        # it is possible that utf8::upgrade is not needed anymore.  To be safe,
        # we can keep it until we only support perl > 5.12.
        # This avoids varying results depending on whether the string is
        # represented internally in UTF-8.  See 'the "Unicode bug"' in the
        # "perlunicode" man page.
        utf8::upgrade($sort_string);
        my $sort_key = $collator->getSortKey(uc($sort_string));
        push @keys_and_alpha, [$sort_key, $sort_string_alpha->{'alpha'}];

      }
      my $sortable_entry = {'entry' => $index_entry->{'entry'},
                            'keys' => \@keys_and_alpha,
                            'entry_strings_alpha' => $index_entry->{'sort_strings'},
                            'number' => $index_entry->{'number'},
                            'index_name' => $index_entry->{'index_name'}};
      push @{$sortable_index_entries}, $sortable_entry;
    }
    $index_sortable_index_entries->{$index_name} = $sortable_index_entries;
  }

  return $index_sortable_index_entries;
}

sub _setup_sort_sortable_strings_collator($$$$$)
{
  my $document = shift;
  my $registrar = shift;
  my $customization_information = shift;
  my $use_unicode_collation = shift;
  my $locale_lang = shift;

  # simple wrapper around setup_index_entries_sort_strings that caches the
  # result
  my $indices_sort_strings = Texinfo::Document::indices_sort_strings($document,
                                                   $customization_information);

  my $collator = _setup_collator($use_unicode_collation, $locale_lang);

  my $index_sortable_index_entries
    = _setup_sortable_index_entries($collator, $indices_sort_strings);

  return ($index_sortable_index_entries, $collator);
}

# Normally called through Texinfo::Document::sorted_indices_by_index only
sub sort_indices_by_index($$$;$$)
{
  my $document = shift;
  my $registrar = shift;
  my $customization_information = shift;
  my $use_unicode_collation = shift;
  my $locale_lang = shift;

  my ($index_sortable_index_entries, $collator)
     = _setup_sort_sortable_strings_collator($document, $registrar,
                       $customization_information, $use_unicode_collation,
                       $locale_lang);

  if (!$index_sortable_index_entries) {
    return undef;
  }

  my $sorted_index_entries = {};
  foreach my $index_name (keys(%$index_sortable_index_entries)) {
    my $sortable_index_entries = $index_sortable_index_entries->{$index_name};
    $sorted_index_entries->{$index_name} = [
         map {$_->{'entry'}} sort {_sort_index_entries($a, $b)}
                                                @{$sortable_index_entries}
       ];
  }
  return $sorted_index_entries;
}

# Return the first non empty text or textual @-command.
# NOTE quotes and dash are not handled especially and it is not known
# if the text was in code or not.
sub _idx_leading_text_or_command($$);
sub _idx_leading_text_or_command($$)
{
  my $tree = shift;
  my $ignore_chars = shift;

  return (undef, undef) if (!$tree->{'contents'});
  foreach my $content (@{$tree->{'contents'}}) {
    if (defined($content->{'text'})) {
      if ($content->{'text'} =~ /\S/) {
        my $result_text = $content->{'text'};
        $result_text =~ s/^\s*//;
        if (defined($ignore_chars)) {
          $result_text =~ s/[$ignore_chars]//g;
          $result_text =~ s/^\s*//;
          next if ($result_text eq '');
        }
        return ($result_text, undef);
      } else {
        next;
      }
    }

    if ($content->{'cmdname'}) {
      my $cmdname = $content->{'cmdname'};
      if ($Texinfo::Commands::formatted_nobrace_commands{$cmdname}) {
        next if (defined($ignore_chars) and $cmdname eq '@'
                 and $ignore_chars =~ /\@/);
        return (undef, $content);
      } else {
        my $brace_command_type = $Texinfo::Commands::brace_commands{$cmdname};
        if (defined($brace_command_type)) {
          if ($Texinfo::Commands::non_formatted_brace_commands{$cmdname}
              or $cmdname eq 'footnote' or $cmdname eq 'dmn'
              or $cmdname eq 'value'
              or $Texinfo::Commands::in_index_commands{$cmdname}) {
            next;
          } elsif ($brace_command_type eq 'accent'
              or $brace_command_type eq 'noarg'
              or $cmdname eq 'U') {
            return (undef, $content);
          } elsif ($brace_command_type ne 'inline') {
            if ($content->{'args'} and scalar(@{$content->{'args'}})) {
              return _idx_leading_text_or_command($content->{'args'}->[0],
                                                  $ignore_chars);
            }
          } else {
            if (defined($content->{'extra'})
                and defined($content->{'extra'}->{'expand_index'})) {
              return _idx_leading_text_or_command($content->{'args'}
                             ->[$content->{'extra'}->{'expand_index'}],
                                                  $ignore_chars);
            }
          }
        } elsif ($Texinfo::Commands::formatted_line_commands{$cmdname}
                 and $cmdname ne 'page'
                 and $content->{'args'}
                 and scalar(@{$content->{'args'}})) {
          return _idx_leading_text_or_command($content->{'args'}->[0],
                                              $ignore_chars);
        }
      }
    } elsif ($content->{'contents'}) {
      return _idx_leading_text_or_command($content, $ignore_chars);
    }
  }
  return (undef, undef);
}

# Return the leading text or textual command that could be used
# for sorting.
sub index_entry_first_letter_text_or_command($;$)
{
  my $index_entry = shift;
  # only used for debugging
  #my $entry_key = shift;

  if (!defined($index_entry)) {
    confess ("index_entry_first_letter_text_or_command: undef index_entry");
  }

  my $index_entry_element = $index_entry->{'entry_element'};
  if ($index_entry_element->{'extra'}
      and defined($index_entry_element->{'extra'}->{'sortas'})) {
    return ($index_entry_element->{'extra'}->{'sortas'}, undef);
  } else {
    my $entry_tree_element = Texinfo::Common::index_content_element(
                                                 $index_entry_element, 0);
    my $ignore_chars;
    if ($index_entry_element->{'extra'}
        and defined($index_entry_element->{'extra'}
                                            ->{'index_ignore_chars'})) {
      $ignore_chars = quotemeta($index_entry_element->{'extra'}
                                            ->{'index_ignore_chars'});
    }
    my $parsed_element;
    if (!$entry_tree_element->{'contents'}) {
      $parsed_element = {'contents' => [$entry_tree_element]};
    } else {
      $parsed_element = $entry_tree_element;
    }

    my ($text, $command) = _idx_leading_text_or_command($parsed_element,
                                                        $ignore_chars);
    #if ($command) {
    #  print STDERR "CCC '$entry_key' "
    #      .Texinfo::Common::debug_print_element($command)."\n";
    #} elsif (defined($text)) {
    #  if (substr($entry_key, 0, 1) ne substr($text, 0, 1)) {
    #    print STDERR "TTT '$entry_key' '$text'\n";
    #  }
    #} else {
    #  print STDERR "III '$entry_key'\n";
    #}
    return ($text, $command);
  }
}

# Normally called through Texinfo::Document::sorted_indices_by_letter only
sub sort_indices_by_letter($$$;$$)
{
  my $document = shift;
  my $registrar = shift;
  my $customization_information = shift;
  my $use_unicode_collation = shift;
  my $locale_lang = shift;

  my ($index_sortable_index_entries, $collator)
     = _setup_sort_sortable_strings_collator($document, $registrar,
                       $customization_information, $use_unicode_collation,
                       $locale_lang);

  if (!$index_sortable_index_entries) {
    return undef;
  }

  my $sorted_index_entries = {};
  foreach my $index_name (keys(%$index_sortable_index_entries)) {
    my $sortable_index_entries = $index_sortable_index_entries->{$index_name};
    my $index_letter_hash = {};
    foreach my $sortable_entry (@{$sortable_index_entries}) {
      my $sort_string
        = $sortable_entry->{'entry_strings_alpha'}->[0]->{'sort_string'};
      # the following line leads to each accented letter being separate
      # $letter = uc(substr($sort_string, 0, 1));
      my $letter_string = uc(substr($sort_string, 0, 1));
      # determine main letter by decomposing and removing diacritics
      my $letter = Unicode::Normalize::NFKD($letter_string);
      $letter =~ s/\p{NonspacingMark}//g;
      # following code is less good, as the upper-casing may lead to
      # two letters in case of the german Eszett that becomes SS.  So
      # it is better to upper-case first and remove diacritics after.
      #my $normalized_string = Unicode::Normalize::NFKD(uc($sort_string));
      #$normalized_string =~ s/\p{NonspacingMark}//g;
      #$letter = substr($normalized_string, 0, 1);

      push @{$index_letter_hash->{$letter}}, $sortable_entry;
    }

    my @letter_keys;
    foreach my $letter (keys %$index_letter_hash) {
      my $sort_key = $collator->getSortKey($letter);
      push @letter_keys, [$sort_key, $letter, $index_letter_hash->{$letter}];
    }

    my @sorted_letters = sort{$a->[0] cmp $b->[0]} @letter_keys;

    foreach my $letter_and_entries (@sorted_letters) {
      my $letter = $letter_and_entries->[1];
      my @sorted_letter_entries
         = map {$_->{'entry'}} sort {_sort_index_entries($a, $b)}
                                            @{$letter_and_entries->[2]};
      push @{$sorted_index_entries->{$index_name}},
        { 'letter' => $letter, 'entries' => \@sorted_letter_entries };
    }
  }
  return $sorted_index_entries;
}

# Normally called through Texinfo::Document::merged_indices only
sub merge_indices($)
{
  my $indices_information = shift;

  my $merged_index_entries;
  foreach my $index_name (keys(%$indices_information)) {
    my $index_info = $indices_information->{$index_name};
    if ($index_info->{'index_entries'}) {
      $merged_index_entries = {} if (! $merged_index_entries);
      my $in_idx_name = $index_name;
      if ($index_info->{'merged_in'}) {
        my $ultimate_idx = Texinfo::Common::ultimate_index($indices_information,
                                                           $index_info);
        $in_idx_name = $ultimate_idx->{'name'};
      }
      push @{$merged_index_entries->{$in_idx_name}},
        @{$index_info->{'index_entries'}};
    }
  }
  return $merged_index_entries;
}


1;

__END__

=head1 NAME

Texinfo::Indices - merging and sorting indices from Texinfo

=head1 SYNOPSIS

  use Texinfo::Indices;

  # $document is a parsed Texinfo::Document document.
  my $indices_information = $document->indices_information();
  my $merged_index_entries
     = Texinfo::Indices::merge_indices($indices_information);

  # $registrar is a Texinfo::Report object.  $config is an object
  # implementing the get_conf() method.
  my $index_entries_sorted;
  if ($sort_by_letter) {
    $index_entries_sorted
      = Texinfo::Indices::sort_indices_by_letter($document, $registrar,
                                                   $config);
  } else {
    $index_entries_sorted
      = Texinfo::Indices::sort_indices_by_index($document, $registrar,
                                                  $config);
  }


=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

C<merge_indices> may be used to merge indices.  Document indices may be sorted
with C<sort_indices_by_index> or C<sort_indices_by_letter>.  Other functions
deal with formatting of index entries as text or getting information on
index entry.

Note that, in general, the functions used to merge or sort indices
should not be called directly, corresponding functions
in L<Texinfo::Document> already call the functions in this module, and,
in addition, cache the result with the document.  Furthermore, it should
be even better to call converter functions, which call document functions.

=head1 METHODS

No method is exported.

=over

=item $sort_string = index_entry_element_sort_string($document_info, $main_entry, $index_entry_element, $options, $prefer_reference_element)
X<C<index_entry_element_sort_string>>

Return a string suitable as a sort string, for index entries.
I<$document_info> is used by C code to retrieve the document data,
using the C<document_descriptor> key.  I<$document_info> can be a
converter based on L<Texinfo::Convert::Converter>, a L<Texinfo::Document>
document, otherwise C<document_descriptor> need, in general, to be
set up explicitely.

The tree element index entry processed is I<$index_entry_element>,
and can be a C<@subentry>.  I<$main_entry> is the main index entry
that can be used to gather information.

The I<$options> are options used for Texinfo to text conversion for the
generation of the sort string.  If the sort string is supposed to be output,
the I<$options> are typically obtained from
L<setup_index_entry_keys_formatting|/$option = setup_index_entry_keys_formatting($customization_information)>.

If I<$prefer_reference_element> is set, prefer an untranslated
element for the formatting as sort string.

=item ($text, $command) = index_entry_first_letter_text_or_command($index_entry)

Return the I<$index_entry> leading text I<$text> or textual command Texinfo
tree hash reference I<$command>.  Here textual commands means accent
commands, brace commands without arguments used for character and glyph
insertion and C<@U>.

This method can in particular be used to format the leading letter
of an index entry using I<$command> instead of the sort string set by
C<sort_indices_by_letter>.

=item $merged_indices = merge_indices($indices_information)
X<C<merge_indices>>

Returns a structure holding all the index entries by index name
with all the entries of merged indices merged with those of the indice
merged into.  The I<$indices_information> argument should be an hash reference
with indices information, it is described in details in
L<< C<Texinfo::Document::indices_information>|Texinfo::Document/$indices_information = $document->indices_information() >>.

The I<$merged_indices> returned is a hash reference whose
keys are the index names and values arrays of index entry structures
described in details in L<Texinfo::Document/index_entries>.

In general, this method should not be called directly, instead
L<< C<Texinfo::Document::merged_indices>|Texinfo::Document/$merged_indices = $document->merged_indices() >>
should be called on a document, which calls C<merge_indices> if needed and
associate the merged indices to the document.

=item $option = setup_index_entry_keys_formatting($customization_information)
X<C<setup_index_entry_keys_formatting>>

Return options relevant for index keys sorting for conversion of Texinfo
to text to be output.

=item $index_entries_sorted = sort_indices_by_index($document, $registrar, $customization_information, $use_unicode_collation, $locale_lang)

=item $index_entries_sorted = sort_indices_by_letter($document, $registrar, $customization_information, $use_unicode_collation, $locale_lang)
X<C<sort_indices_by_index>> X<C<sort_indices_by_letter>>

C<sort_indices_by_letter> sorts by index and letter, while
C<sort_indices_by_index> sort all entries of an index together.
Indices are obtained from I<$document>, and should have been merged
previously, in general by using
L<< C<Texinfo::Document::merged_indices>|Texinfo::Document/$merged_indices = $document->merged_indices() >>.
In both cases, a hash reference with index names as keys I<$index_entries_sorted>
is returned.

By default, indices are sorted according to the I<Unicode Collation Algorithm>
defined in the L<Unicode Technical Standard
#10|http://www.unicode.org/reports/tr10/>, without language-specific collation
tailoring.  If I<$use_unicode_collation> is set to 0, the sorting will not use
the I<Unicode Collation Algorithm> and simply sort according to the codepoints.
If I<$locale_lang> is set, the language is used for linguistic tailoring of the
sorting, if possible.

When sorting by letter, an array reference of letter hash references is
associated with each index name.  Each letter hash reference has two
keys, a I<letter> key with the letter, and an I<entries> key with an array
reference of sorted index entries beginning with the letter.  The letter
is a character string suitable for sorting letters, but is not necessarily
the best to use for output.

When simply sorting, the array of the sorted index entries is associated
with the index name.

The I<$registrar> argument can be set to a L<Texinfo::Report> object.
Error reporting also requires Texinfo customization variables
information, which means an object implementing the C<get_conf> method, a
converter (L<Texinfo::Convert::Converter/Getting and setting customization
variables>) or a document L<Texinfo::Document/Getting customization options
values registered in document>) as I<$customization_information> argument.  If
the I<$registrar> argument is not set, the object used to get customization
information is assumed to be a converter, and the error reporting uses
converters error messages reporting functions
(L<Texinfo::Convert::Converter/Registering error and warning messages>).

In general, those methods should not be called directly, instead
L<< C<Texinfo::Document::sorted_indices_by_index>|Texinfo::Document/$sorted_indices = $document->sorted_indices_by_index($customization_information, $use_unicode_collation, $locale_lang) >>
or L<< C<Texinfo::Document::sorted_indices_by_letter>|Texinfo::Document/$sorted_indices = $document->sorted_indices_by_letter($customization_information, $use_unicode_collation, $locale_lang) >>
should be called on a document. The C<Texinfo::Document> functions call
C<sort_indices_by_index> or C<sort_indices_by_letter> if needed and associate
the sorted indices to the document.

=back

=head1 SEE ALSO

L<Texinfo manual|http://www.gnu.org/s/texinfo/manual/texinfo/>,
L<Texinfo::Document>.

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
