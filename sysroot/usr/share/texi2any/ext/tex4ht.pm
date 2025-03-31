# -*-perl-*-

#+##############################################################################
#
# tex4ht.pm: use tex4ht to convert tex to html
#
# Copyright 2005, 2007, 2009, 2011-2024 Free Software Foundation, Inc.
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
# To customize the command and the options, you can set the
# T4H_MATH_CONVERSION, T4H_TEX_CONVERSION and T4H_LATEX_CONVERSION
# customization variables and/or change
# $Texinfo::TeX4HT::tex4ht_command_tex
#    and $Texinfo::TeX4HT::tex4ht_options_tex
# $Texinfo::TeX4HT::tex4ht_command_latex, $Texinfo::TeX4HT::tex4ht_command_texi
#    and $Texinfo::TeX4HT::tex4ht_options_latex and $Texinfo::TeX4HT::tex4ht_options_texi

use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Cwd;
use Encode qw(encode);

# Also for __(
use Texinfo::Common;
use Texinfo::Convert::Texinfo;
# to implement CONVERT_TO_LATEX_IN_MATH
use Texinfo::Convert::LaTeX;

texinfo_register_handler('structure', \&tex4ht_prepare);
# could probably be done also in the 'structure' phase
texinfo_register_handler('init', \&tex4ht_process);
texinfo_register_handler('finish', \&tex4ht_finish);

texinfo_register_command_formatting('math', \&tex4ht_convert_command);
texinfo_register_command_formatting('tex', \&tex4ht_convert_command);
texinfo_register_command_formatting('latex', \&tex4ht_convert_command);
texinfo_register_command_formatting('displaymath', \&tex4ht_convert_command);

{

package Texinfo::TeX4HT;

use vars qw(
$tex4ht_command_tex
$tex4ht_command_latex
$tex4ht_command_texi
$tex4ht_options_tex
$tex4ht_options_latex
$tex4ht_options_texi
);

if (!defined($tex4ht_command_tex)) {
  $tex4ht_command_tex = 'httex';
}

if (!defined($tex4ht_command_latex)) {
  $tex4ht_command_latex = 'htlatex';
}

if (!defined($tex4ht_command_texi)) {
  $tex4ht_command_texi = 'httexi';
}

}

my %commands;
# style of output
my %formats;

my $tex4ht_initial_dir;
my $tex4ht_out_dir;

sub tex4ht_prepare($$)
{
  # set file names
  my $self = shift;
  my $document = shift;

  my $document_root = $document->tree();

  # this initialization may not be needed, but it is cleaner anyway,
  # in case there is more than one texinfo file processed.
  # In that case, it is indeed better to clear the structures.  Note that
  # even if the structures are not cleared, the results should be ok in most
  # cases, as everything that needs to be changed should be rewritten, so it
  # does not matter if there are remaining results from the previous file.
  %commands = ();
  %formats = ();

  return 0 if (defined($self->get_conf('OUTFILE'))
        and $Texinfo::Common::null_device_file{$self->get_conf('OUTFILE')});

  $formats{'tex'} = {'exec' => $Texinfo::TeX4HT::tex4ht_command_tex,
                     'commands' => [],
                     'results' => {}};
  $formats{'latex'} = {'exec' => $Texinfo::TeX4HT::tex4ht_command_latex,
                       'commands' => [],
                       'results' => {}};
  $formats{'texi'} = {'exec' => $Texinfo::TeX4HT::tex4ht_command_texi,
                      'commands' => [],
                     'results' => {}};

  my $math_conversion = $self->get_conf('T4H_MATH_CONVERSION');
  if (defined($math_conversion) and !$formats{$math_conversion}) {
    $self->converter_document_error(
         sprintf(__("tex4ht.pm: unknown conversion type for math: %s"),
                                      $math_conversion));
    $math_conversion = undef;
  }
  $math_conversion = 'tex' if (!defined($math_conversion));

  my $tex_conversion = $self->get_conf('T4H_TEX_CONVERSION');
  if (defined($tex_conversion) and !$formats{$tex_conversion}) {
    $self->converter_document_error(
         sprintf(__("tex4ht.pm: unknown conversion type for \@tex: %s"),
                                      $tex_conversion));
    $tex_conversion = undef;
  }
  $tex_conversion = 'tex' if (!defined($tex_conversion));

  my $latex_conversion = $self->get_conf('T4H_LATEX_CONVERSION');
  if (defined($latex_conversion) and !$formats{$latex_conversion}) {
    $self->converter_document_error(
         sprintf(__("tex4ht.pm: unknown conversion type for \@latex: %s"),
                                      $latex_conversion));
    $latex_conversion = undef;
  }
  $latex_conversion = 'latex' if (!defined($latex_conversion));

  $commands{'displaymath'} = {'style' => $math_conversion,
                              'results' => {}};
  $commands{'math'} = {'style' => $math_conversion,
                       'results' => {}};
  $commands{'latex'} = {'style' => $latex_conversion,
                      'results' => {}};
  $commands{'tex'} = {'style' => $tex_conversion,
                      'results' => {}};

  $tex4ht_initial_dir = Cwd::abs_path;
  $tex4ht_out_dir = $self->get_info('destination_directory');

  if (!defined($tex4ht_out_dir) or $tex4ht_out_dir =~ /^\s*$/) {
    $tex4ht_out_dir = File::Spec->curdir();
  } else {
    my ($encoded_tex4ht_out_dir, $tex4ht_out_dir_encoding)
      = $self->encoded_output_file_name($tex4ht_out_dir);
    $self->create_destination_directory($encoded_tex4ht_out_dir,
                                        $tex4ht_out_dir);
  }

  my $document_name = $self->get_info('document_name');
  my $tex4ht_basename = "${document_name}_tex4ht";

  my @replaced_commands = sort(keys(%commands));
  my $collected_commands = Texinfo::Common::collect_commands_list_in_tree(
                                        $document_root, \@replaced_commands);
  my %format_collected_commands = ();
  foreach my $element (@{$collected_commands}) {
    my $command = $element->{'cmdname'};
    my $format = $commands{$command}->{'style'};
    push @{$format_collected_commands{$format}}, $element;
    $commands{$command}->{'counter'}++;
  }

  # prepare tex4ht input files for each format
  foreach my $format (sort(keys(%format_collected_commands))) {
    $formats{$format}->{'basename'} = $tex4ht_basename . "_$format";
    my $suffix = '.tex';
    $suffix = '.texi' if ($format eq 'texi');
    $formats{$format}->{'basefile_name'}
                 = $formats{$format}->{'basename'} . $suffix;
    my ($encoded_basefile_name, $basefile_name_encoding)
       = $self->encoded_output_file_name($formats{$format}->{'basefile_name'});
    $formats{$format}->{'basefile_path'} = $encoded_basefile_name;
    $formats{$format}->{'html_basefile_name'}
                 = $formats{$format}->{'basename'} . '.html';
    my ($encoded_html_basefile_name, $html_basefile_name_encoding)
       = $self->encoded_output_file_name($formats{$format}->{'html_basefile_name'});
    $formats{$format}->{'html_basefile_path'} = $encoded_html_basefile_name;

    my $tex4ht_file_path_name
      = "$tex4ht_out_dir/$formats{$format}->{'basefile_name'}";
    my ($encoded_tex4ht_file_path_name, $tex4ht_path_encoding)
      = $self->encoded_output_file_name($tex4ht_file_path_name);
    $formats{$format}->{'counter'} = 0;
    $formats{$format}->{'output_counter'} = 0;

    # FIXME no clear way to use utf8 and support encoded characters.
    # An attempt to encode to utf8 lead to worse results than letting
    # perl encode to latin1.  But with other non ascii characters than
    # latin1 characters, there will be utf8 output anyway.
    my $options_latex_math;
    if ($self->get_conf('CONVERT_TO_LATEX_IN_MATH')) {
      $options_latex_math
     = {Texinfo::Convert::LaTeX::copy_options_for_convert_to_latex_math($self)};
    }
    if (scalar(@{$format_collected_commands{$format}}) > 0) {
      my $fh;
      foreach my $element (@{$format_collected_commands{$format}}) {
        my $cmdname = $element->{'cmdname'};
        my $tree;
        if ($cmdname eq 'math') {
          $tree = $element->{'args'}->[0];
        } elsif ($element->{'contents'}) {
          $tree = {'contents' => [@{$element->{'contents'}}]};
          if (scalar(@{$tree->{'contents'}})
              and $tree->{'contents'}->[0]->{'type'}
              and ($tree->{'contents'}->[0]->{'type'} eq 'empty_line_after_command'
                   or $tree->{'contents'}->[0]->{'type'} eq 'elided_brace_command_arg'
                   or $tree->{'contents'}->[0]->{'type'} eq 'elided_rawpreformatted')) {
            shift @{$tree->{'contents'}};
          }
          if ($tree->{'contents'}->[-1]->{'cmdname'}
              and $tree->{'contents'}->[-1]->{'cmdname'} eq 'end') {
            pop @{$tree->{'contents'}};
          }
        } else {
          next;
        }
        if (scalar(@{$tree->{'contents'}}) == 0) {
          # should correspond to an ignored block
          next;
        }
        if ($formats{$format}->{'counter'} == 0) {
          local *TEX4HT_TEXFILE;
          unless (open(*TEX4HT_TEXFILE, ">$encoded_tex4ht_file_path_name")) {
            $self->converter_document_error(
                    sprintf(__("tex4ht.pm: could not open %s: %s"),
                                          $tex4ht_file_path_name, $!));
            return 1;
          }
          $fh = *TEX4HT_TEXFILE;
          my $comment = '@c';
          $comment = '%' if ($format ne 'texi');
          $comment .= " Automatically generated by the t4ht Texinfo HTML extension\n";
          if ($format eq 'texi') {
            print $fh "\\input texinfo
    \@setfilename $formats{$format}->{'basename'}.info\n";
            print $fh "$comment";
          } else {
            print $fh "$comment";
            if ($format eq 'latex') {
              print $fh "\\documentclass{article}\n\\begin{document}\n";
            } elsif ($format eq 'tex') {
              print $fh "\\csname tex4ht\\endcsname\n";
            }
          }
        }
        $formats{$format}->{'counter'}++;
        my $counter = $formats{$format}->{'counter'};
        my $text;
        if ($options_latex_math) {
          $text = Texinfo::Convert::LaTeX::convert_to_latex_math(undef,
                                            $tree, $options_latex_math);
        } else {
          $text = Texinfo::Convert::Texinfo::convert_to_texinfo($tree);
        }
        $formats{$format}->{'commands'}->[$counter-1] = $element;

        # write to tex file
        my ($before_comment_open, $after_comment_open, $before_comment_close,
            $after_comment_close);

        if ($format eq 'texi') {
          $before_comment_open = "\@verbatim\n\n";
          $after_comment_open = "\n\@end verbatim\n";
          $before_comment_close = "\@verbatim\n";
          $after_comment_close = "\n\n\@end verbatim\n";
        } else {
          $before_comment_open = "\\HCode{\\Hnewline \\Hnewline ";
          $after_comment_open = "\\Hnewline}\n";
          $before_comment_close = "\\HCode{\\Hnewline ";
          $after_comment_close = "\\Hnewline \\Hnewline}\n";
        }

        my $begin_comment = "<!-- tex4ht_begin $formats{$format}->{'basename'} $cmdname $counter -->";
        print $fh "$before_comment_open$begin_comment$after_comment_open";
        if ($cmdname eq 'tex' or $cmdname eq 'latex') {
          print $fh $text;
        } elsif ($cmdname eq 'math') {
          if ($format eq 'texi') {
            print $fh '@math{' . $text . "}\n";
          } else {
            print $fh "\\IgnorePar \$" . $text . "\$";
          }
        } elsif ($cmdname eq 'displaymath') {
          if ($format eq 'texi') {
            print $fh "\@displaymath\n".$text."\@end displaymath\n";
          } elsif ($format eq 'latex') {
            print $fh "\n\\[" . $text . "\\]\n";
          } else { # tex
            print $fh "\n\$\$" . $text . "\$\$\n";
          }
        }
        my $end_comment = "<!-- tex4ht_end $formats{$format}->{'basename'} $cmdname $counter -->";
        print $fh "$before_comment_close$end_comment$after_comment_close";
      }
      if ($formats{$format}->{'counter'} > 0) {
        # finish the tex file
        if ($format eq 'latex') {
          print $fh "\\end{document}\n";
        } elsif ($format eq 'tex') {
          print $fh "\n\\bye\n";
        } else {
          print $fh "\n\@bye\n";
        }
        # FIXME check close error
        close ($fh);
      }
    }
  }
  return 0;
}

# run tex4ht and extract HTML for all the formats
sub tex4ht_process($)
{
  my $self = shift;

  # check first that there are collected commands before attempting chdir.
  # Alternatively, could have checked if scalar(keys(%commands)) is 0.
  my $total_count = 0;
  foreach my $format (keys(%formats)) {
    $total_count += $formats{$format}->{'counter'}
       if ($formats{$format}->{'counter'});
  }
  return 0 if ($total_count == 0);

  my ($encoded_tex4ht_out_dir, $tex4ht_out_dir_encoding)
    = $self->encoded_output_file_name($tex4ht_out_dir);
  unless (chdir $encoded_tex4ht_out_dir) {
    $self->converter_document_warn(
            sprintf(__("tex4ht.pm: chdir %s failed: %s"),
                         $tex4ht_out_dir, $!));
    return 1;
  }
  print STDERR "cwd($encoded_tex4ht_out_dir): " . Cwd::cwd() ."\n"
    if ($self->get_conf('VERBOSE'));

  my $errors = 0;
  # sort for reproducible messages order and output
  foreach my $format (sort(keys(%formats))) {
    $errors += tex4ht_process_format($self, $format);
  }
  unless (chdir $tex4ht_initial_dir) {
    $self->converter_document_warn(sprintf(__(
          "tex4ht.pm: unable to return to initial directory: %s"), $!));
    return 1 + $errors;
  }
  return $errors;
}

# run tex4ht and extract HTML fragments from the result file
sub tex4ht_process_format($$) {
  my $self = shift;
  my $format = shift;

  return 0 unless ($formats{$format}->{'counter'});

  $self->converter_document_warn(
              sprintf(__("tex4ht.pm: output file missing: %s"),
                               $formats{$format}->{'basefile_name'}))
    unless (-f $formats{$format}->{'basefile_path'});

  # run tex4ht
  my $options = '';
  if ($format eq 'tex' and defined($Texinfo::TeX4HT::tex4ht_options_tex)) {
    $options = $Texinfo::TeX4HT::tex4ht_options_tex;
  } elsif ($format eq 'latex' and defined($Texinfo::TeX4HT::tex4ht_options_latex)) {
    $options = $Texinfo::TeX4HT::tex4ht_options_latex;
  } elsif ($format eq 'texi' and defined($Texinfo::TeX4HT::tex4ht_options_texi)) {
    $options = $Texinfo::TeX4HT::tex4ht_options_texi;
  }

  my $cmd = "$formats{$format}->{'exec'} $formats{$format}->{'basefile_name'} $options";
  my $encoding = $self->get_conf('MESSAGE_ENCODING');
  my $encoded_exec;
  my $encoded_options;
  if (defined($encoding)) {
    $encoded_exec = encode($encoding, $formats{$format}->{'exec'});
    $encoded_options = encode($encoding, $options);
  } else {
    $encoded_exec = $formats{$format}->{'exec'};
    $encoded_options = $options;
  }
  my $encoded_cmd = $encoded_exec . " " . $formats{$format}->{'basefile_path'}
                    . " $encoded_options";

  print STDERR "tex4ht command: $encoded_cmd\n" if ($self->get_conf('VERBOSE'));
  # do not use system in order to be sure that tex STDIN is not
  # mixed up with the main script STDIN.  It is important because
  # if tex fails, it will read from STDIN and the input may trigger
  # diverse actions by tex.
  if (not(open(TEX4HT, "|-", $encoded_cmd))) {
    $self->converter_document_error(sprintf(__(
                         "tex4ht.pm: command failed: %s"), $cmd));
    return 1;
  }
  if (!close(TEX4HT)) {
    $self->converter_document_warn(sprintf(__(
                         "tex4ht.pm: closing communication failed: %s: %s"),
                         $cmd, $!));
    return 1;
  }

  $self->css_add_info('imports',
            "\@import \"$formats{$format}->{'basename'}.css\";\n");

  # extract the html from the file created by tex4ht
  my $html_basefile = $formats{$format}->{'html_basefile_name'};
  my $encoded_html_basefile = $formats{$format}->{'html_basefile_path'};
  unless (open(TEX4HT_HTMLFILE, $encoded_html_basefile)) {
    $self->converter_document_warn(
              sprintf(__("tex4ht.pm: could not open %s: %s"),
                                  $html_basefile, $!));
    return 1;
  }
  my $got_count = 0;
  my $line;
  # FIXME decode?
  while ($line = <TEX4HT_HTMLFILE>) {
    #print STDERR "$encoded_html_basefile: while $line";
    if ($line =~ /!-- tex4ht_begin $formats{$format}->{'basename'} (\w+) (\d+) --/) {
      my $cmdname = $1;
      my $count = $2;
      my $text = '';
      my $end_found = 0;
      while ($line = <TEX4HT_HTMLFILE>) {
        #print STDERR "while search $cmdname $count $line";
        if ($line =~ /!-- tex4ht_end $formats{$format}->{'basename'} $cmdname $count --/) {
          $got_count++;
          if ($cmdname eq 'math') {
            chomp($text);
            # tex4ht may add spaces that we do not need.  Actual content
            # should in any case be in HTML elements.
            $text =~ s/^\s*//;
            $text =~ s/\s*$//;
          }
          $commands{$cmdname}->{'results'}->{
                           $formats{$format}->{'commands'}->[$count-1]} = $text;
          $end_found = 1;
          last;
        } else {
          $text .= $line;
        }
      }
      unless ($end_found) {
        # should be a bug or mangled output
        $self->converter_document_warn(sprintf(__(
                               "tex4ht.pm: end of %s item %d for \@%s not found"),
                                      $format, $count, $cmdname));
      }
    }
  }
  if ($got_count != $formats{$format}->{'counter'}) {
    # unless tex4ht somehow mangles the output, this should
    # never happen, could also be considered as en error or a bug.
    $self->converter_document_warn(sprintf(__(
       "tex4ht.pm: processing produced %d items in HTML; expected %d for format %s"),
                                 $got_count, $formats{$format}->{'counter'},
                                 $format));
  }
  close (TEX4HT_HTMLFILE);
  return 0;
}

sub tex4ht_convert_command($$$;$$)
{
  my $self = shift;
  my $cmdname = shift;
  my $command = shift;
  my $args = shift;
  my $content = shift;

  if (not defined ($commands{$cmdname})) {
    # nothing was collected, do the usual output
    return &{$self->default_command_conversion($cmdname)}($self,
                               $cmdname, $command, $args, $content);
  } elsif (not defined ($commands{$cmdname}->{'results'})) {
    # no results at all for that command, also do the usual output
    warn "tex4ht.pm: no results at all for \@$cmdname (element $command)\n"
           if ($self->get_conf('VERBOSE'));
    return &{$self->default_command_conversion($cmdname)}($self,
                               $cmdname, $command, $args, $content);
  } elsif (exists($commands{$cmdname}->{'results'}->{$command})
      and defined($commands{$cmdname}->{'results'}->{$command})) {
    # return the resulting html
    $commands{$cmdname}->{'output_counter'}++;
    return $commands{$cmdname}->{'results'}->{$command};
  } else {
    # probably a bug in that case, unless the format is ignored
    if ($self->is_format_expanded($cmdname)) {
      $self->converter_document_warn(sprintf(__(
                       "tex4ht.pm: output has no HTML item for \@%s %s"),
                                  $cmdname, $command));
    }
    return '';
  }
}

sub tex4ht_finish($)
{
  my $self = shift;
  # this is different from the warning in tex4ht_process_command as, here,
  # this is the number of retrieved fragment, not processed fragment.
  if ($self->get_conf('VERBOSE')) {
    foreach my $command (sort(keys(%commands))) {
      if (not defined($commands{$command}->{'output_counter'})) {
        if (defined($commands{$command}->{'counter'})) {
          $self->converter_document_warn(sprintf(__(
           "tex4ht.pm: output counter UNDEF; expected %d for \@%s"),
                                 $commands{$command}->{'counter'}, $command));
        } else {
          warn sprintf(__(
            "tex4ht.pm: no expected items in the document for \@%s"),
                                             $command)."\n";
        }
      } elsif ($commands{$command}->{'output_counter'} != $commands{$command}->{'counter'}) {
        # NOTE with math commands in @copying and multiple @insertcopying,
        # there may be more items output than found in the document tree
        warn sprintf(__(
           "tex4ht.pm: processing retrieved %d items in HTML; collected %d for \@%s"),
                                  $commands{$command}->{'output_counter'},
                                  $commands{$command}->{'counter'}, $command)."\n";
      }
    }
  }
  return 0;
}

1;
