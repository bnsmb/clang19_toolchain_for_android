# Info.pm: output tree as Info.
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
#
# Names of methods from Texinfo::Convert::Plaintext overriden begin with format_.

package Texinfo::Convert::Info;

use 5.006;

use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Carp qw(cluck);

use Texinfo::Common;
use Texinfo::OutputUnits;
use Texinfo::Convert::Text;
use Texinfo::Convert::Plaintext;

use Texinfo::Convert::Paragraph;

our @ISA = qw(Texinfo::Convert::Plaintext);

our $VERSION = '7.2';


my $STDIN_DOCU_NAME = 'stdin';

my $plaintext_defaults
  = Texinfo::Convert::Plaintext::converter_defaults(undef, undef);
my $defaults = { %$plaintext_defaults };
# Customization option variables
$defaults->{'FORMAT_MENU'} = 'menu';
$defaults->{'EXTENSION'} = 'info';
$defaults->{'USE_SETFILENAME_EXTENSION'} = 1;
$defaults->{'OUTFILE'} = undef;
# in the Emacs Info reader and in old readers, DEL character will appear,
# but the node names are problematic in those readers, so it is not
# such an issue to have them marked that way.
$defaults->{'INFO_SPECIAL_CHARS_QUOTE'} = 1;
# set as default independently of INFO_SPECIAL_CHARS_QUOTE as long
# as the Emacs Info reader does not support node names quoting.
$defaults->{'INFO_SPECIAL_CHARS_WARNING'} = 1;

sub converter_defaults($$)
{
  return $defaults;
}

sub output($$)
{
  my $self = shift;
  my $document = shift;

  $self->conversion_initialization($document);

  my $result;

  my ($output_file, $destination_directory, $output_filename,
      $document_name, $input_basefile)
        = $self->determine_files_and_directory(
                               $self->get_conf('TEXINFO_OUTPUT_FORMAT'));
  my ($encoded_destination_directory, $dir_encoding)
    = $self->encoded_output_file_name($destination_directory);
  my ($succeeded, $created_directory)
    = $self->create_destination_directory($encoded_destination_directory,
                                          $destination_directory);
  unless ($succeeded) {
    $self->conversion_finalization();
    return undef;
  }

  # for format_node
  $self->{'output_filename'} = $output_filename;

  $input_basefile = $STDIN_DOCU_NAME if ($input_basefile eq '-');

  # no splitting when writing to the null device or to stdout
  if ($Texinfo::Common::null_device_file{$output_file}
       or $output_file eq '-') {
    $self->force_conf('SPLIT_SIZE', undef);
  }

  my $fh;
  if ($output_file ne '') {
    if ($self->get_conf('VERBOSE')) {
      print STDERR "Output file $output_file\n";
    }
    $fh = _open_info_file($self, $output_file);
    if (!$fh) {
      $self->conversion_finalization();
      return undef;
    }
  } else {
    $self->{'encoding_disabled'} = 1;
  }

  my $header = $self->_info_header($input_basefile, $output_filename);
  # header + text between setfilename and first node
  my $complete_header = $header;

  my $header_bytes = length($header);
  my $complete_header_bytes = $header_bytes;
  my $output_units = Texinfo::OutputUnits::split_by_node($document);

  print STDERR "DOCUMENT\n" if ($self->get_conf('DEBUG'));

  my $out_file_nr = 0;
  my @indirect_files;
  if (not defined($output_units->[0]->{'unit_command'})) {
    my $input_file_name;
    if ($self->{'document'}) {
      my $document_info = $self->{'document'}->global_information();
      if ($document_info) {
        $input_file_name = $document_info->{'input_file_name'};
      }
    }
    if (defined($input_file_name)) {
      $self->converter_line_warn(__("document without nodes"),
             {'file_name' => $input_file_name});
    } else {
      $self->converter_document_warn(__("document without nodes"));
    }
    my $old_context = $self->{'count_context'}->[-1];
    my $new_context =
      {'lines' => $old_context->{'lines'}, 'bytes' => $old_context->{'bytes'},
       'locations' => [], 'result' => '' };
    push @{$self->{'count_context'}}, $new_context;

    my $root = $document->tree();
    $self->_convert($root);
    $self->process_footnotes();
    my $output = $self->_stream_result();
    pop @{$self->{'count_context'}};

    @{$old_context->{'locations'}}
      = ( @{$old_context->{'locations'}}, @{$new_context->{'locations'}} );
    $old_context->{'lines'} += $new_context->{'lines'};

    $output = $header.$output;
    if ($fh) {
      print $fh $output;
    } else {
      $result = $output;
    }
  } else {
    my $identifiers_target;
    if ($self->{'document'}) {
      $identifiers_target = $self->{'document'}->labels_information();
    }
    unless ($identifiers_target
            and $identifiers_target->{'Top'}) {
      my $input_file_name;
      if ($self->{'document'}) {
        my $document_info = $self->{'document'}->global_information();
        if ($document_info) {
          $input_file_name = $document_info->{'input_file_name'};
        }
      }
      if (defined($input_file_name)) {
        $self->converter_line_warn(__("document without Top node"),
             {'file_name' => $input_file_name});
      } else {
        $self->converter_document_warn(__("document without Top node"));
      }
    }
    $out_file_nr = 1;
    my $first_node_seen = 0;
    $self->{'count_context'}->[-1]->{'bytes'} += $header_bytes;
    foreach my $output_unit (@$output_units) {
      if ($first_node_seen
          and defined($self->get_conf('SPLIT_SIZE'))
          and $self->{'count_context'}->[-1]->{'bytes'} >
                  $out_file_nr * $self->get_conf('SPLIT_SIZE')
          and $fh) {
        # Split the output into an additional output file.
        my $close_error;
        if (!close ($fh)) {
          $close_error = $!;
        }
        if ($out_file_nr == 1) {
          # Switch to split output.
          $self->_register_closed_info_file($output_file);
          if (defined($close_error)) {
            $self->converter_document_error(
                  sprintf(__("error on closing %s: %s"),
                                  $output_file, $close_error));
            $self->conversion_finalization();
            return undef;
          }
          if ($self->get_conf('VERBOSE')) {
            print STDERR "Renaming first output file as ".
                  $output_file.'-'.$out_file_nr."\n";
          }
          unless (rename($output_file, $output_file.'-'.$out_file_nr)) {
            $self->converter_document_error(
                  sprintf(__("rename %s failed: %s"),
                                         $output_file, $!));
            $self->conversion_finalization();
            return undef;
          }
          # remove the main file from opened files since it was renamed
          # and add the file with a number.
          @{$self->{'opened_files'}} = grep {$_ ne $output_file}
               @{$self->{'opened_files'}};
          push @{$self->{'opened_files'}},
                   $output_file.'-'.$out_file_nr;
          push @indirect_files, [$output_filename.'-'.$out_file_nr,
                                 $complete_header_bytes];
          #print STDERR join(' --> ', @{$indirect_files[-1]}) ."\n";
        } else {
          $self->_register_closed_info_file($output_file.'-'.$out_file_nr);
          if (defined($close_error)) {
            $self->converter_document_error(
                  sprintf(__("error on closing %s: %s"),
                                  $output_file.'-'.$out_file_nr,
                                  $close_error));
            $self->conversion_finalization();
            return undef;
          }
        }
        $out_file_nr++;
        if ($self->get_conf('VERBOSE')) {
          print STDERR "New output file ".
                $output_file.'-'.$out_file_nr."\n";
        }
        $fh = _open_info_file($self, $output_file.'-'.$out_file_nr);
        if (!$fh) {
          $self->conversion_finalization();
          return undef;
        }
        print $fh $complete_header;
        $self->{'count_context'}->[-1]->{'bytes'} += $complete_header_bytes;
        push @indirect_files, [$output_filename.'-'.$out_file_nr,
                               $self->{'count_context'}->[-1]->{'bytes'}];
        #print STDERR join(' --> ', @{$indirect_files[-1]}) ."\n";
      }

      my $node_text = $self->convert_output_unit($output_unit);
      if ($node_text !~ /\n\n$/) {
        $node_text .= "\n";
        $self->{'count_context'}->[-1]->{'bytes'}++;
      }
      if (!$first_node_seen) {
        # We are outputting the first node.
        $first_node_seen = 1;
        $node_text = $header . $node_text;

        # When the first node was converted in convert_output_unit above, the
        # text before the first node (type 'before_node_section') was saved in
        # 'text_before_first_node'.  Save this text for subsequent use in
        # case of split Info output.
        if (defined($self->{'text_before_first_node'})) {
          $complete_header .= $self->{'text_before_first_node'};
          $complete_header_bytes += length($self->{'text_before_first_node'});
        }
      }
      if ($fh) {
        print $fh $node_text;
      } else {
        $result .= $node_text;
      }
    }
  }
  my $tag_text = '';
  if ($out_file_nr > 1) {
    $self->_register_closed_info_file($output_file.'-'.$out_file_nr);
    if (!close ($fh)) {
      $self->converter_document_error(
               sprintf(__("error on closing %s: %s"),
                            $output_file.'-'.$out_file_nr, $!));
      $self->conversion_finalization();
      return undef;
    }
    if ($self->get_conf('VERBOSE')) {
      print STDERR "Outputing the split manual file $output_file\n";
    }
    $fh = _open_info_file($self, $output_file);
    if (!$fh) {
      $self->conversion_finalization();
      return undef;
    }
    $tag_text = $complete_header;
    $tag_text .= "\x{1F}\nIndirect:\n";
    foreach my $indirect (@indirect_files) {
      $tag_text .= "$indirect->[0]: $indirect->[1]\n";
    }
  }

  $tag_text .= "\x{1F}\nTag Table:\n";
  if ($out_file_nr > 1) {
    $tag_text .=  "(Indirect)\n";
  }
  # This may happen for anchors in @insertcopying
  my %seen_anchors;
  foreach my $label (@{$self->{'count_context'}->[-1]->{'locations'}}) {
    next unless ($label->{'root'} and $label->{'root'}->{'extra'}
                 and $label->{'root'}->{'extra'}->{'is_target'});
    my $label_element = Texinfo::Common::get_label_element($label->{'root'});
    my $prefix;

    if ($label->{'root'}->{'cmdname'} eq 'node') {
      $prefix = 'Node';
    } else {
      $prefix = 'Ref';
    }
    my ($label_text, undef) = $self->node_name($label->{'root'});

    if ($seen_anchors{$label_text}) {
      $self->plaintext_line_error($self,
                                  sprintf(__("\@%s output more than once: %s"),
          $label->{'root'}->{'cmdname'},
          Texinfo::Convert::Texinfo::convert_to_texinfo({'contents' =>
                                                  $label_element->{'contents'}})),
        $label->{'root'}->{'source_info'});
      next;
    } else {
      $seen_anchors{$label_text} = 1;
    }

    $tag_text .=  "$prefix: $label_text\x{7F}$label->{'bytes'}\n";
  }
  $tag_text .=  "\x{1F}\nEnd Tag Table\n";

  my $coding = $self->get_conf('OUTPUT_ENCODING_NAME');
  my $documentlanguage = $self->get_conf('documentlanguage');

  if ($coding or $documentlanguage) {
    # Note: Info readers expect the Local Variables section to be
    # under 1000 bytes in length so not many variables can be added here.
    $tag_text .= "\n\x{1F}\nLocal Variables:\n";
    $tag_text .= "coding: $coding\n" if $coding;
    $tag_text .= "Info-documentlanguage: $documentlanguage\n"
      if $documentlanguage;
    $tag_text .= "End:\n";
  }
  if ($fh) {
    print $fh $tag_text;
    # NOTE it should be possible to close STDOUT.  However this leads to
    # 'Filehandle STDOUT reopened as FH only for input' if there are files
    # reopened after closing STDOUT.  So closing STDOUT is handled by the
    # caller.
    unless ($output_file eq '-') {
      $self->_register_closed_info_file($output_file);
      if (!close ($fh)) {
        $self->converter_document_error(
                  sprintf(__("error on closing %s: %s"),
                              $output_file, $!));
      }
    }
  } else {
    $result .= $tag_text;
  }
  $self->conversion_finalization();
  return $result;
}

# Wrapper around Texinfo::Convert::Utils::output_files_open_out.  Open the file
# with any CR-LF conversion disabled.  We need this for tag tables to
# be correct under MS-Windows.   Return filehandle or undef on failure.
sub _open_info_file($$)
{
  my $self = shift;
  my $filename = shift;

  my ($encoded_filename, $path_encoding)
      = $self->encoded_output_file_name($filename);

  # the third return information, set if the file has already been used
  # in this files_information is not checked as this cannot happen.
  my ($fh, $error_message) = Texinfo::Convert::Utils::output_files_open_out(
                               $self->output_files_information(), $self,
                               $encoded_filename, 'use_binmode');

  if (!$fh) {
    $self->converter_document_error(sprintf(
        __("could not open %s for writing: %s"),
        $filename, $error_message));
    return undef;
  }
  return $fh;
}

sub _register_closed_info_file($$)
{
  my $self = shift;
  my $filename = shift;

  my ($encoded_filename, $path_encoding)
      = $self->encoded_output_file_name($filename);

  Texinfo::Convert::Utils::output_files_register_closed(
             $self->output_files_information(), $encoded_filename)
}

# Return (encoded) info header
sub _info_header($$$)
{
  my $self = shift;
  my $input_basefile = shift;
  my $output_filename = shift;

  push @{$self->{'count_context'}}, {'lines' => 0, 'bytes' => 0,
                                     'locations' => []};

  my $paragraph = Texinfo::Convert::Paragraph->new();
  my $result = add_text($paragraph, "This is ");
  # This ensures that spaces in file are kept.
  $result .= add_next($paragraph, $output_filename);
  my $program = $self->get_conf('PROGRAM');
  my $version = $self->get_conf('PACKAGE_VERSION');
  if (defined($program) and $program ne '') {
    $result .=
        add_text($paragraph, ", produced by $program version $version from ");
  } else {
    $result .= add_text($paragraph, ", produced from ");
  }
  $result .= add_next($paragraph, $input_basefile);
  $result .= add_text($paragraph, '.');
  $result .= Texinfo::Convert::Paragraph::end($paragraph);
  $result .= "\n";
  $self->_stream_output($result, $paragraph);

  my $global_commands;
  if ($self->{'document'}) {
    $global_commands = $self->{'document'}->global_commands_information();
  }
  # format @copying using the last value of the preamble.
  my @informative_global_commands = $self->get_informative_global_commands();
  $self->set_global_document_commands('preamble', \@informative_global_commands);
  if ($global_commands and $global_commands->{'copying'}) {
    print STDERR "COPYING HEADER\n" if ($self->get_conf('DEBUG'));
    $self->{'in_copying_header'} = 1;
    $self->_convert({'contents' =>
          $global_commands->{'copying'}->{'contents'}});
    $self->process_footnotes();
    delete $self->{'in_copying_header'};
  }
  $self->set_global_document_commands('before', \@informative_global_commands);

  if ($global_commands->{'dircategory_direntry'}) {
    $self->{'ignored_commands'}->{'direntry'} = 0;
    foreach my $command (@{$global_commands->{'dircategory_direntry'}}) {
      if ($command->{'cmdname'} eq 'dircategory') {
        if ($command->{'args'} and @{$command->{'args'}}
            and defined($command->{'args'}->[0]->{'contents'})) {
          my ($converted, undef) = $self->convert_line_new_context(
             {'contents' => $command->{'args'}->[0]->{'contents'}});
          $self->_stream_output("INFO-DIR-SECTION " . $converted . "\n");
        }
      } elsif ($command->{'cmdname'} eq 'direntry') {
        $self->_stream_output("START-INFO-DIR-ENTRY\n");
        $self->_convert($command);
        $self->_stream_output("END-INFO-DIR-ENTRY\n\n");
      }
    }
    $self->{'ignored_commands'}->{'direntry'} = 1;
  }
  $self->_add_newline_if_needed();
  $result = $self->_stream_result();
  pop @{$self->{'count_context'}};
  return $result;
}

sub format_warn_strong_note($)
{
  return 1;
}

sub format_contents($$$)
{
  my $self = shift;
  my $section_root = shift;
  my $contents_or_shortcontents = shift;

  return ('', 0);
}

sub format_printindex($$)
{
  my $self = shift;
  my $printindex = shift;
  return $self->process_printindex($printindex, 1);
}

sub format_error_outside_of_any_node($$)
{
  my $self = shift;
  my $element = shift;
  if (!$self->{'current_node'}) {
    $self->plaintext_line_warn($self,
         sprintf(__("\@%s outside of any node"),
                 $element->{'cmdname'}), $element->{'source_info'});
  }
}

sub format_ref($$$$)
{
  my $self = shift;
  my $cmdname = shift;
  my $element = shift;
  my $formatter = shift;

  my @args;
  for my $arg (@{$element->{'args'}}) {
    if (defined $arg->{'contents'}) {
      push @args, $arg;
    } else {
      push @args, undef;
    }
  }
  $args[0] = {'text' => ''} if (!defined($args[0]));

  my $node_arg = $element->{'args'}->[0];

  # normalize node name, to get a ref with the right formatting
  # NOTE as a consequence, the line numbers appearing in case of errors
  # correspond to the node lines numbers, and not the @ref.
  my $label_element;
  my $target_element;

  my $identifiers_target;
  if ($self->{'document'}) {
    $identifiers_target = $self->{'document'}->labels_information();
  }

  if ($node_arg and $node_arg->{'extra'}
      and !$node_arg->{'extra'}->{'manual_content'}
      # excludes external nodes, as only internal refs get an extra normalized
      and defined($node_arg->{'extra'}->{'normalized'})
      # exlude external nodes again, in case internal refs get normalized
      and !defined($args[3])
      and !defined($args[4])
      and $identifiers_target
      and $identifiers_target->{$node_arg->{'extra'}->{'normalized'}}) {
    $target_element
      = $identifiers_target->{$node_arg->{'extra'}->{'normalized'}};
    $label_element
      = Texinfo::Common::get_label_element($target_element);
    if (defined($label_element) and !$label_element->{'contents'}) {
      $label_element = undef;
    }
  }
  if (!defined($label_element)) {
    $label_element = $args[0];
  }

  # if it a reference to a float with a label, $arg[1] is
  # set to '$type $number' or '$number' if there is no type.
  if (! defined($args[1])
      and $target_element and $target_element->{'cmdname'}
      and $target_element->{'cmdname'} eq 'float') {
    my $name = $self->float_type_number($target_element);
    $args[1] = $name;
  }
  if ($cmdname eq 'inforef' and scalar(@args) >= 3) {
    $args[3] = $args[2];
    $args[2] = undef;
  }

  # Treat cross-reference commands in a multitable cell as if they
  # were surrounded by @w{ ... }, so not to split output across
  # lines, leading text from other columns appearing to be part of the
  # cross-reference.
  my $in_multitable = 0;
  if ($self->{'document_context'}->[-1]->{'in_multitable'}) {
    $in_multitable = 1;
    $formatter->{'w'}++;
    set_space_protection($formatter->{'container'}, 1, undef)
      if ($formatter->{'w'} == 1);
  }
  # Disallow breaks in runs of Chinese text in node names, because a
  # break would be normalized to a single space by the Info reader, and
  # the node wouldn't be found.
  set_space_protection($formatter->{'container'},
              undef, undef, undef, undef, 1);

  if ($cmdname eq 'xref') {
    $self->_convert({'type' => '_stop_upper_case',
                     'contents' => [{'text' => '*Note '}]});
  } else {
    $self->_convert({'type' => '_stop_upper_case',
                     'contents' => [{'text' => '*note '}]});
  }
  my $name;
  if (defined($args[1])) {
    $name = $args[1];
  } elsif (defined($args[2])) {
    $name = $args[2];
  }
  my $file;
  if (defined($args[3])) {
    $file = {'contents' => [
               {'text' => '('},
               {'type' => '_stop_upper_case',
                  'contents' => [{'type' => '_code',
                                   'contents' => [$args[3]]}],},
               {'text' => ')'},]};
  } elsif (defined($args[4])) {
    # add a () such that the node is considered to be external,
    # even though the manual name is not known.  This should only
    # happen if a book argument is given, but no manual name.
    $file = {'text' => '()'};
  }

  if ($name) {
    push @{$self->{'count_context'}}, {'lines' => 0, 'bytes' => 0};
    $self->_convert($name);
    my $name_text = $self->_stream_result();
    # needed, as last word is added only when : is added below
    # NB this mixes encoded and unencoded strings but is ok for
    # checking for : only
    my $name_text_checked = $name_text
       .get_pending($self->{'formatters'}->[-1]->{'container'});
    my $quoting_required = 0;
    if ($name_text_checked =~ /:/m) {
      if ($self->{'info_special_chars_warning'}) {
        $self->plaintext_line_warn($self, sprintf(__(
           "\@%s cross-reference name should not contain `:'"),
                                 $cmdname), $element->{'source_info'});
      }
      if ($self->{'info_special_chars_quote'}) {
        $quoting_required = 1;
      }
    }
    my $pre_quote = $quoting_required ? "\x{7f}" : '';
    my $post_quote = $pre_quote;

    $self->_stream_output(
             add_text($formatter->{'container'}, "$post_quote: "),
             $formatter->{'container'});
    my $result = $self->_stream_result();

    # Note post_quote has to be added first to flush output
    $result =~ s/^(\s*)/$1$pre_quote/ if $pre_quote;

    my $lines_added = $self->{'count_context'}->[-1]->{'lines'};
    pop @{$self->{'count_context'}};
    $self->_stream_output_encoded($result);
    $self->{'count_context'}->[-1]->{'lines'} += $lines_added;
  }

  if ($file) {
    $self->_convert($file);
  }

  my $node_name;

  # Get the node name to be output.
  # Due to the paragraph formatter holding pending text, converting
  # the node name with the current formatter does not yield all the
  # converted text.  To get the full node name (and no more), we
  # can convert in a new context, using convert_line_new_context.
  # However, it is slow to do this for every node.  So in the most
  # frequent case when the node name is a simple text element, use
  # that text instead.
  if ($label_element and $label_element->{'contents'}
      and scalar(@{$label_element->{'contents'}}) == 1
      and defined($label_element->{'contents'}->[0]->{'text'})) {
    $node_name = $label_element->{'contents'}->[0]->{'text'};
  } else {
    $self->{'silent'} = 0 if (!defined($self->{'silent'}));
    $self->{'silent'}++;

    ($node_name, undef) = $self->convert_line_new_context(
                                  {'type' => '_code',
                                   'contents' => [$label_element]},
                                  {'suppress_styles' => 1,
                                    'no_added_eol' => 1});
    $self->{'silent'}--;
  }
  if (defined($file) and $node_name !~ /\S/) {
    # Some Info reader versions, at least the Info reader from
    # Texinfo 6.8 and 7.1 cannot follow a cross-reference
    # consisting only of a manual name, such as *Note (manual)::.
    # The Emacs Info reader does not seem to have this problem.
    # Add a Top node to have a node name.
    # Should probably be removed about 10-15 years after Info
    # reader have been fixed.
    $label_element = {'text' => 'Top'};
  }

  my $check_chars;
  if ($name) {
    $check_chars = quotemeta ",\t.";
  } else {
    $check_chars = quotemeta ":";
  }

  my $quoting_required = 0;
  if ($node_name =~ /([$check_chars])/m) {
    if ($self->{'info_special_chars_warning'}) {
      $self->plaintext_line_warn($self, sprintf(__(
         "\@%s node name should not contain `%s'"), $cmdname, $1),
                       $element->{'source_info'});
    }
    if ($self->{'info_special_chars_quote'}) {
      $quoting_required = 1;
    }
  }

  my $pre_quote = $quoting_required ? "\x{7f}" : '';
  my $post_quote = $pre_quote;

  # node name
  $self->_stream_output(
    add_next($self->{'formatters'}->[-1]->{'container'}, $pre_quote),
    $self->{'formatters'}[-1]{'container'})
         if $pre_quote;

  $self->{'formatters'}->[-1]->{'suppress_styles'} = 1;
  $self->_convert({'type' => '_stop_upper_case',
                   'contents' => [
                     {'type' => '_code',
                      'contents' => [$label_element]}]});
  delete $self->{'formatters'}->[-1]->{'suppress_styles'};

  $self->_stream_output(
    add_next($self->{'formatters'}->[-1]->{'container'}, $post_quote),
    $self->{'formatters'}[-1]{'container'})
         if $post_quote;

  if (!$name) {
    $self->_stream_output(
      add_next($self->{'formatters'}->[-1]->{'container'}, '::'),
      $self->{'formatters'}[-1]{'container'});
  }

  # Check if punctuation follows the ref command with a label
  # argument.  If not, add a full stop.
  if ($name) {
    # Find next element
    my $next;
    my $current_contents = $element->{'parent'}->{'contents'};
    my $contents_nr = scalar(@$current_contents);
    for (my $i = 0; $i < $contents_nr - 1; $i++) {
      if ($current_contents->[$i] == $element) {
        $next = $current_contents->[$i+1];
        last;
      }
    }

    if (!($next and $next->{'text'}
          and $next->{'text'} =~ /^[\.,]/)) {
      # In the past, it was explicily described in the manual that
      # some punctuation was automatically added for @pxref only,
      # while the other commands required a following full stop or
      # comma.
      #
      # It is better if the user manages to find a wording with a
      # comma or full stop following naturally the ref command.
      # However, it is not possible in general except for @xref -- and
      # even for @xref it may be cumbersome.  Therefore we only warn
      # that a comma or full stop is missing with @xref such that the
      # user tries to add it in that case, in the other case, we
      # automatically add a full stop without warning.
      #
      # There cannot be a perfect solution, as these issues stem from
      # the Info language design where it is not possible to
      # distinguish if punctuation used in cross reference is
      # part of the text or is added and should be considered as markup.
      if ($cmdname eq 'xref') {
        if ($next and defined($next->{'text'})
            and $next->{'text'} =~ /\S/) {
          my $text = $next->{'text'};
          $text =~ s/^\s*//;
          my $char = substr($text, 0, 1);
          $self->plaintext_line_warn($self, sprintf(__(
                      "`.' or `,' must follow \@xref, not %s"),
                                   $char), $element->{'source_info'});
        } else {
          $self->plaintext_line_warn($self,
                     __("`.' or `,' must follow \@xref"),
                           $element->{'source_info'});
        }
      }
      my @added = ({'text' => '.'});
      # The added full stop does not end a sentence.  Info readers will
      # have a chance of guessing correctly whether the full stop was
      # added by whether it is followed by 2 spaces (although this
      # doesn't help at the end of a line nor when a parenthesis
      # follows the ref command).
      push @added, {'cmdname' => ':'};
      for my $added_element (@added) {
        $self->_convert($added_element);
      }
    }
  }

  if ($in_multitable) {
    $formatter->{'w'}--;
    set_space_protection($formatter->{'container'}, 0, undef)
      if ($formatter->{'w'} == 0);
  }
  set_space_protection($formatter->{'container'},
    undef,undef,undef,undef,0); # double_width_no_break
}

my @directions = ('Next', 'Prev', 'Up');
sub format_node($$)
{
  my $self = shift;
  my $node = shift;

  return '' if (not $node->{'extra'}
                or not $node->{'extra'}->{'is_target'});

  my ($node_text, undef) = $self->node_name($node);

  my $output_filename;
  if (defined($self->{'output_filename'})) {
    $output_filename = $self->{'output_filename'};
  } else {
    # May happen when only converting a fragment
    $output_filename = '';
  }

  $self->add_location($node);
  my $node_begin = "\x{1F}\nFile: $output_filename,  Node: ";
  $self->_stream_output($node_begin);

  my $pre_quote = '';
  my $post_quote = '';
  if ($node_text =~ /,/) {
    if ($self->{'info_special_chars_warning'}) {
      $self->plaintext_line_warn($self, sprintf(__(
                 "\@node name should not contain `,': %s"),
                     $self->_decode($node_text)), $node->{'source_info'});
    }
    if ($self->{'info_special_chars_quote'}) {
      $pre_quote = "\x{7f}";
      $post_quote = $pre_quote;
    }
  }
  $self->_stream_output_encoded($pre_quote . $node_text . $post_quote);
  foreach my $direction (@directions) {
    if ($node->{'extra'}->{'node_directions'}
        and $node->{'extra'}->{'node_directions'}->{lc($direction)}) {
      my $node_direction
          = $node->{'extra'}->{'node_directions'}->{lc($direction)};
      $self->_stream_output(",  $direction: ");
      if ($node_direction->{'extra'}->{'manual_content'}) {
        $self->convert_line({'type' => '_code',
                          'contents' => [{'text' => '('},
                             $node_direction->{'extra'}->{'manual_content'},
                                          {'text' => ')'}]});
      }
      if (defined($node_direction->{'extra'}->{'normalized'})) {
        my $pre_quote = '';
        my $post_quote = '';
        my ($node_text, undef) = $self->node_name($node_direction);
        # Up may not strictly need protection, as it is the last direction,
        # but we protect consistently
        if ($node_text =~ /,/) {
          if ($self->{'info_special_chars_warning'}
              # warn only for external nodes, internal nodes should already
              # trigger a warning when defined
              and $node_direction->{'extra'}->{'manual_content'}) {
            $self->plaintext_line_warn($self, sprintf(__(
                 "\@node %s name should not contain `,': %s"),
                                     $direction, $self->_decode($node_text)),
                             $node->{'source_info'});
          }
          if ($self->{'info_special_chars_quote'}) {
            $pre_quote = "\x{7f}";
            $post_quote = $pre_quote;
          }
        }
        $self->_stream_output_encoded($pre_quote . $node_text . $post_quote);
      }
    } elsif ($direction eq 'Up'
             and $node->{'extra'}->{'normalized'} eq 'Top') {
      # add an up direction for Top node
      my $top_node_up = $self->get_conf('TOP_NODE_UP');
      if (defined($top_node_up)) {
        $self->_stream_output(",  $direction: ".$top_node_up);
      }
    }
  }
  $self->_stream_output("\n\n");
  $self->{'count_context'}->[-1]->{'lines'} = 3;

  return;
}

my @image_files_extensions = ('.png', '.jpg');
sub format_image($$)
{
  my $self = shift;
  my $element = shift;
  my @extensions = @image_files_extensions;

  my $lines_count = 0;

  if ($element->{'args'}
      and $element->{'args'}->[0]->{'contents'}) {
    Texinfo::Convert::Text::set_options_code(
                                 $self->{'convert_text_options'});
    my $basefile = Texinfo::Convert::Text::convert_to_text(
                                         $element->{'args'}->[0],
                                   $self->{'convert_text_options'});
    Texinfo::Convert::Text::reset_options_code(
                                 $self->{'convert_text_options'});

    if (defined($element->{'args'}->[4])
        and $element->{'args'}->[4]->{'contents'}
        and @{$element->{'args'}->[4]->{'contents'}}) {
      Texinfo::Convert::Text::set_options_code(
                                 $self->{'convert_text_options'});
      my $extension = Texinfo::Convert::Text::convert_to_text(
                                         $element->{'args'}->[4],
                                   $self->{'convert_text_options'});
      Texinfo::Convert::Text::reset_options_code(
                                 $self->{'convert_text_options'});
      unshift @extensions, ".$extension";
      unshift @extensions, "$extension";
    }
    my $image_file;
    foreach my $extension (@extensions) {
      my ($file_name, $file_name_encoding)
        = $self->encoded_input_file_name($basefile.$extension);
      if (Texinfo::Common::locate_include_file($file_name,
                          $self->get_conf('INCLUDE_DIRECTORIES'))) {
        # use the basename and not the file found.  It is agreed that it is
        # better, since in any case the files are moved.
        # If the file path found was to be used it should be decoded to perl
        # codepoints too.
        $image_file = $basefile.$extension;
        last;
      }
    }
    my ($text, $width) = $self->txt_image_text($element, $basefile);
    # remove last end of line
    chomp($text) if (defined($text));
    my $alt;
    if (defined($element->{'args'}->[3])
        and $element->{'args'}->[3]->{'contents'}
        and @{$element->{'args'}->[3]->{'contents'}}) {
     $alt = Texinfo::Convert::Text::convert_to_text(
                                    $element->{'args'}->[3],
                                  $self->{'convert_text_options'});
    }

    my $result;

    if (defined($image_file) or (defined($text) and defined($alt))) {
      if (defined($image_file)) {
        $image_file =~ s/\\/\\\\/g;
        $image_file =~ s/\"/\\\"/g;
      } else {
        $image_file = '';
      }
      $result = "\x{00}\x{08}[image src=\"$image_file\"";

      if (defined($alt) and $alt ne '') {
        $alt =~ s/\\/\\\\/g;
        $alt =~ s/\"/\\\"/g;
        $result .= " alt=\"$alt\"";
      }
      if (defined($text)) {
        $text =~ s/\\/\\\\/g;
        $text =~ s/\"/\\\"/g;
        $result .= " text=\"$text\"";
      }
      $result .= "\x{00}\x{08}]";
      if ($self->{'formatters'}->[-1]->{'_top_formatter'}) {
        $result .= "\n";
      }
      $lines_count = ($result =~ tr/\n/\n/);
      $self->add_image($element, $lines_count +1, $width, 1);
    } else {
      $result = $self->image_formatted_text($element, $basefile, $text);
      $lines_count = ($result =~ tr/\n/\n/);
      $self->add_image($element, $lines_count +1, $width);
    }
    return ($result, $lines_count);
  }
  return ('', 0);
}

1;

__END__
# Automatically generated from maintain/template.pod

=head1 NAME

Texinfo::Convert::Info - Convert Texinfo tree to Info

=head1 SYNOPSIS

  my $converter
    = Texinfo::Convert::Info->converter({'NUMBER_SECTIONS' => 0});

  $converter->output($document);
  $converter->convert($document);
  $converter->convert_tree($tree);

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

Texinfo::Convert::Info converts a Texinfo tree to Info.

=head1 METHODS

=over

=item $converter = Texinfo::Convert::Info->converter($options)

Initialize converter from Texinfo to Info.

The I<$options> hash reference holds Texinfo customization options for the
converter.  These options should be Texinfo customization options
that can be passed to the converter.  Most of the customization options are
described in the Texinfo manual or in the customization API manual.  Those
customization options, when appropriate, override the document content.

See L<Texinfo::Convert::Converter> for more information.

=item $converter->output($document)

Convert a Texinfo parsed document I<$document> and output the result in files as
described in the Texinfo manual.

=item $result = $converter->convert($document)

Convert a Texinfo parsed document I<$document> and return the resulting output.

=item $result = $converter->convert_tree($tree)

Convert a Texinfo tree portion I<$tree> and return the resulting
output.  This function does not try to output a full document but only
portions.  For a full document use C<convert>.

In general, this function should be called after the converter has been
associated to a document by a call to C<output> or C<convert>.

=back

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
