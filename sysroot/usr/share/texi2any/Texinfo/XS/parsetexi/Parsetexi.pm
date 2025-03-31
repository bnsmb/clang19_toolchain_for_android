# Copyright 2014-2024 Free Software Foundation, Inc.
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

# Since there are different parser implementation, XS and NonXS, it is
# better to have the Texinfo::Parser packages define only the parser
# API functions.  Constants, functions useful in both parsers, and other
# functions useful in other codes are better defined in other Texinfo
# modules.

# File to be loaded in conjunction with Parsetexi.xs module
#
# In general, the Parser works with character strings decoded from the
# command line, from input files or from the parsed document and returns
# character strings.  There are exceptions for the following files and
# directory names that are binary strings:
# * the input file name passed through parse_texi_file is a binary string
# * the 'file_name' values in 'source_info' from convert_errors and in
#   the tree elements 'source_info' are returned as binary strings

package Texinfo::Parser;

use 5.008;
use strict;
use warnings;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Texinfo::Report;
# Not directly used, but the returned variables are in this module, this
# import makes sure that the functions associated to the objects are found.
use Texinfo::Document;

# Initialize the parser
# The last argument, optional, is a hash provided by the user to change
# the default values for what is present in %parser_document_parsing_options.
sub parser (;$)
{
  my $conf = shift;

  my $parser = {};
  bless $parser;

  # pass directly DEBUG value to reset_parser to override previous
  # parser configuration, as the configuration isn't already reset and the new
  # configuration is set afterwards.
  my $debug = 0;
  $debug = $conf->{'DEBUG'} if ($conf and $conf->{'DEBUG'});

  # The reset_parser call resets the conf to the same values as found in
  # Texinfo::Common parser_document_parsing_options.
  reset_parser($debug);

  # (re)set debug in any case, assuming that undef DEBUG is no debug
  parser_conf_set_DEBUG($debug);

  # Storing conf is only needed if the parser is reused.  There could be
  # a customization variable.  Instead, we set store_conf to 0 if
  # accept_internalvalue is set, if called from gdt as we know for sure that
  # the parser is not gonna be reused.
  my $store_conf = 1;
  if (defined($conf)) {
    foreach my $key (keys(%$conf)) {
      if ($key eq 'INCLUDE_DIRECTORIES') {
        parser_store_INCLUDE_DIRECTORIES($conf->{'INCLUDE_DIRECTORIES'});
      } elsif ($key eq 'values') {
        parser_store_values($conf->{'values'});
      } elsif ($key eq 'EXPANDED_FORMATS') {
        parser_store_EXPANDED_FORMATS($conf->{'EXPANDED_FORMATS'});
      } elsif ($key eq 'documentlanguage') {
        if (defined ($conf->{$key})) {
          parser_conf_set_documentlanguage($conf->{$key});
        }
      } elsif ($key eq 'FORMAT_MENU') {
        if ($conf->{$key} and $conf->{$key} eq 'menu') {
          parser_conf_set_show_menu(1);
        } else {
          parser_conf_set_show_menu(0);
        }
      } elsif ($key eq 'IGNORE_SPACE_AFTER_BRACED_COMMAND_NAME') {
        parser_conf_set_IGNORE_SPACE_AFTER_BRACED_COMMAND_NAME($conf->{$key});
      } elsif ($key eq 'CPP_LINE_DIRECTIVES') {
        parser_conf_set_CPP_LINE_DIRECTIVES($conf->{$key});
      } elsif ($key eq 'MAX_MACRO_CALL_NESTING') {
        parser_conf_set_MAX_MACRO_CALL_NESTING($conf->{$key});
      } elsif ($key eq 'NO_INDEX') {
        parser_conf_set_NO_INDEX($conf->{$key});
      } elsif ($key eq 'NO_USER_COMMANDS') {
        parser_conf_set_NO_USER_COMMANDS($conf->{$key});
      } elsif ($key eq 'DOC_ENCODING_FOR_INPUT_FILE_NAME') {
        parser_conf_set_DOC_ENCODING_FOR_INPUT_FILE_NAME($conf->{$key});
      } elsif ($key eq 'INPUT_FILE_NAME_ENCODING') {
        if (defined($conf->{$key})) {
          parser_conf_set_INPUT_FILE_NAME_ENCODING($conf->{$key});
        }
      } elsif ($key eq 'LOCALE_ENCODING') {
        if (defined($conf->{$key})) {
          parser_conf_set_LOCALE_ENCODING($conf->{$key});
        }
      } elsif ($key eq 'COMMAND_LINE_ENCODING') {
        if (defined($conf->{$key})) {
          parser_conf_set_COMMAND_LINE_ENCODING($conf->{$key});
        }
      } elsif ($key eq 'accept_internalvalue') {
        if ($conf->{$key}) {
          # called from gdt, no need to store the parser configuration
          parser_conf_set_accept_internalvalue(1);
          $store_conf = 0;
        }
      } elsif ($key eq 'DEBUG') {
        # no action needed, already taken into account
      } else {
        warn "ignoring parser configuration value \"$key\"\n";
      }
    }
  }
  if ($store_conf) {
    register_parser_conf($parser);
  }

  return $parser;
}

1;
__END__

The POD documentation of Texinfo::Parser is in Texinfo::ParserNonXS.
