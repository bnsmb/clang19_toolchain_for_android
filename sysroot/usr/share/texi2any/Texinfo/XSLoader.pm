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

package Texinfo::XSLoader;

use 5.006;
use strict;
use warnings;

use DynaLoader;

#use version;

BEGIN {
  eval 'require Texinfo::ModulePath';
  if ($@ ne '') {
    # For configure test in TestXS.pm where Texinfo/ModulePath.pm may
    # not exist yet.
    $Texinfo::ModulePath::texinfo_uninstalled = 1;
    $Texinfo::ModulePath::tp_builddir = '';
  }
}

our $TEXINFO_XS;

our $VERSION = '7.2';

# used for comparison with XS_VERSION passed through configure and make.
# The github CI adds the date after a hyphen, turn the hyphen to a dot.
my $xs_version = $VERSION;
$xs_version =~ s/-/./g;
#my $xs_version = version->declare($VERSION)->numify;

sub XS_parser_enabled {
  return ((not defined($ENV{TEXINFO_XS})
           or $ENV{TEXINFO_XS} ne 'omit')
          and (not defined($ENV{TEXINFO_XS_PARSER})
               or $ENV{TEXINFO_XS_PARSER} eq '1'));
}

sub XS_structuring_enabled {
  return (XS_parser_enabled()
           and (not defined($ENV{TEXINFO_XS_STRUCTURE})
                or $ENV{TEXINFO_XS_STRUCTURE} ne '0'));
}

sub XS_convert_enabled {
  return (XS_structuring_enabled()
            and defined $ENV{TEXINFO_XS_CONVERT}
            and $ENV{TEXINFO_XS_CONVERT} eq '1');
}


our $disable_XS;

# For verbose information about what's being done
sub _debug($) {
  my $msg = shift;
  if ($TEXINFO_XS eq 'debug') {
    warn $msg . "\n";
  }
}

# For messages to say that XS module couldn't be loaded
sub _fatal($) {
  my $msg = shift;
  if ($TEXINFO_XS eq 'debug'
      or $TEXINFO_XS eq 'required'
      or $TEXINFO_XS eq 'warn') {
    warn $msg . "\n";
  }
}

# We look for the .la and .so files in @INC because this allows us to override
# which modules are used using -I flags to "perl".
sub _find_file($) {
  my $file = shift;
  for my $dir (@INC) {
    next if (ref($dir) ne '');
    _debug("checking $dir/$file");
    if (-f "$dir/$file") {
      _debug("found $dir/$file");
      return ($dir, "$dir/$file");
    }
  }
  return undef;
}

sub load_libtool_library {
  my ($module_name) = @_;

  my ($libtool_dir, $libtool_archive) = _find_file("$module_name.la");
  if (!$libtool_archive) {
    _fatal("$module_name: couldn't find Libtool archive file");
    return 0;
  }

  my $dlname = undef;

  my $fh;
  open $fh, $libtool_archive;
  if (!$fh) {
    _fatal("$module_name: couldn't open Libtool archive file");
    return 0;
  }

  # Look for the line in XS*.la giving the name of the loadable object.
  while (my $line = <$fh>) {
    if ($line =~ /^\s*dlname\s*=\s*'([^']+)'\s$/) {
      $dlname = $1;
      last;
    }
  }
  if (!defined($dlname) or $dlname eq '') {
    _fatal("$module_name: couldn't find name of shared object");
    return 0;
  }

  # Use unshift to place directories at start of search path.  This
  # way we avoid accidentally loading the wrong library, e.g. if someone
  # has some random /usr/lib/libtexinfo.so file.
  # The *.so file is under .libs in the build directory.
  # Consider that we are in the build directory if texinfo_uninstalled
  # is set, or if Texinfo::ModulePath has not been called, as is the
  # case when TestXS is called, as it is not called from a Perl script.
  if (not defined($Texinfo::ModulePath::texinfo_uninstalled)
      or $Texinfo::ModulePath::texinfo_uninstalled) {
    unshift @DynaLoader::dl_library_path, "$libtool_dir/.libs";
  }
  unshift @DynaLoader::dl_library_path, $libtool_dir;

  my @found_files = DynaLoader::dl_findfile($dlname);
  if (scalar(@found_files) == 0) {
    _fatal("$module_name: couldn't find $dlname");
    return 0;
  }
  my $dlpath = $found_files[0];

  #my $flags = dl_load_flags $module; # This is 0 in DynaLoader
  my $flags = 0;
  my $libref = DynaLoader::dl_load_file($dlpath, $flags);
  if (!defined($libref)) {
    my $message = DynaLoader::dl_error();
    _fatal("$module_name: couldn't load file $dlpath: $message");
    return 0;
  }
  _debug("$dlpath loaded");
  push @DynaLoader::dl_shared_objects, $dlpath; # record files loaded

  my @undefined_symbols = DynaLoader::dl_undef_symbols();
  if (scalar(@undefined_symbols) != 0) {
    _fatal("$module_name: still have undefined symbols after dl_load_file");
  }
  return $libref;
}

our $loaded_additional_libraries = {};

# Load module $MODULE, either from XS implementation in
# Libtool file $MODULE_NAME and Perl file $PERL_EXTRA_FILE,
# or non-XS implementation $FALLBACK_MODULE.
# The package loaded is returned or undef if there is no fallback and the
# XS package was not loaded.
sub init {
  my ($module,
     $fallback_module,
     $module_name,
     $perl_extra_file,
     $additional_libraries,
   ) = @_;

  # Possible values for TEXINFO_XS environment variable:
  #
  # TEXINFO_XS=omit         # don't try loading xs at all
  # TEXINFO_XS=default      # try xs, libtool, silent fallback
  # TEXINFO_XS=warn         # try xs, libtool warn on failure
  # TEXINFO_XS=required     # abort if not loadable, no fallback
  # TEXINFO_XS=debug        # voluminuous debugging
  #
  # Other values are treated at the moment as 'default'.

  $TEXINFO_XS = $ENV{'TEXINFO_XS'};
  if (!defined($TEXINFO_XS)) {
    $TEXINFO_XS = '';
  }

  if ($TEXINFO_XS eq 'omit') {
    # Don't try to use the XS module
    goto FALLBACK;
  }

  if ($disable_XS) {
    _fatal("use of XS modules was disabled when Texinfo was built");
    goto FALLBACK;
  }

  if (!$module_name) {
    goto FALLBACK;
  }

  if ($additional_libraries) {
    for my $additional_library_name (@{$additional_libraries}) {
      my $additional_library = 'lib' . $additional_library_name;
      if (!$loaded_additional_libraries->{$additional_library}) {
        my $ref = load_libtool_library($additional_library);
        # if the libraries are installed but .la were removed, in general
        # they will be found as there are RUNPATH or similar pointing
        # to the installation directory in the XS modules objects themselves,
        # so we do not fallback if the libraries are not found.
        if (!$ref and (not defined($Texinfo::ModulePath::texinfo_uninstalled)
                       or $Texinfo::ModulePath::texinfo_uninstalled)) {
          goto FALLBACK;
        } else {
          $loaded_additional_libraries->{$additional_library} = $ref;
        }
      }
    }
  }

  my $libref = load_libtool_library($module_name);
  if (!$libref) {
    goto FALLBACK;
  }

  my $bootname = "boot_$module";
  $bootname =~ s/:/_/g;
  _debug("looking for $bootname");
  my $symref = DynaLoader::dl_find_symbol($libref, $bootname);
  if (!defined($symref)) {
    _fatal("$module_name: couldn't find $bootname symbol");
    goto FALLBACK;
  }
  _debug("trying to call $bootname...");
  my $boot_fn = DynaLoader::dl_install_xsub("${module}::bootstrap",
                                                  $symref); #, $dlname);

  if (!defined($boot_fn)) {
    _fatal("$module_name: couldn't bootstrap");
    goto FALLBACK;
  }
  _debug("  ...succeeded");

  # This is the module bootstrap function, which causes all the other
  # functions (XSUB's) provided by the module to become available to
  # be called from Perl code, after a check that the version argument
  # matches the XS object XS_VERSION value.  In our case, XS_VERSION
  # is set based on tp/Texinfo/XS/configure.ac AC_INIT version passed
  # through Makefile.am.  The tp/Texinfo/XS/configure.ac AC_INIT version
  # and thePerl modules VERSION should be synchronized with the top-level
  # configure.ac version.  The check therefore ensures that the XS objects
  # and the Perl module come from the same GNU Texinfo distribution.
  #print STDERR "REMARK: XS version: $xs_version\n";
  &$boot_fn($module, $xs_version);

  # This makes it easier to refer to packages and symbols by name.
  no strict 'refs';

  if (defined &{"${module}::init"}
      and !&{"${module}::init"} ($Texinfo::ModulePath::texinfo_uninstalled,
                                 $Texinfo::ModulePath::converterdatadir,
                                 $Texinfo::ModulePath::tp_builddir,
                                 $Texinfo::ModulePath::top_srcdir)) {
    _fatal("$module_name: error initializing");
    goto FALLBACK;
  }

  if ($perl_extra_file) {
    eval "require $perl_extra_file";
    if ($@) {
      warn();
      die "Error loading $perl_extra_file\n";
    }
  }

  return $module;

 FALLBACK:
  if ($TEXINFO_XS eq 'required') {
    die "set the TEXINFO_XS environment variable to 'omit' to use the "
       ."pure Perl modules\n";
  } elsif ($TEXINFO_XS eq 'warn' or $TEXINFO_XS eq 'debug') {
    if (defined($fallback_module)) {
      warn "falling back to pure Perl module $fallback_module\n";
    }
  }
  # if there is no fallback, it may be relevant to have access to the
  # return value in perl code, to check if the package was loaded.
  if (!defined $fallback_module) {
    if ($TEXINFO_XS eq 'warn' or $TEXINFO_XS eq 'debug') {
      warn "no fallback module for $module\n";
    }
    return undef;
    #die "set/unset the TEXINFO_XS, TEXINFO_XS_PARSER and TEXINFO_XS_CONVERT "
    #   ."environment variables to use the pure Perl modules\n";
  }

  # Fall back to using the Perl code.
  # Note that if no import method can be found, then the call is skipped (this
  # special case is described in perldoc use), therefore the fallback module
  # does not need to implement import().
  # Use eval here to interpret :: properly in module name.
  eval "require $fallback_module; $module->import();";
  if ($@) {
    warn();
    die "Error loading $fallback_module\n";
  }

  return  $fallback_module;
} # end init

# Override subroutine $TARGET with $SOURCE.
sub override {
  my ($target, $source) = @_;

  _debug("attempting to override $target with $source...");

  no strict 'refs'; # access modules and symbols by name.
  no warnings 'redefine'; # do not warn about redefining a function.

  if (defined &{"${source}"}) {
    *{"${target}"} = \&{"${source}"};
    _debug("  ...succeeded");
  } else {
    _debug("  ...failed");
  }
}


1;
__END__
