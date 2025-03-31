# common code for code test in t/*
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

package Texinfo::Tests;

use 5.006;

use strict;

use File::Compare qw(compare); # standard since 5.004

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
compare_dirs_files
unlink_dir_files
prepare_format_directories
);

# not that subdirectories are not compared, so subdirectories generated
# by INFO_JS_DIR, if different, will not trigger an error in test, but
# will lead to different directories and files in diffs.
sub compare_dirs_files($$;$)
{
  my $dir1 = shift;
  my $dir2 = shift;
  my $ignore_files = shift;

  my %dir1_files;
  my %dir2_files;
  my @errors;
  my %ignored_files_hash;
  foreach my $ignored_file (@$ignore_files) {
    $ignored_files_hash{$ignored_file} = 1;
  }
  if (opendir(DIR1, $dir1)) {
    my @files = readdir (DIR1);
    foreach my $file (@files) {
      next if (! -r "$dir1/$file" or ! -f "$dir1/$file"
               or $ignored_files_hash{$file});
      $dir1_files{$file} = 1;
    }
    closedir (DIR1);
  } else {
    push @errors, "readdir $dir1: $!";
  }
  if (opendir(DIR2, $dir2)) {
    my @files = readdir (DIR2);
    foreach my $file (@files) {
      next if (! -r "$dir2/$file" or ! -f "$dir2/$file"
               or $ignored_files_hash{$file});
      $dir2_files{$file} = 1;
    }
    closedir (DIR2);
  } else {
    push @errors, "readdir $dir2: $!";
  }
  if (scalar(@errors)) {
    return \@errors;
  }
  foreach my $file (sort(keys(%dir1_files))) {
    if ($dir2_files{$file}) {
      my $status = compare("$dir1/$file", "$dir2/$file");
      if ($status) {
        push @errors, "$dir1/$file and $dir2/$file differ: $status";
      }
      delete $dir2_files{$file};
    } else {
      push @errors, "No $file in $dir2";
    }
  }
  foreach my $file (sort(keys(%dir2_files))) {
    push @errors, "No $file in $dir1"
  }
  if (scalar(@errors)) {
    return \@errors;
  } else {
    return undef;
  }
}

#my $errors = compare_dirs_files('a', 'b',['nnn']);
#if ($errors) {
#  foreach my $error (@$errors) {
#    warn $error."\n";
#  }
#}

sub unlink_dir_files($;$)
{
  my $dir = shift;
  my $ignore_files = shift;
  my %ignored_files_hash;
  foreach my $ignored_file (@$ignore_files) {
    $ignored_files_hash{$ignored_file} = 1;
  }
  if (opendir(DIR, $dir)) {
    my @files = readdir (DIR);
    foreach my $file (@files) {
      next if (! -f "$dir/$file"
               or $ignored_files_hash{$file});
      unlink "$dir/$file" or warn "Could not unlink $dir/$file: $!\n";
    }
    closedir (DIR);
  } else {
    warn "readdir $dir: $!";
  }
}

my $default_result_base = 't/results/';

sub create_group_directory($;$)
{
  my $test_group = shift;
  my $result_base = shift;

  $result_base = $default_result_base if (!defined($result_base));

  foreach my $dir ('t', $result_base,
                 File::Spec->catdir($result_base, $test_group)) {
    my $error;
    # to avoid a race conditon, first create the dir then test that it
    # exists
    mkdir $dir or $error = $!;
    if (! -d $dir) {
      die "mkdir $dir: $error\n";
    }
  }
}

sub prepare_format_directories($$$$;$)
{
  my $srcdir = shift;
  my $test_group = shift;
  my $test_name = shift;
  my $format_type = shift;
  my $result_base = shift;

  $result_base = $default_result_base if (!defined($result_base));

  my $base = File::Spec->catdir($result_base, $test_group, $test_name);

  my $test_out_dir = File::Spec->catdir($base, 'out_'.$format_type);
  my $reference_dir = File::Spec->catdir($srcdir, $base, 'res_'.$format_type);

  mkdir ($base)
    if (! -d $base);
  if (! -d $test_out_dir) {
    mkdir ($test_out_dir);
  } else {
    # remove any files from previous runs
    unlink glob ("$test_out_dir/*");
  }
  return ($test_out_dir, $reference_dir);
}

1;
