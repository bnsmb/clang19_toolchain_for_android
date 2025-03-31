# ParagraphNonXS.pm: handle paragraph text.
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

# this module has nothing Texinfo specific.  In contrast with existing
# modules Text::Wrap, Text::Format, it keeps a state of the paragraph
# and waits for text to be fed into it.

package Texinfo::Convert::Paragraph;

use 5.006;
use strict;

use if $] >= 5.014, re => '/a';  # ASCII-only character classes in regexes

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Unicode::EastAsianWidth;
use Texinfo::Convert::Unicode;
use Carp qw(cluck);

# initialize a paragraph object.
sub new($;$)
{
  my $class = shift;
  my $conf = shift;
  my $self = {'max' => 72, 'indent_length' => 0, 'counter' => 0,
              'word_counter' => 0, 'space' => '', 'frenchspacing' => 0,
              'lines_counter' => 0, 'end_line_count' => 0,
              'unfilled' => 0, 'last_letter' => '' };
  if (defined($conf)) {
    foreach my $key (keys(%$conf)) {
      $self->{$key} = $conf->{$key};
    }
  }
  bless $self, $class;
}

# for debugging
sub dump($)
{
  my $self = shift;
  print STDERR "para ($self->{'counter'}+$self->{'word_counter'}) "
    ."word: ".(defined($self->{'word'}) ? $self->{'word'} : 'UNDEF')
    .", space `$self->{'space'}' "
    ."end_sentence: ".(defined($self->{'end_sentence'})
                                ? $self->{'end_sentence'} : 'UNDEF')."\n";
}

sub _cut_line($)
{
  my $paragraph = shift;
  return '' if ($paragraph->{'ignore_columns'});
  return _end_line($paragraph);
}

sub end_line_count($)
{
  my $paragraph = shift;
  return $paragraph->{'end_line_count'};
}

sub counter($)
{
  my $paragraph = shift;
  return $paragraph->{'counter'};
}

sub end_line($)
{
  my $paragraph = shift;
  $paragraph->{'end_line_count'} = 0;
  return _end_line($paragraph);
}

# end a line.
sub _end_line($)
{
  my $paragraph = shift;
  $paragraph->{'counter'} = 0;
  $paragraph->{'space'} = '';
  if (defined($paragraph->{'indent_length_next'})) {
    $paragraph->{'indent_length'} = $paragraph->{'indent_length_next'};
    delete $paragraph->{'indent_length_next'};
  }
  $paragraph->{'lines_counter'}++;
  $paragraph->{'end_line_count'}++;
  # could be set to other values, anything that is not upper case.
  $paragraph->{'last_letter'} = "\n";
  print STDERR "END_LINE\n" if ($paragraph->{'DEBUG'});
  return "\n";
}

sub get_pending($)
{
  my $paragraph = shift;
  my $result = '';
  if ($paragraph->{'space'}) {
    $result .= $paragraph->{'space'};
  }
  if (defined($paragraph->{'word'})) {
    $result .= $paragraph->{'word'};
  }
  return $result;
}

sub add_pending_word($;$)
{
  my $paragraph = shift;
  my $add_spaces = shift;
  $paragraph->{'end_line_count'} = 0;
  return _add_pending_word($paragraph, $add_spaces);
}

# put a pending word and spaces in the result string.
sub _add_pending_word($;$)
{
  my $paragraph = shift;
  my $add_spaces = shift;
  my $result = '';

  if (not defined($paragraph->{'word'}) and not $add_spaces) {
    return $result;
  }

  if ($paragraph->{'indent_length'} > $paragraph->{'counter'}) {
    $result .= ' ' x ($paragraph->{'indent_length'} - $paragraph->{'counter'});
    $paragraph->{'counter'} = $paragraph->{'indent_length'};
    print STDERR "INDENT($paragraph->{'counter'}+$paragraph->{'word_counter'})\n"
                 if ($paragraph->{'DEBUG'});
    delete $paragraph->{'space'} unless $paragraph->{'unfilled'};
  }
  if ($paragraph->{'space'}) {
    $result .= $paragraph->{'space'};
    $paragraph->{'counter'} += length($paragraph->{'space'});
    print STDERR "ADD_SPACES($paragraph->{'counter'}+$paragraph->{'word_counter'})\n"
       if ($paragraph->{'DEBUG'});
  }
  $paragraph->{'space'} = '';
  if (defined($paragraph->{'word'})) {
    $result .= $paragraph->{'word'};
    $paragraph->{'counter'} += $paragraph->{'word_counter'};
    print STDERR "ADD_WORD[$paragraph->{'word'}]+$paragraph->{'word_counter'}"
      ." ($paragraph->{'counter'})\n"
        if ($paragraph->{'DEBUG'});
    $paragraph->{'word'} = undef;
    $paragraph->{'word_counter'} = 0;
  }
  return $result;
}

# end a paragraph
sub end($)
{
  my $paragraph = shift;
  $paragraph->{'end_line_count'} = 0;
  print STDERR "PARA END\n" if ($paragraph->{'DEBUG'});
  my $result = _add_pending_word($paragraph, $paragraph->{'add_final_space'});
  # probably not really useful, but cleaner
  $paragraph->{'last_letter'} = '';
  if (!$paragraph->{'no_final_newline'} and $paragraph->{'counter'} != 0) {
    $result .= "\n";
    $paragraph->{'lines_counter'}++;
    $paragraph->{'end_line_count'}++;
  }
  return $result;
}

my $end_sentence_characters = quotemeta('.?!');
my $after_punctuation_characters = quotemeta('"\')]');

# Add $WORD to paragraph, returning the text to be added to the paragraph.
sub add_next($;$$)
{
  my $paragraph = shift;
  my $word = shift;
  my $transparent = shift;
  $paragraph->{'end_line_count'} = 0;
  return _add_next($paragraph, $word, $transparent);
}

# add a word (without wrapping).
sub _add_next($;$$$)
{
  my $paragraph = shift;
  my $word = shift;
  my $transparent = shift;
  my $newlines_impossible = shift;
  my $result = '';

  if (!defined($word)) {
    return '';
  }

  $paragraph->{'word'} .= $word;

  if (!$transparent
      and ($word =~
           /([^$end_sentence_characters$after_punctuation_characters])
            [$end_sentence_characters$after_punctuation_characters]*$/ox)) {
    # Save the last character in $word before punctuation
    $paragraph->{'last_letter'} = $1;
  }

  if (!$newlines_impossible and $word =~ /\n/) {
    $result .= _add_pending_word ($paragraph);
    _end_line($paragraph);
  } else {
    $paragraph->{'word_counter'}
      += Texinfo::Convert::Unicode::string_width($word);

    # The $paragraph->{'counter'} != 0 is here to avoid having an
    # additional line output when the text is longer than the max.
    if ($paragraph->{'counter'} != 0 and
        $paragraph->{'counter'} + $paragraph->{'word_counter'} +
           length($paragraph->{'space'}) > $paragraph->{'max'}) {
      $result .= _cut_line($paragraph);
    }
  }
  if ($paragraph->{'DEBUG'}) {
    print STDERR "WORD+ $word -> "
      .(defined($paragraph->{'word'}) ? $paragraph->{'word'} : 'UNDEF')."\n";
  }

  return $result;
}

# Values for 'end_sentence'.  'end_sentence' can also be undef.
use constant {
  eos_inhibited => 0,
  eos_present => 1,
  eos_present_frenchspacing => -1,
};

sub remove_end_sentence($)
{
  my $paragraph = shift;
  $paragraph->{'end_sentence'} = eos_inhibited;
}

sub add_end_sentence($;$) {
  my $paragraph = shift;
  my $value = shift;
  $paragraph->{'end_sentence'} = $value;
}

sub allow_end_sentence($)
{
  my $paragraph = shift;
  printf STDERR "ALLOW END SENTENCE\n" if $paragraph->{'DEBUG'};
  $paragraph->{'last_letter'} = 'a'; # lower-case
}

sub set_space_protection($$;$$$$)
{
  my $paragraph = shift;
  my $no_break = shift;
  my $ignore_columns = shift;
  my $keep_end_lines = shift;
  my $frenchspacing = shift;
  my $double_width_no_break = shift;
  $paragraph->{'no_break'} = $no_break
    if defined($no_break);
  $paragraph->{'ignore_columns'} = $ignore_columns
    if defined($ignore_columns);
  $paragraph->{'keep_end_lines'} = $keep_end_lines
    if defined($keep_end_lines);
  $paragraph->{'frenchspacing'} = $frenchspacing
    if defined($frenchspacing);
  $paragraph->{'double_width_no_break'} = $double_width_no_break
    if defined($double_width_no_break);
  # begin a word, to have something even if empty
  if ($no_break) {
    _add_next($paragraph, '');
  }
}

# Wrap $TEXT, returning the wrapped text, taking into account the current state
# of $PARAGRAPH.  Any end of sentence punctuation in $TEXT that should be
# allowed to end a sentence but which would otherwise be preceded by an
# upper-case letter should instead by preceded by a backspace character.
sub add_text($$)
{
  my $paragraph = shift;
  my $text = shift;
  $paragraph->{'end_line_count'} = 0;
  my $result = '';

  my @segments = split
    /(\s+)|(\p{InFullwidth})|((?:[^\s\p{InFullwidth}\x08])+)|(\x08)/,
    $text;

  # Check now if a newline exists anywhere in the string to
  # try to eliminate regex checks later.
  my $newline_possible_flag = ($text =~ /\n/);

  my $debug_flag = $paragraph->{'DEBUG'};
  while (@segments) {
    # $empty_segment should be an empty string; the other variables
    # here were recognized as field separators by split, the separator
    # set to something else than undef for the separator matching.
    my ($empty_segment, $spaces, $fullwidth_segment, $added_word, $allow_eos)
     = splice (@segments, 0, 5);

    if ($debug_flag) {
      print STDERR "p ($paragraph->{'counter'}+$paragraph->{'word_counter'}) "
       ."s `" . _print_escaped_spaces($paragraph->{'space'})."', "
       ."l `$paragraph->{'last_letter'}', "
       ."w `".(defined($paragraph->{'word'}) ? $paragraph->{'word'}
                                 : 'UNDEF')."'\n";
    }
    if (defined $spaces) {
      print STDERR "SPACES($paragraph->{'counter'}) `"
          ._print_escaped_spaces($spaces)."'\n" if $debug_flag;
      if ($paragraph->{'unfilled'}) {
        $result .= _add_pending_word($paragraph);
        if ($spaces =~ /\n/) {
          $result .= _end_line ($paragraph);
        } else {
          $paragraph->{'space'} .= $spaces;
        }
      } else {
        my $at_end_sentence = 0;
        $at_end_sentence = 1 if (defined($paragraph->{'end_sentence'})
                               and  $paragraph->{'end_sentence'} == eos_present
                               and !$paragraph->{'frenchspacing'});
        if ($paragraph->{'no_break'}) {
          if (substr($paragraph->{'word'}, -1) ne ' ') {
            my $new_spaces = $at_end_sentence ? '  ' : ' ';
            $paragraph->{'word'} .= $new_spaces;
            $paragraph->{'word_counter'} += length($new_spaces);

            # The $paragraph->{'counter'} != 0 is here to avoid having an
            # additional line output when the text is longer than the max.
            if ($paragraph->{'counter'} != 0 and
                $paragraph->{'counter'} + $paragraph->{'word_counter'} +
                   length($paragraph->{'space'}) > $paragraph->{'max'}) {
              $result .= _cut_line($paragraph);
            }
          }
        } else {
          my $pending_word = $paragraph->{'word'};
          $result .= _add_pending_word($paragraph);
          if ($paragraph->{'counter'} != 0
              or (defined $pending_word)) {
            if ($at_end_sentence) {
              $paragraph->{'space'} = '  ';
            } else {
              # Only save the first space
              if (length($paragraph->{'space'}) < 1) {
                $paragraph->{'space'} = ' ';
              }
            }
          }
        }
      }
      if ($paragraph->{'counter'} + length($paragraph->{'space'})
                      > $paragraph->{'max'}) {
        $result .= _cut_line($paragraph);
      }
      if ($newline_possible_flag and !$paragraph->{'unfilled'}
          and $paragraph->{'keep_end_lines'} and $spaces =~ /\n/) {
        $result .= _end_line($paragraph);
      }
      $paragraph->{'last_letter'} = ' ';
    } elsif (defined $allow_eos) {
      # Reset 'last_leter' to a lower-case letter to allow an end of
      # sentence to occur.
      $paragraph->{'last_letter'} = 'a';
    } elsif (defined $added_word) {
      my $tmp = $added_word;
      # Prepend 'last_letter' to add the information on the last
      # letter even if it was read as part of a previous string
      # Add it here because _add_next overwrites it.  Note that
      # if _add_next overwrited it, it wouldn't lead to an invalid
      # result, as the wrong prepended 'last_letter' would not match
      # at the end of the $added_word in the regex below anyway.
      $tmp = $paragraph->{'last_letter'} . $tmp;

      $result .= _add_next($paragraph, $added_word, undef,
                           !$newline_possible_flag);

      # Check if it is considered as an end of sentence.  There are two things
      # to check: one, that we have a ., ! or ?; and second, that it is not
      # preceded by an upper-case letter (ignoring some punctuation)
      if (defined($paragraph->{'end_sentence'})
          and $added_word =~ /^[$after_punctuation_characters]*$/o) {
        # do nothing in the case of a continuation of after_punctuation_characters
      } elsif (!$paragraph->{'unfilled'}
          and $tmp =~
        /(^|[^\p{Upper}$after_punctuation_characters$end_sentence_characters])
         [$after_punctuation_characters]*[$end_sentence_characters]
         [$end_sentence_characters$after_punctuation_characters]*$/ox) {
        if ($paragraph->{'frenchspacing'}) {
          $paragraph->{'end_sentence'} = eos_present_frenchspacing;
        } else {
          $paragraph->{'end_sentence'} = eos_present;
        }
        print STDERR "END_SENTENCE\n" if ($paragraph->{'DEBUG'});
      } else {
        print STDERR "delete END_SENTENCE($paragraph->{'end_sentence'})\n"
          if (defined($paragraph->{'end_sentence'}) and $paragraph->{'DEBUG'});
        delete $paragraph->{'end_sentence'};
      }
    } elsif (defined $fullwidth_segment) {
      print STDERR "FULLWIDTH\n" if ($paragraph->{'DEBUG'});

      if (!defined($paragraph->{'word'})) {
        $paragraph->{'word'} = '';
      }
      $paragraph->{'word'} .= $fullwidth_segment;
      $paragraph->{'word_counter'} += 2;

      # fullwidth latin letters can be upper case, so it is important to
      # use the actual characters here.
      $paragraph->{'last_letter'} = $fullwidth_segment;

      # We allow a line break in between Chinese characters even if
      # there was no space between them, unlike single-width
      # characters.
      if ($paragraph->{'counter'} != 0 and
          $paragraph->{'counter'} + $paragraph->{'word_counter'}
                               > $paragraph->{'max'}) {
        $result .= _cut_line($paragraph);
      }
      if (!$paragraph->{'no_break'}
          and !$paragraph->{'double_width_no_break'}) {
        $result .= _add_pending_word($paragraph);
      }
      delete $paragraph->{'end_sentence'};
    }
  }
  return $result;
}

# for debug
sub _print_escaped_spaces($)
{
  my $spaces = shift;
  my $result = '';
  foreach my $pos (0 .. length($spaces)-1) {
    my $char = substr($spaces, $pos, 1);
    if ($char eq ' ') {
      $result .= $char;
    } elsif ($char =~ /[\f\n]/) {
      $char =~ s/\f/\\f/;
      $char =~ s/\n/\\n/;
      $result .= $char;
    } elsif ($char =~ /\s/) {
      if (ord($char) <= hex(0xFFFF)) {
        $result .= '\x'.sprintf("%04x",ord($char));
      } else {
        $result .= '\x'.sprintf("%06x",ord($char));
      }
    } else {
      $result .= $char;
    }
  }
  return $result;
}

1;
