# Unicode.pm: handle conversion to unicode.
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

package Texinfo::Convert::Unicode;

# Documentation of earlier releases for perluniintro is missing.
# charnames::vianame is not documented in 5.6.0.
use 5.008;
use strict;

# To check if there is no erroneous autovivification
#no autovivification qw(fetch delete exists store strict);

use Carp qw(cluck);

use Encode;
use Unicode::Normalize;
use Unicode::EastAsianWidth;
# To obtain unicode characters based on code points represented as
# strings
use charnames ();

use Texinfo::MiscXS;

require Exporter;

# Some extra initialization for the first time this module is loaded.
# This could be done in a UNITCHECK block, but they were introduced in
# Perl 5.10.
our $module_loaded = 0;
sub import {
  if (!$module_loaded) {
    Texinfo::XSLoader::override("Texinfo::Convert::Unicode::unicode_text",
                                "Texinfo::MiscXS::unicode_text");
    $module_loaded = 1;
  }
  # The usual import method.
  goto &Exporter::import;
}

our @EXPORT_OK = qw(
  unicode_accent
  encoded_accents
  brace_no_arg_command
  unicode_text
  string_width
);

our $VERSION = '7.2';


our %unicode_diacritics = (
       'H'          => '030B',
       'ringaccent' => '030A',
       "'"          => '0301',
       'v'          => '030C',
       ','          => '0327',
       '^'          => '0302',
       'dotaccent'  => '0307',
       '`'          => '0300',
       '='          => '0304',
       '~'          => '0303',
       '"'          => '0308',
       'udotaccent' => '0323',
       'ubaraccent' => '0332',
       'u'          => '0306',
       'tieaccent'  => '0361',
       'ogonek'     => '0328'
);

our %diacritics_accent_commands;
foreach my $diacritic(keys(%unicode_diacritics)) {
  $diacritics_accent_commands{$unicode_diacritics{$diacritic}} = $diacritic;
}

# dotless in unicode_accented_letters not in diacritics,
# tieaccent in diacritics not in unicode_accented_letters.
our %unicode_accented_letters = (
    'dotaccent' => { # dot above
        'A' => '0226',
        'a' => '0227',
        'B' => '1E02',
        'b' => '1E03',
        'C' => '010A',
        'c' => '010B',
        'D' => '1E0A',
        'd' => '1E0B',
        'E' => '0116',
        'e' => '0117',
        'F' => '1E1E',
        'f' => '1E1F',
        'G' => '0120',
        'g' => '0121',
        'H' => '1E22',
        'h' => '1E23',
        'i' => '0069',
        'I' => '0130',
        'N' => '1E44',
        'n' => '1E45',
        'O' => '022E',
        'o' => '022F',
        'P' => '1E56',
        'p' => '1E57',
        'R' => '1E58',
        'r' => '1E59',
        'S' => '1E60',
        's' => '1E61',
        'T' => '1E6A',
        't' => '1E6B',
        'W' => '1E86',
        'w' => '1E87',
        'X' => '1E8A',
        'x' => '1E8B',
        'Y' => '1E8E',
        'y' => '1E8F',
        'Z' => '017B',
        'z' => '017C',
    },
    'udotaccent' => { # dot below
        'A' => '1EA0',
        'a' => '1EA1',
        'B' => '1E04',
        'b' => '1E05',
        'D' => '1E0C',
        'd' => '1E0D',
        'E' => '1EB8',
        'e' => '1EB9',
        'H' => '1E24',
        'h' => '1E25',
        'I' => '1ECA',
        'i' => '1ECB',
        'K' => '1E32',
        'k' => '1E33',
        'L' => '1E36',
        'l' => '1E37',
        'M' => '1E42',
        'm' => '1E43',
        'N' => '1E46',
        'n' => '1E47',
        'O' => '1ECC',
        'o' => '1ECD',
        'R' => '1E5A',
        'r' => '1E5B',
        'S' => '1E62',
        's' => '1E63',
        'T' => '1E6C',
        't' => '1E6D',
        'U' => '1EE4',
        'u' => '1EE5',
        'V' => '1E7E',
        'v' => '1E7F',
        'W' => '1E88',
        'w' => '1E89',
        'Y' => '1EF4',
        'y' => '1EF5',
        'Z' => '1E92',
        'z' => '1E93',
    },
    'ubaraccent' => { # line below
        'B' => '1E06',
        'b' => '1E07',
        'D' => '1E0E',
        'd' => '1E0F',
        'h' => '1E96',
        'K' => '1E34',
        'k' => '1E35',
        'L' => '1E3A',
        'l' => '1E3B',
        'N' => '1E48',
        'n' => '1E49',
        'R' => '1E5E',
        'r' => '1E5F',
        'T' => '1E6E',
        't' => '1E6F',
        'Z' => '1E94',
        'z' => '1E95',
    },
    ',' => { # cedilla
        'C' => '00C7',
        'c' => '00E7',
        'D' => '1E10',
        'd' => '1E11',
        'E' => '0228',
        'e' => '0229',
        'G' => '0122',
        'g' => '0123',
        'H' => '1E28',
        'h' => '1E29',
        'K' => '0136',
        'k' => '0137',
        'L' => '013B',
        'l' => '013C',
        'N' => '0145',
        'n' => '0146',
        'R' => '0156',
        'r' => '0157',
        'S' => '015E',
        's' => '015F',
        'T' => '0162',
        't' => '0163',
    },
    '=' => { # macron
        'A' => '0100',
        'a' => '0101',
        'E' => '0112',
        'e' => '0113',
        'I' => '012A',
        'i' => '012B',
        'G' => '1E20',
        'g' => '1E21',
        'O' => '014C',
        'o' => '014D',
        'U' => '016A',
        'u' => '016B',
        'Y' => '0232',
        'y' => '0233',
    },
    '"' => { # diaeresis
        'A' => '00C4',
        'a' => '00E4',
        'E' => '00CB',
        'e' => '00EB',
        'H' => '1E26',
        'h' => '1E27',
        'I' => '00CF',
        'i' => '00EF',
        'O' => '00D6',
        'o' => '00F6',
        't' => '1E97',
        'U' => '00DC',
        'u' => '00FC',
        'W' => '1E84',
        'w' => '1E85',
        'X' => '1E8C',
        'x' => '1E8D',
        'y' => '00FF',
        'Y' => '0178',
    },
    'u' => { # breve
        'A' => '0102',
        'a' => '0103',
        'E' => '0114',
        'e' => '0115',
        'G' => '011E',
        'g' => '011F',
        'I' => '012C',
        'i' => '012D',
        'O' => '014E',
        'o' => '014F',
        'U' => '016C',
        'u' => '016D',
    },
    "'" => { # acute
        'A' => '00C1',
        'a' => '00E1',
        'C' => '0106',
        'c' => '0107',
        'E' => '00C9',
        'e' => '00E9',
        'G' => '01F4',
        'g' => '01F5',
        'I' => '00CD',
        'i' => '00ED',
        'K' => '1E30',
        'k' => '1E31',
        'L' => '0139',
        'l' => '013A',
        'M' => '1E3E',
        'm' => '1E3F',
        'N' => '0143',
        'n' => '0144',
        'O' => '00D3',
        'o' => '00F3',
        'P' => '1E54',
        'p' => '1E55',
        'R' => '0154',
        'r' => '0155',
        'S' => '015A',
        's' => '015B',
        'U' => '00DA',
        'u' => '00FA',
        'W' => '1E82',
        'w' => '1E83',
        'Y' => '00DD',
        'y' => '00FD',
        'Z' => '0179',
        'z' => '017A',
    },
    '~' => { # tilde
        'A' => '00C3',
        'a' => '00E3',
        'E' => '1EBC',
        'e' => '1EBD',
        'I' => '0128',
        'i' => '0129',
        'N' => '00D1',
        'n' => '00F1',
        'O' => '00D5',
        'o' => '00F5',
        'U' => '0168',
        'u' => '0169',
        'V' => '1E7C',
        'v' => '1E7D',
        'Y' => '1EF8',
        'y' => '1EF9',
    },
    '`' => { # grave
        'A' => '00C0',
        'a' => '00E0',
        'E' => '00C8',
        'e' => '00E8',
        'I' => '00CC',
        'i' => '00EC',
        'N' => '01F8',
        'n' => '01F9',
        'O' => '00D2',
        'o' => '00F2',
        'U' => '00D9',
        'u' => '00F9',
        'W' => '1E80',
        'w' => '1E81',
        'Y' => '1EF2',
        'y' => '1EF3',
    },
    '^' => { # circumflex
        'A' => '00C2',
        'a' => '00E2',
        'C' => '0108',
        'c' => '0109',
        'E' => '00CA',
        'e' => '00EA',
        'G' => '011C',
        'g' => '011D',
        'H' => '0124',
        'h' => '0125',
        'I' => '00CE',
        'i' => '00EE',
        'J' => '0134',
        'j' => '0135',
        'O' => '00D4',
        'o' => '00F4',
        'S' => '015C',
        's' => '015D',
        'U' => '00DB',
        'u' => '00FB',
        'W' => '0174',
        'w' => '0175',
        'Y' => '0176',
        'y' => '0177',
        'Z' => '1E90',
        'z' => '1E91',
    },
    'ringaccent' => { # ring
        'A' => '00C5',
        'a' => '00E5',
        'U' => '016E',
        'u' => '016F',
        'w' => '1E98',
        'y' => '1E99',
    },
    'v' => { # caron
        'A' => '01CD',
        'a' => '01CE',
        'C' => '010C',
        'c' => '010D',
        'D' => '010E',
        'd' => '010F',
        'E' => '011A',
        'e' => '011B',
        'G' => '01E6',
        'g' => '01E7',
        'H' => '021E',
        'h' => '021F',
        'I' => '01CF',
        'i' => '01D0',
        'K' => '01E8',
        'k' => '01E9',
        'L' => '013D',
        'l' => '013E',
        'N' => '0147',
        'n' => '0148',
        'O' => '01D1',
        'o' => '01D2',
        'R' => '0158',
        'r' => '0159',
        'S' => '0160',
        's' => '0161',
        'T' => '0164',
        't' => '0165',
        'U' => '01D3',
        'u' => '01D4',
        'Z' => '017D',
        'z' => '017E',
    },
    'H' => { # double acute
        'O' => '0150',
        'o' => '0151',
        'U' => '0170',
        'u' => '0171',
    },
    'ogonek' => {
        'A' => '0104',
        'a' => '0105',
        'E' => '0118',
        'e' => '0119',
        'I' => '012E',
        'i' => '012F',
        'U' => '0172',
        'u' => '0173',
        'O' => '01EA',
        'o' => '01EB',
    },
    'dotless' => {
        'i' => '0131', # 305
        'j' => '0237', # 567
    }
);

our %unicode_simple_character_map = (
            ' ' => '0020',
            '!' => '0021',
            '"' => '0022',
            '#' => '0023',
            '$' => '0024',
            '%' => '0025',
            '&' => '0026',
            "'" => '0027',
            '(' => '0028',
            ')' => '0029',
            '*' => '002A',
            '+' => '002B',
            ',' => '002C',
            '-' => '002D',
            '.' => '002E',
            '/' => '002F',
            ':' => '003A',
            ';' => '003B',
            '<' => '003C',
            '=' => '003D',
            '>' => '003E',
            '?' => '003F',
            '@' => '0040',
            '[' => '005B',
            '\\' => '005C',
            ']' => '005D',
            '^' => '005E',
            '_' => '005F',
            '`' => '0060',
            '{' => '007B',
            '|' => '007C',
            '}' => '007D',
            '~' => '007E',
);


# Also discussed on the texinfo list.
# taken from
#Latin extended additionnal
#http://www.alanwood.net/unicode/latin_extended_additional.html
#C1 Controls and Latin-1 Supplement
#http://www.alanwood.net/unicode/latin_1_supplement.html
#Latin Extended-A
#http://www.alanwood.net/unicode/latin_extended_a.html
#Latin Extended-B
#http://www.alanwood.net/unicode/latin_extended_b.html
#dotless i: 0131

#http://www.alanwood.net/unicode/arrows.html 21**
#http://www.alanwood.net/unicode/general_punctuation.html 20**
#http://www.alanwood.net/unicode/mathematical_operators.html 22**

# 'today' is not set here.
our %unicode_map = (
               # characters
               'atchar'            => '0040',
               'ampchar'           => '0026',
               'backslashchar'     => '005C',
               'comma'             => '002C',
               'hashchar'          => '0023',
               'lbracechar'        => '007B',
               'rbracechar'        => '007D',

               # symbols (9)
               'euro'              => '20AC',
               'exclamdown'        => '00A1',
               'geq'               => '2265',
               'leq'               => '2264',
               'ordf'              => '00AA',
               'ordm'              => '00BA',
               'pounds'            => '00A3',
               'questiondown'      => '00BF',
               'textdegree'        => '00B0',

               # quotes
               'guillemetleft'     => '00AB',
               'guillemetright'    => '00BB',
               'guillemotleft'     => '00AB',
               'guillemotright'    => '00BB',
               'guilsinglleft'     => '2039',
               'guilsinglright'    => '203A',
               'quotedblbase'      => '201E',
               'quotesinglbase'    => '201A',

               # letters
               'AA'                => '00C5',
               'aa'                => '00E5',
               'AE'                => '00C6',
               'ae'                => '00E6',
               'DH'                => '00D0',
               'dh'                => '00F0',
               'L'                 => '0141',
               'l'                 => '0142',
               'O'                 => '00D8',
               'o'                 => '00F8',
               'OE'                => '0152',
               'oe'                => '0153',
               'ss'                => '00DF',
               'TH'                => '00DE',
               'th'                => '00FE',
             );

# For commands where ASCII output is acceptable and may be wanted by the users
# as ASCII instead of encoded characters
our %extra_unicode_map = (
               # symbols (11 + 3)
               'arrow'             => '2192',
               'bullet'            => '2022',
               'copyright'         => '00A9',
               'dots'              => '2026',
               #'enddots'           => '',
               'equiv'             => '2261',
               'expansion'         => '21A6',
               #'LaTeX'
               'minus'             => '2212', # in mathematical operators
#               'minus'             => '002D', # in latin1
               'point'             => '22C6', # another candidate is 2605
                                              # corresponding to a bigger star
                                              # (and to \bigstar in LaTeX)
                                              # but less consistent with TeX
                                              # \star
               'print'             => '22A3',
               'registeredsymbol'  => '00AE',
               'result'            => '21D2',
               #'TeX'

               # quotes
               'quotedblleft'      => '201C',
               'quotedblright'     => '201D',
               'quoteleft'         => '2018',
               'quoteright'        => '2019',

               # other
               # this should only happen if the @clickstyle argument isn't a
               # command with braces and no argument.
               'click'             => '2192',
               #'error'             => '',
               #'tie'               => '',
#               'tie'               => '0020',
);

%unicode_map = (%unicode_map, %extra_unicode_map);

# set the %unicode_character_brace_no_arg_commands value to the character
# corresponding to the textual hex value in %unicode_map.
our %unicode_character_brace_no_arg_commands;
foreach my $command (keys(%unicode_map)) {
# FIXME Using charnames::vianame as in the following is the clean documented
# way to create an unicode character at runtime.  However, in tests of perl
# 5.10.1 (on solaris), if charnames::vianame is used for @aa{} '00E5', uc()
# on the resulting character does not leads to \x{00C5} (@AA{}) (when
# formatting @sc{@aa{}} or @var{@aa{}} in plaintext).
#  $unicode_character_brace_no_arg_commands{$command}
#    = charnames::vianame("U+$unicode_map{$command}");
  my $char_nr = hex($unicode_map{$command});
  if ($char_nr > 126 and $char_nr < 255) {
    # this is very strange, indeed.  The reason lies certainly in the
    # magic backward compatibility support in Perl for 8bit encodings.
    $unicode_character_brace_no_arg_commands{$command} =
       Encode::decode("iso-8859-1", chr($char_nr));
  } else {
    $unicode_character_brace_no_arg_commands{$command} = chr($char_nr);
  }
}

our %unicode_entities;
# set entities corresponding to unicode_map
foreach my $command (keys(%unicode_map)) {
  $unicode_entities{$command}
   = '&#'.hex($unicode_map{$command}).';';
}


our %transliterate_map = (
  # Text::Unicode starting from version 1.25_01 maps C1 controls in the
  # 0080 to 009F range to Windows-1252 characters.  We still consider
  # the Unicode standard to rule and keep on transliterating to empty
  # strings
               '0080'  => '',
               '0081'  => '',
               '0082'  => '',
               '0083'  => '',
               '0084'  => '',
               '0085'  => '',
               '0086'  => '',
               '0087'  => '',
               '0088'  => '',
               '0089'  => '',
               '008A'  => '',
               '008B'  => '',
               '008C'  => '',
               '008D'  => '',
               '008E'  => '',
               '008F'  => '',
               '0090'  => '',
               '0091'  => '',
               '0092'  => '',
               '0093'  => '',
               '0094'  => '',
               '0095'  => '',
               '0096'  => '',
               '0097'  => '',
               '0098'  => '',
               '0099'  => '',
               '009A'  => '',
               '009B'  => '',
               '009C'  => '',
               '009D'  => '',
               '009E'  => '',
               '009F'  => '',
               # explicit transliterations
               '00A3' => 'GBP', # iconv @pounds
               '00A9' => '(C)', # iconv
               '00AA' => 'a', # ordf iconv and unidecode
               '00AE' => '(R)', # iconv
               '00BA' => 'o', # ordm iconv and unidecode
               #'00B0' => '?', #iconv @textdegree, probably no translit
               #'00BF' => '?', #iconv @questiondown
               '00C5' => 'A',
               '00E5' => 'a',
               '00D8' => 'O',
               '00F8' => 'o',
               '00E6' => 'ae',
               '0153' => 'oe',
               '00C6' => 'AE',
               '0152' => 'OE',
               '00DF' => 'ss',
               '0141' => 'L',
               '0142' => 'l',
               '00D0' => 'D',
               '00F0' => 'd',
               '00DE' => 'TH',
               '00FE' => 'th',
               '0415'  => 'E',
               '0435'  => 'e',
               '0426'  => 'C',
               '042A'  => 'W',
               '044A'  => 'w',
               '042C'  => 'X',
               '044C'  => 'x',
               '042E'  => 'yu',
               '042F'  => 'YA',
               '044F'  => 'ya',
               '0433'  => 'g',
               '0446'  => 'c',
               '04D7'  => 'IO',
               '00DD'  => 'Y', # unidecode gets this wrong ?
               '0237'  => 'j', # unknown dotless j for unidecode, returns [?]
               '20AC'  => 'EUR', # iconv and unidecode
               # following based on iconv
               '2022'  => 'o', # bullet
               '2026'  => '...', # ellipsis
               #'21A6'  => '?', # expansion, probably no translit
               '2192'  => '->', # arrow
               '21D2'  => '=>', # result
               '2212'  => '-',
               #'2261'  => '?', # equiv, probably no translit
               '2264'  => '<=', # leq
               '2265'  => '>=', # geq
               #'22A3'  => '?', # print, probably no translit
               #'22C6'  => '?', # point, probably no translit

               # following appears in tests, this is required to have
               # the same output with and without unidecode
               '4E2D'  => 'Zhong',
               '6587'  => 'Wen',
               '793A'  => 'Shi',
               '4F8B'  => 'Li',
               '7B2C'  => 'Di',
               '7AE0'  => 'Zhang',
               '53E6'  => 'Ling',
               '4E2A'  => 'Ge',
               # in http://www.cantonese.sheik.co.uk/dictionary/characters/7/
               # unidecode certainly gets it wrong
               '4E00'  => 'Yi',
               'FF08' => '(',
               'FF09' => ')',
               'FF0C' => ',',
               '5B66' => 'Xue',
               '7FD2' => 'Xi',
               '30DE' => 'ma',
               '30CB' => 'ni',
               '30E5' => 'yu',
               '30A2' => 'a',
               '30EB' => 'ru',
          );

our %no_transliterate_map;
foreach my $symbol(keys(%unicode_map)) {
  if (!exists($transliterate_map{$symbol})) {
    $no_transliterate_map{$unicode_map{$symbol}} = 1;
  }
}

our %transliterate_accent_map;
foreach my $command (keys(%unicode_accented_letters)) {
  foreach my $letter(keys (%{$unicode_accented_letters{$command}})) {
    $transliterate_accent_map{$unicode_accented_letters{$command}->{$letter}} = $letter
      unless (exists($transliterate_map{$unicode_accented_letters{$command}->{$letter}}));
  }
}

# Note that the values are not actually used anywhere, they are there
# to mark unicode codepoints that exist in the encoding.  It is important
# to get them right, though, as the values are shown when debugging.
# Also note that values below A0, which correspond to the ascii range
# are not in the values and therefore should be handled differently by the
# codes using the hash.
# used in code generating C data structure.
our %unicode_to_eight_bit = (
   'iso-8859-1' => {
      '00A0' => 'A0',
      '00A1' => 'A1',
      '00A2' => 'A2',
      '00A3' => 'A3',
      '00A4' => 'A4',
      '00A5' => 'A5',
      '00A6' => 'A6',
      '00A7' => 'A7',
      '00A8' => 'A8',
      '00A9' => 'A9',
      '00AA' => 'AA',
      '00AB' => 'AB',
      '00AC' => 'AC',
      '00AD' => 'AD',
      '00AE' => 'AE',
      '00AF' => 'AF',
      '00B0' => 'B0',
      '00B1' => 'B1',
      '00B2' => 'B2',
      '00B3' => 'B3',
      '00B4' => 'B4',
      '00B5' => 'B5',
      '00B6' => 'B6',
      '00B7' => 'B7',
      '00B8' => 'B8',
      '00B9' => 'B9',
      '00BA' => 'BA',
      '00BB' => 'BB',
      '00BC' => 'BC',
      '00BD' => 'BD',
      '00BE' => 'BE',
      '00BF' => 'BF',
      '00C0' => 'C0',
      '00C1' => 'C1',
      '00C2' => 'C2',
      '00C3' => 'C3',
      '00C4' => 'C4',
      '00C5' => 'C5',
      '00C6' => 'C6',
      '00C7' => 'C7',
      '00C7' => 'C7',
      '00C8' => 'C8',
      '00C9' => 'C9',
      '00CA' => 'CA',
      '00CB' => 'CB',
      '00CC' => 'CC',
      '00CD' => 'CD',
      '00CE' => 'CE',
      '00CF' => 'CF',
      '00D0' => 'D0',
      '00D1' => 'D1',
      '00D2' => 'D2',
      '00D3' => 'D3',
      '00D4' => 'D4',
      '00D5' => 'D5',
      '00D6' => 'D6',
      '00D7' => 'D7',
      '00D8' => 'D8',
      '00D9' => 'D9',
      '00DA' => 'DA',
      '00DB' => 'DB',
      '00DC' => 'DC',
      '00DD' => 'DD',
      '00DE' => 'DE',
      '00DF' => 'DF',
      '00E0' => 'E0',
      '00E1' => 'E1',
      '00E2' => 'E2',
      '00E3' => 'E3',
      '00E4' => 'E4',
      '00E5' => 'E5',
      '00E6' => 'E6',
      '00E7' => 'E7',
      '00E8' => 'E8',
      '00E9' => 'E9',
      '00EA' => 'EA',
      '00EB' => 'EB',
      '00EC' => 'EC',
      '00ED' => 'ED',
      '00EE' => 'EE',
      '00EF' => 'EF',
      '00F0' => 'F0',
      '00F1' => 'F1',
      '00F2' => 'F2',
      '00F3' => 'F3',
      '00F4' => 'F4',
      '00F5' => 'F5',
      '00F6' => 'F6',
      '00F7' => 'F7',
      '00F8' => 'F8',
      '00F9' => 'F9',
      '00FA' => 'FA',
      '00FB' => 'FB',
      '00FC' => 'FC',
      '00FD' => 'FD',
      '00FE' => 'FE',
      '00FF' => 'FF',
   },
   'iso-8859-15' => {
      '00A0' => 'A0',
      '00A1' => 'A1',
      '00A2' => 'A2',
      '00A3' => 'A3',
      '20AC' => 'A4',
      '00A5' => 'A5',
      '0160' => 'A6',
      '00A7' => 'A7',
      '0161' => 'A8',
      '00A9' => 'A9',
      '00AA' => 'AA',
      '00AB' => 'AB',
      '00AC' => 'AC',
      '00AD' => 'AD',
      '00AE' => 'AE',
      '00AF' => 'AF',
      '00B0' => 'B0',
      '00B1' => 'B1',
      '00B2' => 'B2',
      '00B3' => 'B3',
      '017D' => 'B4',
      '00B5' => 'B5',
      '00B6' => 'B6',
      '00B7' => 'B7',
      '017E' => 'B8',
      '00B9' => 'B9',
      '00BA' => 'BA',
      '00BB' => 'BB',
      '0152' => 'BC',
      '0153' => 'BD',
      '0178' => 'BE',
      '00BF' => 'BF',
      '00C0' => 'C0',
      '00C1' => 'C1',
      '00C2' => 'C2',
      '00C3' => 'C3',
      '00C4' => 'C4',
      '00C5' => 'C5',
      '00C6' => 'C6',
      '00C7' => 'C7',
      '00C8' => 'C8',
      '00C9' => 'C9',
      '00CA' => 'CA',
      '00CB' => 'CB',
      '00CC' => 'CC',
      '00CD' => 'CD',
      '00CE' => 'CE',
      '00CF' => 'CF',
      '00D0' => 'D0',
      '00D1' => 'D1',
      '00D2' => 'D2',
      '00D3' => 'D3',
      '00D4' => 'D4',
      '00D5' => 'D5',
      '00D6' => 'D6',
      '00D7' => 'D7',
      '00D8' => 'D8',
      '00D9' => 'D9',
      '00DA' => 'DA',
      '00DB' => 'DB',
      '00DC' => 'DC',
      '00DD' => 'DD',
      '00DE' => 'DE',
      '00DF' => 'DF',
      '00E0' => 'E0',
      '00E1' => 'E1',
      '00E2' => 'E2',
      '00E3' => 'E3',
      '00E4' => 'E4',
      '00E5' => 'E5',
      '00E6' => 'E6',
      '00E7' => 'E7',
      '00E8' => 'E8',
      '00E9' => 'E9',
      '00EA' => 'EA',
      '00EB' => 'EB',
      '00EC' => 'EC',
      '00ED' => 'ED',
      '00EE' => 'EE',
      '00EF' => 'EF',
      '00F0' => 'F0',
      '00F1' => 'F1',
      '00F2' => 'F2',
      '00F3' => 'F3',
      '00F4' => 'F4',
      '00F5' => 'F5',
      '00F6' => 'F6',
      '00F7' => 'F7',
      '00F8' => 'F8',
      '00F9' => 'F9',
      '00FA' => 'FA',
      '00FB' => 'FB',
      '00FC' => 'FC',
      '00FD' => 'FD',
      '00FE' => 'FE',
      '00FF' => 'FF',
   },
   'iso-8859-2' => {
      '00A0' => 'A0',
      '0104' => 'A1',
      '02D8' => 'A2',
      '0141' => 'A3',
      '00A4' => 'A4',
      '013D' => 'A5',
      '015A' => 'A6',
      '00A7' => 'A7',
      '00A8' => 'A8',
      '015E' => 'AA',
      '0164' => 'AB',
      '0179' => 'AC',
      '00AD' => 'AD',
      '017D' => 'AE',
      '017B' => 'AF',
      '00B0' => 'B0',
      '0105' => 'B1',
      '02DB' => 'B2',
      '0142' => 'B3',
      '00B4' => 'B4',
      '013E' => 'B5',
      '015B' => 'B6',
      '02C7' => 'B7',
      '00B8' => 'B8',
      '0161' => 'B9',
      '015F' => 'BA',
      '0165' => 'BB',
      '017A' => 'BC',
      '02DD' => 'BD',
      '017E' => 'BE',
      '017C' => 'BF',
      '0154' => 'C0',
      '00C1' => 'C1',
      '00C2' => 'C2',
      '0102' => 'C3',
      '00C4' => 'C4',
      '0139' => 'C5',
      '0106' => 'C6',
      '00C7' => 'C7',
      '010C' => 'C8',
      '00C9' => 'C9',
      '0118' => 'CA',
      '00CB' => 'CB',
      '011A' => 'CC',
      '00CD' => 'CD',
      '00CE' => 'CE',
      '010E' => 'CF',
      '0110' => 'D0',
      '0143' => 'D1',
      '0147' => 'D2',
      '00D3' => 'D3',
      '00D4' => 'D4',
      '0150' => 'D5',
      '00D6' => 'D6',
      '00D7' => 'D7',
      '0158' => 'D8',
      '016E' => 'D9',
      '00DA' => 'DA',
      '0170' => 'DB',
      '00DC' => 'DC',
      '00DD' => 'DD',
      '0162' => 'DE',
      '00DF' => 'DF',
      '0155' => 'E0',
      '00E1' => 'E1',
      '00E2' => 'E2',
      '0103' => 'E3',
      '00E4' => 'E4',
      '013A' => 'E5',
      '0107' => 'E6',
      '00E7' => 'E7',
      '010D' => 'E8',
      '00E9' => 'E9',
      '0119' => 'EA',
      '00EB' => 'EB',
      '011B' => 'EC',
      '00ED' => 'ED',
      '00EE' => 'EE',
      '010F' => 'EF',
      '0111' => 'F0',
      '0144' => 'F1',
      '0148' => 'F2',
      '00F3' => 'F3',
      '00F4' => 'F4',
      '0151' => 'F5',
      '00F6' => 'F6',
      '00F7' => 'F7',
      '0159' => 'F8',
      '016F' => 'F9',
      '00FA' => 'FA',
      '0171' => 'FB',
      '00FC' => 'FC',
      '00FD' => 'FD',
      '0163' => 'FE',
      '02D9' => 'FF',
   },
   'koi8-r' => {
      '0415' => 'A3',
      '04D7' => 'B3',
      '042E' => 'C0',
      '0430' => 'C1',
      '0431' => 'C2',
      '0446' => 'C3',
      '0434' => 'C4',
      '0435' => 'C5',
      '0444' => 'C6',
      '0433' => 'C7',
      '0445' => 'C8',
      '0438' => 'C9',
      '0439' => 'CA',
      '043A' => 'CB',
      '043B' => 'CC',
      '043C' => 'CD',
      '043D' => 'CE',
      '043E' => 'CF',
      '043F' => 'D0',
      '044F' => 'D1',
      '0440' => 'D2',
      '0441' => 'D3',
      '0442' => 'D4',
      '0443' => 'D5',
      '0436' => 'D6',
      '0432' => 'D7',
      '044C' => 'D8',
      '044B' => 'D9',
      '0437' => 'DA',
      '0448' => 'DB',
      '044D' => 'DC',
      '0449' => 'DD',
      '0447' => 'DE',
      '044A' => 'DF',
      '042D' => 'E0',
      '0410' => 'E1',
      '0411' => 'E2',
      '0426' => 'E3',
      '0414' => 'E4',
      '0415' => 'E5',
      '0424' => 'E6',
      '0413' => 'E7',
      '0425' => 'E8',
      '0418' => 'E9',
      '0419' => 'EA',
      '041A' => 'EB',
      '041B' => 'EC',
      '041C' => 'ED',
      '041D' => 'EE',
      '041E' => 'EF',
      '041F' => 'F0',
      '042F' => 'F1',
      '0420' => 'F2',
      '0421' => 'F3',
      '0422' => 'F4',
      '0423' => 'F5',
      '0416' => 'F6',
      '0412' => 'F7',
      '042C' => 'F8',
      '042B' => 'F9',
      '0417' => 'FA',
      '0428' => 'FB',
      '042D' => 'FC',
      '0429' => 'FD',
      '0427' => 'FE',
      '042A' => 'FF',
   },
   # additional to koi8-r, replacing box drawing characters not used in Texinfo
   'koi8-u' => {
      '0454' => 'A4',
      '0404' => 'B4',
      '0456' => 'A6',
      '0406' => 'B6',
      '0457' => 'A7',
      '0407' => 'B7',
      '0491' => 'AD',
      '0490' => 'BD',
   }
);

foreach my $unicode_point (keys(%{$unicode_to_eight_bit{'koi8-r'}})) {
  $unicode_to_eight_bit{'koi8-u'}->{$unicode_point}
    = $unicode_to_eight_bit{'koi8-r'}->{$unicode_point};
}

# currently unused
my %makeinfo_transliterate_map = (
  '0416' => 'ZH',
  '0447' => 'ch',
  '00EB' => 'e',
  '0414' => 'D',
  '0159' => 'r',
  '00E6' => 'ae',
  '042B' => 'Y',
  '00FA' => 'u',
  '043B' => 'l',
  '00DE' => 'TH',
  '00D9' => 'U',
  '00C4' => 'A',
  '0148' => 'n',
  '00F6' => 'o',
  '0434' => 'd',
  '041E' => 'O',
  '041B' => 'L',
  '044B' => 'y',
  '0107' => 'c',
  '0415' => 'E',
  '00C1' => 'A',
  '00D3' => 'O',
  '00DB' => 'U',
  '016E' => 'U',
  '013A' => 'l',
  '017B' => 'Z',
  '00F1' => 'n',
  '0428' => 'SH',
  '0153' => 'oe',
  '00F4' => 'o',
  '0144' => 'n',
  '0404' => 'IE',
  '0427' => 'CH',
  '0162' => 'T',
  '017A' => 'z',
  '0448' => 'sh',
  '0436' => 'zh',
  '00F9' => 'u',
  '0406' => 'I',
  '0103' => 'a',
  '0422' => 'T',
  '0160' => 'S',
  '0165' => 't',
  '017E' => 'z',
  '00F0' => 'd',
  '043E' => 'o',
  '043D' => 'n',
  '013E' => 'l',
  '0412' => 'V',
  '0111' => 'd',
  '0155' => 's',
  '017C' => 'z',
  '00CE' => 'I',
  '042D' => 'E',
  '00C8' => 'E',
  '00F8' => 'oe',
  '00F2' => 'o',
  '00FF' => 'y',
  '0420' => 'R',
  '0119' => 'e',
  '00D2' => 'O',
  '043C' => 'm',
  '00D0' => 'DH',
  '0179' => 'Z',
  '0110' => 'D',
  '043F' => 'p',
  '0170' => 'U',
  '011A' => 'E',
  '010C' => 'C',
  '015A' => 'S',
  '0433' => 'g',
  '00E1' => 'a',
  '010D' => 'c',
  '00CC' => 'I',
  '016F' => 'u',
  '0457' => 'yi',
  '00C2' => 'A',
  '0438' => 'i',
  '00E3' => 'a',
  '0435' => 'e',
  '0440' => 'r',
  '042A' => 'W',
  '0431' => 'b',
  '00EE' => 'i',
  '0150' => 'O',
  '00E8' => 'e',
  '0418' => 'I',
  '00CF' => 'I',
  '015F' => 's',
  '0142' => 'l',
  '0147' => 'N',
  '00DF' => 'ss',
  '00E5' => 'aa',
  '00C3' => 'A',
  '0106' => 'C',
  '0141' => 'L',
  '0164' => 'T',
  '017D' => 'Z',
  '00EC' => 'i',
  '041C' => 'M',
  '00C9' => 'E',
  '00E0' => 'a',
  '043A' => 'k',
  '00F5' => 'o',
  '042C' => 'X',
  '0449' => 'shch',
  '0444' => 'f',
  '0139' => 'L',
  '0158' => 'R',
  '00F3' => 'o',
  '00FB' => 'u',
  '0424' => 'F',
  '0446' => 'c',
  '0423' => 'U',
  '0442' => 't',
  '00FD' => 'y',
  '0102' => 'A',
  '0104' => 'A',
  '00CB' => 'E',
  '0426' => 'C',
  '00CD' => 'I',
  '0437' => 'z',
  '0178' => 'y',
  '00D4' => 'O',
  '044D' => 'e',
  '0432' => 'v',
  '013D' => 'L',
  '0163' => 't',
  '0456' => 'i',
  '011B' => 'e',
  '044F' => 'ya',
  '0429' => 'SHCH',
  '0411' => 'B',
  '044A' => 'w',
  '00C6' => 'AE',
  '041D' => 'N',
  '00DA' => 'U',
  '00C0' => 'A',
  '0152' => 'OE',
  '00DD' => 'Y',
  '0154' => 'R',
  '00E9' => 'e',
  '00D5' => 'O',
  '041F' => 'P',
  '0161' => 's',
  '0430' => 'a',
  '0445' => 'h',
  '00E2' => 'a',
  '00D6' => 'O',
  '0407' => 'YI',
  '00CA' => 'E',
  '0439' => 'i',
  '0171' => 'u',
  '00DC' => 'U',
  '042F' => 'YA',
  '0425' => 'H',
  '00FE' => 'th',
  '00D1' => 'N',
  '044C' => 'x',
  '010F' => 'd',
  '0410' => 'A',
  '0443' => 'u',
  '00EF' => 'i',
  '0105' => 'a',
  '00EA' => 'e',
  '00E4' => 'a',
  '015E' => 'S',
  '0417' => 'Z',
  '00ED' => 'i',
  '00FC' => 'u',
  '04D7' => 'IO',
  '00D8' => 'OE',
  '0419' => 'I',
  '0421' => 'S',
  '0143' => 'N',
  '010E' => 'D',
  '0413' => 'G',
  '015B' => 's',
  '0151' => 'o',
  '00E7' => 'c',
  '00C5' => 'AA',
  '0441' => 's',
  '0118' => 'E',
  '00C7' => 'C',
  '041A' => 'K',
  '0454' => 'ie',
  '042E' => 'yu',
);


sub unicode_accent($$)
{
  my $text = shift;
  my $command = shift;

  my $accent = $command->{'cmdname'};

  my $result;

  # special handling of @dotless{i}.
  # \x{0131}\x{0308} for @dotless{i} @" doesn't lead to NFC 00ef.
  # so it is set to a real dotless i only if not in an accent command.
  # Do the same for dotless j, even though we have no clear idea on
  # what is going on for that character.
  if ($accent eq 'dotless') {
    if ($unicode_accented_letters{$accent}->{$text}
        and (!$command->{'parent'}
             or !$command->{'parent'}->{'parent'}
             or !$command->{'parent'}->{'parent'}->{'cmdname'}
             or !$unicode_diacritics{$command->{'parent'}
                                        ->{'parent'}->{'cmdname'}})) {
      return chr(hex($unicode_accented_letters{$accent}->{$text}));
    } else {
      return $text;
    }
  }

  if (defined($unicode_diacritics{$accent})) {
    my $diacritic = chr(hex($unicode_diacritics{$accent}));
    if ($accent ne 'tieaccent') {
      # FIXME with a malformed string, there can be an infinite loop
      # in Unicode::Normalize::NFC.
      return Unicode::Normalize::NFC($text . $diacritic);
    } else {
      # tieaccent diacritic is naturally and correctly composed
      # between two characters
      my $remaining_text = $text;
      # \p{L} matches a single code point in the category "letter".
      if ($remaining_text =~ s/^([\p{L}\d])([\p{L}\d])(.*)$/$3/) {
        return Unicode::Normalize::NFC($1.$diacritic.$2 . $remaining_text);
      } else {
        return Unicode::Normalize::NFC($text . $diacritic);
      }
    }
  }
  # There are diacritics for every accent command except for dotless and
  # dotless is handled especially, so we should never end up here.
  return undef;
}

sub unicode_text {
  my $text = shift;
  my $in_code = shift;

  if (!$in_code) {
    $text =~ s/---/\x{2014}/g;
    $text =~ s/--/\x{2013}/g;
    $text =~ s/``/\x{201C}/g;
    $text =~ s/''/\x{201D}/g;
    $text =~ s/'/\x{2019}/g;
    $text =~ s/`/\x{2018}/g;
  }
  return $text;
}

# return the hexadecimal 8 bit string, if it exists, and the unicode codepoint
sub _eight_bit_and_unicode_point($$)
{
  my $char = shift;
  my $encoding = shift;

  my ($eight_bit, $codepoint);
  if (ord($char) < 127) {
    # 7bit ascii characters (excluding 127, \x{7F}, DEL), the same in every
    # 8bit encodings
    $eight_bit = uc(sprintf("%02x",ord($char)));
    $codepoint = uc(sprintf("%04x",ord($char)));
  } elsif (ord($char) <= hex(0xFFFF)) {
    $codepoint = uc(sprintf("%04x",ord($char)));
    if (exists($unicode_to_eight_bit{$encoding}->{$codepoint})) {
     $eight_bit = $unicode_to_eight_bit{$encoding}->{$codepoint};
    }
  }
  return ($eight_bit, $codepoint);
}

# format a stack of accents as unicode
sub _format_unicode_accents_stack($$$$;$)
{
  my $converter = shift;
  my $inner_text = shift;
  my $stack = shift;
  my $format_accent = shift;
  my $set_case = shift;

  my $result = $inner_text;

  while (@$stack) {
    my $formatted_result = unicode_accent($result, $stack->[-1]);
    last if (!defined($formatted_result));

    $result = $formatted_result;
    pop @$stack;
  }
  if ($set_case) {
    if ($set_case > 0) {
      $result = uc($result);
    } else {
      $result = lc($result);
    }
  }
  while (@$stack) {
    my $accent_command = pop @$stack;
    $result = &$format_accent($converter, $result, $accent_command, $set_case);
  }
  return $result;
}

sub _format_eight_bit_accents_stack($$$$$;$)
{
  my $converter = shift;
  my $text = shift;
  my $stack = shift;
  my $encoding = shift;
  my $convert_accent = shift;
  my $set_case = shift;

  my $result = $text;

  my $debug;
  #$debug = 1;

  if ($debug) {
    print STDERR "STACK: ".join('|', map {$_->{'cmdname'}} @$stack)."\n";
  }

  # accents are formatted and the intermediate results are kept, such
  # that we can return the maximum of multiaccented letters that can be
  # rendered with a given eight bit formatting.  undef is stored when
  # there is no corresponding unicode anymore.
  my $unicode_formatted = $text;
  my @results_stack = ([$unicode_formatted, undef]);

  while (@$stack) {
    if (defined($unicode_formatted)) {
      $unicode_formatted
         = unicode_accent($unicode_formatted, $stack->[-1]);
      if (defined($unicode_formatted) and $set_case) {
        if ($set_case > 0) {
          $unicode_formatted = uc($unicode_formatted);
        } else {
          $unicode_formatted = lc($unicode_formatted);
        }
      }
    }
    push @results_stack, [$unicode_formatted, $stack->[-1]];
    pop @$stack;
  }

  if ($debug) {
    print STDERR "PARTIAL_RESULTS_STACK:\n";
    foreach my $partial_result (@results_stack) {
      my $command = 'TEXT';
      $command = $partial_result->[1]->{'cmdname'} if ($partial_result->[1]);
      if (defined($partial_result->[0])) {
        print STDERR "   -> ".Encode::encode('utf-8', $partial_result->[0])
                            ."|$command\n";
      } else {
        print STDERR "   -> NO accented character |$command\n";
      }
    }
  }

  # At this point we have the unicode character results for the accent
  # commands stack, with all the intermediate results.
  # For each one we'll check if it is possible to encode it in the
  # current eight bit output encoding table and, if so set the result
  # to the character.

  my $prev_eight_bit = '';

  while (@results_stack) {
    my $char = $results_stack[0]->[0];
    last if (!defined($char));

    my ($new_eight_bit, $codepoint)
      = _eight_bit_and_unicode_point($char, $encoding);
    if ($debug) {
      my $command = 'TEXT';
      $command = $results_stack[0]->[1]->{'cmdname'}
        if ($results_stack[0]->[1]);
      print STDERR "" . Encode::encode('utf-8', $char) . " ($command) "
        . "codepoint: $codepoint "
        ."8bit: ". (defined($new_eight_bit) ? $new_eight_bit : 'UNDEF')
        . " prev: $prev_eight_bit\n";
    }

    # no corresponding eight bit character found for a composed character
    last if (!$new_eight_bit);

    # in that case, the new eight bit character is the same than the one
    # found with one less character (and it isn't a @dotless{i}). It may
    # hapen in 2 case, both meaning that there is no corresponding 8bit char:
    #
    # -> there are 2 characters in accent. This could happen, for example
    #    if an accent that cannot be rendered is found and it leads to
    #    appending or prepending a character. For example this happens for
    #    @={@,{@~{n}}}, where @,{@~{n}} is expanded to a 2 character:
    #    n with a tilde, followed by a ,
    #    In that case, the additional diacritic is appended, which
    #    means that it is composed with the , and leaves n with a tilde
    #    untouched.
    # -> the diacritic is appended but the normal form doesn't lead
    #    to a composed character, such that the first character
    #    of the string is unchanged. This, for example, happens for
    #    @ubaraccent{a} since there is no composed accent with a and an
    #    underbar.
    last if ($new_eight_bit eq $prev_eight_bit
             and !($results_stack[0]->[1]->{'cmdname'} eq 'dotless'
                   and $char eq 'i'));
    $result = $results_stack[0]->[0];
    $prev_eight_bit = $new_eight_bit;
    shift @results_stack;
  }

  # handle the remaining accents, that have not been converted to 8bit
  # compatible unicode
  shift @results_stack if (scalar(@results_stack)
                           and !defined($results_stack[0]->[1]));
  while (@results_stack) {
    $result = &$convert_accent($converter, $result,
                               $results_stack[0]->[1],
                               $set_case);
    shift @results_stack;
  }

  # An important remark is that the final conversion to 8bit is left to
  # Perl.
  return $result;
}

sub encoded_accents($$$$$;$)
{
  my $converter = shift;
  my $text = shift;
  my $stack = shift;
  my $encoding = shift;
  my $format_accent = shift;
  my $set_case = shift;

  if ($encoding) {
    # in case an encoding is directly specified with -c OUTPUT_ENCODING_NAME
    # in upper case to match with the encodings in Texinfo input, we convert
    # to lower case to match the encoding names used here.  In the code
    # encoding names are lower cased early.
    $encoding = lc($encoding);
    if ($encoding eq 'utf-8') {
      return _format_unicode_accents_stack($converter, $text, $stack,
                                            $format_accent, $set_case);
    } elsif ($unicode_to_eight_bit{$encoding}) {
      return _format_eight_bit_accents_stack($converter, $text, $stack, $encoding,
                               $format_accent, $set_case);
    }
  }
  return undef;
}

# $UNICODE_POINT is a string describing an hexadecimal number with
# letters in upper case.
sub unicode_point_decoded_in_encoding($$) {
  my $encoding = shift;
  my $unicode_point = shift;

  if ($encoding) {
    # in case an encoding is directly specified with -c OUTPUT_ENCODING_NAME
    # in upper case to match with the encodings in Texinfo input, we convert
    # to lower case to match the encoding names used here.  In the code
    # encoding names are lower cased early.
    $encoding = lc($encoding);
  }

  return 1 if ((!defined($encoding) or $encoding eq 'utf-8')
                    or ($unicode_to_eight_bit{$encoding}
                        and ($unicode_to_eight_bit{$encoding}->{$unicode_point}
                             # excludes 127 \x{7F} DEL
                             or hex($unicode_point) < 127)));
  return 0;
}

# returns the text for a command with brace and no arg
# if it is known that it is present for $encoding
sub brace_no_arg_command($$) {
  my $command = shift;
  my $encoding = shift;

  if ($unicode_character_brace_no_arg_commands{$command}
      and unicode_point_decoded_in_encoding($encoding, $unicode_map{$command})) {
    return $unicode_character_brace_no_arg_commands{$command};
  } else {
    return undef;
  }
}

# this function checks that it is possible to output
# actual UTF-8 binary bytes, by checking that chr(hex($arg)) is valid.
# Perl gives a warning and will not output UTF-8 for Unicode
# non-characters such as U+10FFFF.
#
# return 1 if the conversion is possible and can be attempted, 0 otherwise.
# the second argument triggers debugging output if the conversion failed.
sub check_unicode_point_conversion($;$)
{
  my $arg = shift;
  my $output_debug = shift;

  # The warning about non-characters is only given when the code
  # point is attempted to be output, not just manipulated.
  # http://stackoverflow.com/questions/5127725/how-could-i-catch-an-unicode-non-character-warning
  # In perl 5.36.0, Encoding and printing also do not give a warning, so
  # no warning for:
  #
  # my ($fh, $string);
  # open($fh, ">", \$string);
  # my $char = chr(hex("110000"));
  # print $fh Encode::encode("utf-8", $char);
  #
  # but there is a warning if going through an encoding layer as below.
  #
  # In perl 5.10.1 on solaris 11, but not on solaris 10, the warning all does
  # not catch the nonchar warning (this warning seems to be defined on
  # 5.13.10 or newer).  This may be a consequence of what is described in
  # http://stackoverflow.com/questions/5127725/how-could-i-catch-an-unicode-non-character-warning
  # as a compiler bug, but it is unclear.  This does not happen with the
  # lax conversion to utf8, but we prefer to use a strict conversion.
  #
  # To avoid outputting a warning, we do not even try to encode the string
  # in the 5.10.0 5.13.8 range.
  #
  # We still use an eval to catch $arg that are illegal for hex
  if ($] >= 5.010 and $] <= 5.013008) {
    eval {
      use warnings FATAL => qw(all);
      my $var;
      if (hex($arg) > 0x10FFFF) {
        $var = 1;
      }
    };
    if ($@) {
      warn "Unicode hex($arg) eval failed: $@\n" if ($output_debug);
      return 0;
    } elsif (hex($arg) > 0x10FFFF) {
      return 0;
    }
  }
  #
  # For the other cases, we have to try to output it within an eval.
  # Since opening /dev/null or a temporary file means
  # more system-dependent checks, use a string as our
  # filehandle.
  eval {
    use warnings FATAL => qw(all);
    my ($fh, $string);
    open($fh, ">", \$string) || die "open(U string eval) failed: $!";
    binmode($fh, ":encoding(utf-8)") || die "binmode(U string eval) failed: $!";
    print $fh chr(hex("$arg"));
  };
  if ($@) {
    warn "Unicode chr(hex($arg)) eval failed: $@\n" if ($output_debug);
    return 0;
  } elsif (hex($arg) > 0x10FFFF) {
    # The check above appears not to work in older versions of Perl,
    # so check the argument is not greater the maximum Unicode code
    # point.
    return 0;
  }
  return 1;
}

# string length size taking into account that east asian characters
# may take 2 spaces.
sub string_width($)
{
  my $string = shift;

  # Optimise for the common case where we can just return the length
  # of the string.  These regexes are faster than making the substitutions
  # below.
  # IsPrint without \p{Mark}.  Matches classes Letter, Number, Punct, Symbol,
  # and Space_Separator.
  if ($string =~ /^[\p{L}\p{N}\p{P}\p{S}\p{Zs}]*$/
      and $string !~ /[\p{InFullwidth}]/) {
    return length($string);
  }

  $string =~ s/\p{InFullwidth}/\x{02}/g;
  $string =~ s/[\p{L}\p{N}\p{P}\p{S}\p{Zs}]/\x{01}/g;
  $string =~ s/[^\x{01}\x{02}]/\x{00}/g;

  # This sums up the byte values of the bytes in $string, which now are
  # all either 0, 1 or 2.  This is faster.  The original, more readable
  # version is below.
  return unpack("U0%32A*", $string);

  if (! defined($string)) {
    cluck();
  }
  my $width = 0;
  foreach my $character(split '', $string) {
    if ($character =~ /\p{InFullwidth}/) {
      $width += 2;
    } elsif ($character =~ /[\p{L}\p{N}\p{P}\p{S}\p{Zs}]/) {
      $width += 1;
    } else {
      # zero width character: \pC (including controls), \pM, \p{Zl}, \p{Zp}
    }
  }
  return $width;
}

1;
__END__

=head1 NAME

Texinfo::Convert::Unicode - Representation as Unicode characters

=head1 SYNOPSIS

  use Texinfo::Convert::Unicode qw(unicode_accent encoded_accents
                                   unicode_text);
  use Texinfo::Convert::Text qw(convert_to_text);

  my ($contents_element, $stack)
      = Texinfo::Convert::Utils::find_innermost_accent_contents($accent);

  my $formatted_accents = encoded_accents ($converter,
                 convert_to_text($contents_element), $stack, $encoding,
                        \&Texinfo::Text::ascii_accent_fallback);

  my $accent_text = unicode_accent('e', $accent_command);

=head1 NOTES

The Texinfo Perl module main purpose is to be used in C<texi2any> to convert
Texinfo to other formats.  There is no promise of API stability.

=head1 DESCRIPTION

C<Texinfo::Convert::Unicode> provides methods dealing with Unicode
representation and conversion of Unicode code points, to be used in Texinfo
converters.

When an encoding supported in Texinfo is given as argument of a method of the
module, the accented letters or characters returned by the method should only
be represented by Unicode code points if it is known that Perl should manage
to convert the Unicode code points to encoded characters in the encoding
character set.  Note that the actual conversion is done by Perl, not by the
module.

=head1 METHODS

=over

=item $result = brace_no_arg_command($command_name, $encoding)
X<C<brace_no_arg_command>>

Return the Unicode representation of a command with brace and no argument
I<$command_name> (like C<@bullet{}>, C<@aa{}> or C<@guilsinglleft{}>),
or C<undef> if the Unicode representation cannot be converted to encoding
I<$encoding>.

=item $possible_conversion = check_unicode_point_conversion($arg, $output_debug)
X<C<check_unicode_point_conversion>>

Check that it is possible to output actual UTF-8 binary bytes
corresponding to the Unicode code point string I<$arg> (such as
C<201D>).  Perl gives a warning and will not output UTF-8 for
Unicode non-characters such as U+10FFFF.  If the optional
I<$output_debug> argument is set, a debugging output warning
is emitted if the test of the conversion failed.
Returns 1 if the conversion is possible and can be attempted,
0 otherwise.

=item $result = encoded_accents($converter, $text, $stack, $encoding, $format_accent, $set_case)
X<C<encoded_accents>>

I<$encoding> is the encoding the accented characters should be encoded to.  If
I<$encoding> not set, I<$result> is set to C<undef>.  Nested accents and
their content are passed with I<$text> and I<$stack>.  I<$text> is the text
appearing within nested accent commands.  I<$stack> is an array reference
holding the nested accents texinfo tree elements.  In general, I<$text> is
the formatted contents and I<$stack> the stack returned by
L<Texinfo::Convert::Utils::find_innermost_accent_contents|Texinfo::Convert::Utils/($contents_element,
\@accent_commands) = find_innermost_accent_contents($element)>.  The function
tries to convert as much as possible the accents to I<$encoding> starting from the
innermost accent.

I<$format_accent> is a function reference that is used to format the accent
commands if there is no encoded character available at some point of the
conversion of the I<$stack>.  I<$converter> is a converter object optionaly
used by I<$format_accent>.  It may be C<undef> if there is no need of
converter object in I<$format_accent>.

The I<$set_case> argument is optional.  If I<$set_case> is positive, the result
is upper-cased, while if it is negative, the result is lower-cased.

=item $width = string_width($string)
X<C<string_width>>

Return the string width, taking into account the fact that some characters
have a zero width (like composing accents) while some have a width of 2
(most chinese characters, for example).

=item $result = unicode_accent($text, $accent_command)
X<C<unicode_accent>>

I<$text> is the text appearing within an accent command.  I<$accent_command>
should be a Texinfo tree element corresponding to an accent command taking
an argument.  The function returns the Unicode representation of the accented
character.

=item $is_decoded = unicode_point_decoded_in_encoding($encoding, $unicode_point)
X<C<unicode_point_decoded_in_encoding>>

Return true if the I<$unicode_point> will be encoded in the encoding
I<$encoding>.  The I<$unicode_point> should be specified as a four letter
string describing an hexadecimal number with letters in upper case
(such as C<201D>).  Tables are used to determine if the I<$unicode_point>
will be encoded, when the encoding does not cover the whole Unicode range.

If the encoding is not supported in Texinfo, the result will always be false.

=item $result = unicode_text($text, $in_code)
X<C<unicode_text>>

Return I<$text> with dashes and quotes corresponding, for example to C<---> or
C<'>, represented as Unicode code points.  If I<$in_code> is set, the text is
considered to be in code style.

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
