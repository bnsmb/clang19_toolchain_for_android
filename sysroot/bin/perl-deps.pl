#!/data/local/tmp/sysroot/usr/bin/perl
use strict;
use warnings;
use Module::CoreList;
use File::Find;
use File::Spec;
use File::Basename;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use Getopt::Long;
use Cwd qw(abs_path cwd);
use lib;
use POSIX qw(WNOHANG);
no strict 'refs';

# Autoflush stdout
$| = 1;


if (defined $ENV{CLANG_SYSROOT} && length $ENV{CLANG_SYSROOT}) {
    $ENV{PATH} = "$ENV{CLANG_SYSROOT}/usr/bin:$ENV{PATH}";
}

# ============================================================
# 1. Command line options
# ============================================================
my $help;
my $verbose = 0;
my $no_core;
my $no_duplicates = 1;
my $debug;
my $check_installed;
my $fetch_missing;
my $show_all;
my $show_build_deps;
my $force_download;
my $max_depth = 1;
my $quiet = 0;

GetOptions(
    'help'          => \$help,
    'verbose'       => \$verbose,
    'quiet'         => \$quiet,
    'no-core'       => \$no_core,
    'no-duplicates!' => \$no_duplicates,
    'debug'         => \$debug,
    'check'         => \$check_installed,
    'fetch'         => \$fetch_missing,
    'show-all'      => \$show_all,
    'build-deps'    => \$show_build_deps,
    'force-download'=> \$force_download,
    'depth=i'       => \$max_depth,
) or die "Usage: $0 [--help] [--verbose] [--quiet] [--no-core] [--no-duplicates] [--debug] [--check] [--fetch] [--show-all] [--build-deps] [--force-download] [--depth=N] <ModuleName>\n";

if ($help || !@ARGV) {
    print <<"EOT";
Usage: $0 [OPTIONS] <ModuleName>

OPTIONS:
    --help          Show this help message
    --verbose       Show detailed progress messages
    --quiet         Suppress all progress messages (only show results)
    --no-core       Don't show Perl core modules
    --no-duplicates Remove duplicate entries (default: enabled)
    --debug         Show debug information for troubleshooting
    --check         Check if each dependency is already installed
    --fetch         Fetch missing modules from CPAN (requires TMPDIR)
    --show-all      Show all sub-modules individually (default is grouped)
    --build-deps    Show build and test dependencies (from META.json)
    --force-download Force download even if module is installed
    --depth=N       Maximum dependency depth to analyze (default: 1)

Examples:
    # Show runtime dependencies only (default)
    $0 Log::Log4perl
    
    # Show build and test dependencies
    $0 --build-deps --force-download Log::Log4perl
    
    # Fetch and show all dependencies
    $0 --fetch --build-deps --force-download Log::Log4perl

EOT
    exit(0);
}

my $module_orig = shift @ARGV;
my $module_path = $module_orig;
$module_path =~ s/::/\//g;

# ============================================================
# 2. Progress indicator
# ============================================================

my $dots_active = 0;
my $last_dot_time = 0;

sub progress_start {
    my ($msg) = @_;
    return if $quiet;
    return if !$fetch_missing && !$verbose;
    print "$msg ";
    $dots_active = 1;
    $last_dot_time = time();
}

sub progress_dot {
    return if $quiet;
    return if !$dots_active;
    my $now = time();
    if ($now - $last_dot_time >= 0.15) {
        print ".";
        $last_dot_time = $now;
        select(undef, undef, undef, 0.01);
    }
}

sub progress_done {
    my ($status) = @_;
    return if $quiet;
    return if !$dots_active;
    if ($status) {
        print " $status\n";
    } else {
        print " Done\n";
    }
    $dots_active = 0;
}

sub progress_msg {
    my ($msg) = @_;
    return if $quiet;
    return if !$verbose && !$fetch_missing;
    print "$msg\n";
}

# ============================================================
# 3. Temporary directory handling
# ============================================================

my $TMPDIR;
my $temp_dir_created = 0;

sub check_tmpdir {
    my $tmpdir = $ENV{TMPDIR};
    
    if (!$tmpdir) {
        die "ERROR: TMPDIR environment variable is not set.\n" .
            "Please set TMPDIR to a writable directory for temporary files.\n";
    }
    
    if (!-d $tmpdir) {
        die "ERROR: TMPDIR '$tmpdir' does not exist.\n" .
            "Please create the directory or set TMPDIR to a valid path.\n";
    }
    
    if (!-w $tmpdir) {
        die "ERROR: TMPDIR '$tmpdir' is not writable.\n" .
            "Please check permissions or set TMPDIR to a writable directory.\n";
    }
    
    print "Debug: Using TMPDIR: $tmpdir\n" if $debug;
    return $tmpdir;
}

sub create_temp_dir {
    my $tmpdir = shift;
    my $prefix = "perl-deps-$$-";
    
    my $temp_dir;
    eval {
        $temp_dir = tempdir( $prefix . 'XXXXXX', DIR => $tmpdir, CLEANUP => 0 );
    };
    if ($@) {
        die "ERROR: Failed to create temporary directory in '$tmpdir': $@\n";
    }
    
    print "Debug: Created temporary directory: $temp_dir\n" if $debug;
    return $temp_dir;
}

sub cleanup_temp_dir {
    my ($dir) = @_;
    return unless $dir && -d $dir;
    
    print "Debug: Cleaning up temporary directory: $dir\n" if $debug;
    eval {
        remove_tree($dir, { safe => 1, keep_root => 0 });
    };
    if ($@) {
        warn "Warning: Could not clean up temporary directory '$dir': $@\n";
    }
}

# ============================================================
# 4. CPAN download and extraction
# ============================================================

sub run_command {
    my ($cmd) = @_;
    print "Debug: Running: $cmd\n" if $debug;
    return system($cmd) == 0;
}

sub download_file {
    my ($url, $output) = @_;
    
    if (run_command("which curl > /dev/null 2>&1")) {
        print "Debug: Using curl to download $url\n" if $debug;
        return run_command("curl -L -s -o '$output' '$url' 2>/dev/null");
    }
    
    if (run_command("which wget > /dev/null 2>&1")) {
        print "Debug: Using wget to download $url\n" if $debug;
        return run_command("wget -q -O '$output' '$url' 2>/dev/null");
    }
    
    die "ERROR: Neither curl nor wget found. Please install one of them.\n";
}

sub extract_tarball {
    my ($tarball, $target_dir) = @_;
    
    print "Debug: Extracting $tarball to $target_dir\n" if $debug;
    
    if (run_command("which tar > /dev/null 2>&1")) {
        return run_command("tar -xzf '$tarball' -C '$target_dir' 2>/dev/null");
    }
    
    die "ERROR: tar command not found. Please install tar.\n";
}

# List of modules that are false positives or system modules
my %false_positives = map { $_ => 1 } qw(
    happy
    Config
    DynaLoader
    Errno
    IO
    IPC
    VMS
    Win32
    XSLoader
    warnings
    Class
    Data
    List
    Scalar
    Socket
    Sys
    Term
    Tie
    Time
    Opcode
    RRDs
    CPAN
    CPANPLUS
    Mac
    SSL
    make
    inc
    authzID
    proxyDN
    LDAPv3
    Convert::ASN1
    Crypt::OpenPGP
    YAML::Tiny
    Win32::UTCFileTime
    Mac::BuildTools
);

# Optional dependencies that we shouldn't analyze further
my %optional_deps = map { $_ => 1 } qw(
    Net::LDAP
    LWP::UserAgent
    XML::DOM
    DBI
    Log::Log4perl::Appender::DBI
    Log::Log4perl::Config::LDAPConfigurator
    Log::Log4perl::Config::DOMConfigurator
    Log::Log4perl::Appender::RRDs
    Log::Log4perl::Appender::ScreenColoredLevels
);

# ============================================================
# 5. JSON parsing with jq fallback
# ============================================================

my $has_json_module = eval { require JSON; 1 };
my $has_jq = run_command("which jq > /dev/null 2>&1");

sub parse_json_with_jq {
    my ($file, $query) = @_;
    my $cmd = "jq -r '$query' '$file' 2>/dev/null";
    my $output = `$cmd`;
    return unless $output && $? == 0;
    chomp $output;
    return $output;
}

sub parse_json_deps_with_jq {
    my ($file, $section) = @_;
    my %deps;
    
    my $keys_cmd = "jq -r '.prereqs.$section.requires | keys[]' '$file' 2>/dev/null";
    my @keys = split(/\n/, `$keys_cmd`);
    return %deps unless @keys && $? == 0;
    
    for my $key (@keys) {
        next unless $key && $key ne '';
        my $version_cmd = "jq -r '.prereqs.$section.requires.\"$key\"' '$file' 2>/dev/null";
        my $version = `$version_cmd`;
        chomp $version if $version;
        $deps{$key} = $version || '0';
    }
    
    return %deps;
}

sub parse_meta_file {
    my ($dist_dir) = @_;
    my %deps;
    
    my $meta_json = File::Spec->catfile($dist_dir, "META.json");
    if (-f $meta_json) {
        print "Debug: Found META.json\n" if $debug;
        
        if ($has_json_module) {
            print "Debug: Using JSON Perl module\n" if $debug;
            eval {
                local $/;
                open my $fh, '<', $meta_json or die "Cannot open $meta_json";
                my $json_text = <$fh>;
                close $fh;
                
                my $json = JSON->new;
                my $data = $json->decode($json_text);
                
                if ($data->{prereqs}) {
                    my $prereqs = $data->{prereqs};
                    
                    if ($prereqs->{configure} && $prereqs->{configure}->{requires}) {
                        $deps{configure} = $prereqs->{configure}->{requires};
                    }
                    if ($prereqs->{build} && $prereqs->{build}->{requires}) {
                        $deps{build} = $prereqs->{build}->{requires};
                    }
                    if ($prereqs->{test} && $prereqs->{test}->{requires}) {
                        $deps{test} = $prereqs->{test}->{requires};
                    }
                    if ($prereqs->{runtime} && $prereqs->{runtime}->{requires}) {
                        $deps{runtime} = $prereqs->{runtime}->{requires};
                    }
                    if ($prereqs->{develop} && $prereqs->{develop}->{requires}) {
                        $deps{develop} = $prereqs->{develop}->{requires};
                    }
                }
                
                if ($data->{recommends}) {
                    $deps{recommends} = $data->{recommends};
                }
            };
            if ($@) {
                warn "Warning: Failed to parse META.json with JSON module: $@\n" if $verbose;
                if ($has_jq) {
                    print "Debug: Falling back to jq\n" if $debug;
                    %deps = ();
                    for my $section (qw(configure build test runtime develop)) {
                        my %section_deps = parse_json_deps_with_jq($meta_json, $section);
                        if (%section_deps) {
                            $deps{$section} = \%section_deps;
                        }
                    }
                    my %recommends = parse_json_deps_with_jq($meta_json, 'recommends');
                    if (%recommends) {
                        $deps{recommends} = \%recommends;
                    }
                }
            }
        } elsif ($has_jq) {
            print "Debug: Using jq for JSON parsing\n" if $debug;
            for my $section (qw(configure build test runtime develop)) {
                my %section_deps = parse_json_deps_with_jq($meta_json, $section);
                if (%section_deps) {
                    $deps{$section} = \%section_deps;
                }
            }
            my %recommends = parse_json_deps_with_jq($meta_json, 'recommends');
            if (%recommends) {
                $deps{recommends} = \%recommends;
            }
        } else {
            warn "Warning: Neither JSON Perl module nor jq available. Cannot parse META.json\n" if $verbose;
        }
    }
    
    if (!%deps) {
        my $meta_yml = File::Spec->catfile($dist_dir, "META.yml");
        if (-f $meta_yml) {
            print "Debug: Found META.yml\n" if $debug;
            eval {
                require YAML::Tiny;
                my $yaml = YAML::Tiny->read($meta_yml);
                my $data = $yaml->[0];
                
                if ($data->{prereqs}) {
                    my $prereqs = $data->{prereqs};
                    
                    if ($prereqs->{configure} && $prereqs->{configure}->{requires}) {
                        $deps{configure} = $prereqs->{configure}->{requires};
                    }
                    if ($prereqs->{build} && $prereqs->{build}->{requires}) {
                        $deps{build} = $prereqs->{build}->{requires};
                    }
                    if ($prereqs->{test} && $prereqs->{test}->{requires}) {
                        $deps{test} = $prereqs->{test}->{requires};
                    }
                    if ($prereqs->{runtime} && $prereqs->{runtime}->{requires}) {
                        $deps{runtime} = $prereqs->{runtime}->{requires};
                    }
                    if ($prereqs->{develop} && $prereqs->{develop}->{requires}) {
                        $deps{develop} = $prereqs->{develop}->{requires};
                    }
                }
                
                if ($data->{recommends}) {
                    $deps{recommends} = $data->{recommends};
                }
            };
            if ($@) {
                warn "Warning: Failed to parse META.yml: $@\n" if $verbose;
            }
        }
    }
    
    return \%deps;
}

# ============================================================
# 6. Distribution fetching
# ============================================================

my %seen_distributions = ();

my $fetch_started = 0;  # Add this near the top of the script

sub get_module_distribution {
    my ($mod, $temp_dir, $force) = @_;
    $force //= 0;
    
    my $base_mod = get_base_module($mod);
    
    if (!$force && $seen_distributions{$base_mod}) {
        progress_msg("Module $mod is part of distribution $base_mod (already fetched).") if $verbose;
        return $seen_distributions{$base_mod};
    }
    
    if ($false_positives{$mod}) {
        progress_msg("Skipping false positive module: $mod") if $verbose;
        return undef;
    }
    
    if (is_core_module($mod)) {
        progress_msg("Module $mod is a core Perl module, no need to fetch.") if $verbose;
        return undef;
    }
    
    # Only show fetch message once
    if ($verbose && $mod ne $module_orig) {
        progress_msg("Fetching $mod from CPAN...");
    }
    
    # Get distribution info from MetaCPAN
    my $api_url = "https://fastapi.metacpan.org/v1/module/$mod";
    my $info_file = File::Spec->catfile($temp_dir, "module_info.json");
    
    print "Debug: Querying MetaCPAN API: $api_url\n" if $debug;
    progress_start("  Querying MetaCPAN");
    
    if (!download_file($api_url, $info_file)) {
        progress_done("Failed");
        print "Warning: Could not fetch info for $mod from MetaCPAN API. Skipping.\n" if $verbose;
        return undef;
    }
    
    progress_done();
    
    if (!-f $info_file || !-s $info_file) {
        print "Warning: Module info file for $mod is empty or missing. Skipping.\n" if $verbose;
        return undef;
    }
    
    # Parse JSON to get distribution name
    my $real_dist_name;
    if ($has_jq) {
        print "Debug: Using jq to parse distribution info\n" if $debug;
        $real_dist_name = parse_json_with_jq($info_file, '.distribution');
        if (!$real_dist_name || $real_dist_name eq 'null') {
            print "Warning: Module $mod not found on CPAN (no distribution). Skipping.\n" if $verbose;
            return undef;
        }
    } else {
        eval {
            require JSON;
            local $/;
            open my $fh, '<', $info_file or die "Cannot open $info_file";
            my $json_text = <$fh>;
            close $fh;
            
            my $json = JSON->new;
            my $data = $json->decode($json_text);
            
            if ($data->{code} && $data->{code} == 404) {
                die "Module not found on CPAN (404)";
            }
            
            if ($data->{distribution}) {
                $real_dist_name = $data->{distribution};
            } else {
                die "No distribution found in API response\n";
            }
        };
        if ($@) {
            my $err = $@;
            if ($err =~ /404/) {
                print "Warning: Module $mod not found on CPAN (likely a system module). Skipping.\n" if $verbose;
            } else {
                print "Warning: Failed to parse JSON for $mod: $err\n" if $verbose;
            }
            return undef;
        }
    }
    
    print "Debug: Found distribution: $real_dist_name\n" if $debug;
    
    # Get release info
    my $release_url = "https://fastapi.metacpan.org/v1/release/$real_dist_name";
    my $release_file = File::Spec->catfile($temp_dir, "release_info.json");
    
    print "Debug: Querying release API: $release_url\n" if $debug;
    progress_start("  Getting release info");
    
    if (!download_file($release_url, $release_file)) {
        progress_done("Failed");
        die "ERROR: Failed to download release info from MetaCPAN API\n";
    }
    
    progress_done();
    
    if (!-f $release_file || !-s $release_file) {
        die "ERROR: Release info file is empty or missing\n";
    }
    
    # Parse release info to get download URL
    my $download_url;
    if ($has_jq) {
        print "Debug: Using jq to parse release info\n" if $debug;
        $download_url = parse_json_with_jq($release_file, '.download_url');
        if (!$download_url || $download_url eq 'null') {
            die "ERROR: No download_url found in release info\n";
        }
    } else {
        eval {
            require JSON;
            local $/;
            open my $fh, '<', $release_file or die "Cannot open $release_file";
            my $json_text = <$fh>;
            close $fh;
            
            my $json = JSON->new;
            my $data = $json->decode($json_text);
            
            if ($data->{download_url}) {
                $download_url = $data->{download_url};
            } else {
                die "No download_url found in release info\n";
            }
        };
        if ($@) {
            die "ERROR: Failed to parse release JSON: $@\n";
        }
    }
    
    print "Debug: Download URL: $download_url\n" if $debug;
    
    # Download the tarball
    my $tarball = File::Spec->catfile($temp_dir, "dist.tar.gz");
    progress_start("  Downloading");
    
    my $pid = fork();
    if ($pid == 0) {
        if (!download_file($download_url, $tarball)) {
            exit(1);
        }
        exit(0);
    } elsif ($pid > 0) {
        my $done = 0;
        while (!$done) {
            my $child = waitpid($pid, WNOHANG);
            if ($child == $pid) {
                $done = 1;
                my $status = $? >> 8;
                if ($status != 0) {
                    progress_done("Failed");
                    die "ERROR: Failed to download distribution from $download_url\n";
                }
            } else {
                progress_dot();
                select(undef, undef, undef, 0.05);
            }
        }
        progress_done();
    } else {
        die "ERROR: Failed to fork for download\n";
    }
    
    if (!-f $tarball || !-s $tarball) {
        die "ERROR: Downloaded tarball is empty or missing\n";
    }
    
    # Extract the tarball
    progress_start("  Extracting");
    
    $pid = fork();
    if ($pid == 0) {
        if (!extract_tarball($tarball, $temp_dir)) {
            exit(1);
        }
        exit(0);
    } elsif ($pid > 0) {
        my $done = 0;
        while (!$done) {
            my $child = waitpid($pid, WNOHANG);
            if ($child == $pid) {
                $done = 1;
                my $status = $? >> 8;
                if ($status != 0) {
                    progress_done("Failed");
                    die "ERROR: Failed to extract tarball $tarball\n";
                }
            } else {
                progress_dot();
                select(undef, undef, undef, 0.05);
            }
        }
        progress_done();
    } else {
        die "ERROR: Failed to fork for extraction\n";
    }
    
    # Find the extracted directory
    opendir(my $dh, $temp_dir) or die "ERROR: Cannot read temporary directory $temp_dir\n";
    my @dirs = grep { -d File::Spec->catfile($temp_dir, $_) && !/^\./ && $_ !~ /^perl-deps-/ } readdir($dh);
    closedir($dh);
    
    my $extract_dir;
    for my $dir (@dirs) {
        my $full_path = File::Spec->catfile($temp_dir, $dir);
        if (-f File::Spec->catfile($full_path, "Makefile.PL") ||
            -f File::Spec->catfile($full_path, "Build.PL") ||
            -f File::Spec->catfile($full_path, "lib", "$mod.pm")) {
            $extract_dir = $full_path;
            last;
        }
    }
    
    if (!$extract_dir) {
        $extract_dir = File::Spec->catfile($temp_dir, $dirs[0]) if @dirs;
    }
    
    if (!$extract_dir || !-d $extract_dir) {
        die "ERROR: Could not find extracted distribution directory\n";
    }
    
    print "Debug: Extracted to: $extract_dir\n" if $debug;
    
    # Find all .pm files
    progress_start("  Scanning .pm files");
    my @pm_files;
    find({
        wanted => sub {
            if (/\.pm$/ && -f $_) {
                push @pm_files, $_;
            }
        },
        no_chdir => 1,
    }, $extract_dir);
    
    progress_done("Found " . scalar(@pm_files));
    
    if (!@pm_files) {
        die "ERROR: No .pm files found in extracted distribution\n";
    }
    
    # Parse META.json for build/test dependencies
    my $meta_deps = parse_meta_file($extract_dir);
    
    my $result = {
        files => \@pm_files,
        dir => $extract_dir,
        name => $real_dist_name,
        meta => $meta_deps,
    };
    
    $seen_distributions{$base_mod} = $result;
    
    progress_msg("Done fetching $mod") if $mod eq $module_orig || $verbose;
    return $result;
}

# ============================================================
# 7. Helper functions
# ============================================================

sub find_module_path {
    my ($mod) = @_;
    return undef unless $mod;
    
    my $mod_pm = $mod;
    $mod_pm =~ s/::/\//g;
    $mod_pm .= ".pm";
    
    if (exists $INC{$mod_pm}) {
        return $INC{$mod_pm};
    }
    
    eval {
        my $load = "require $mod";
        eval $load;
    };
    if (!$@ && exists $INC{$mod_pm}) {
        return $INC{$mod_pm};
    }
    
    for my $dir (@INC) {
        next unless defined $dir && -d $dir;
        my $full_path = File::Spec->catfile($dir, split(/::/, $mod));
        $full_path .= ".pm";
        if (-f $full_path) {
            return $full_path;
        }
    }
    
    return undef;
}

sub is_core_module {
    my ($mod) = @_;
    return 1 if Module::CoreList::is_core($mod);
    return 1 if $mod eq 'VMS::Feature';
    return 1 if $mod eq 'VMS::Stdio';
    return 1 if $mod eq 'Win32';
    my $version = Module::CoreList->first_release($mod);
    return defined $version && $version ge '5.000';
}

sub is_module_installed {
    my ($mod) = @_;
    return 0 unless defined $mod && length $mod > 0;
    
    if (is_core_module($mod)) {
        return 1;
    }
    
    my $mod_pm = $mod;
    $mod_pm =~ s/::/\//g;
    $mod_pm .= ".pm";
    
    if (exists $INC{$mod_pm}) {
        return 1;
    }
    
    eval "require $mod";
    if (!$@) {
        return 1;
    }
    
    for my $dir (@INC) {
        next unless defined $dir && -d $dir;
        next if $dir =~ /perl-deps/;
        my $full_path = File::Spec->catfile($dir, split(/::/, $mod));
        $full_path .= ".pm";
        if (-f $full_path) {
            return 1;
        }
    }
    
    return 0;
}

sub get_module_version {
    my ($mod) = @_;
    return undef unless $mod;
    
    eval "require $mod";
    return undef if $@;
    
    my $version;
    if (defined ${"${mod}::VERSION"}) {
        $version = ${"${mod}::VERSION"};
        return $version if defined $version;
    }
    eval {
        $version = $mod->VERSION;
    };
    return $version if defined $version && !$@;
    eval {
        no strict 'refs';
        if (defined &{"${mod}::VERSION"}) {
            $version = &{"${mod}::VERSION"}();
        }
    };
    return $version if defined $version && !$@;
    return undef;
}

sub is_valid_module_name {
    my ($name) = @_;
    return 0 unless defined $name && length $name > 0;
    return 0 if $name !~ /^[A-Za-z_][A-Za-z0-9_:]*$/;
    return 0 if $name =~ /^(the|of|for|in|it|this|that|with|without|from|to|by|on|at)$/i;
    return 0 if $name =~ /^(strict|warnings|feature|vars|base|parent|integer|bytes|utf8|open|encoding|lib|overload|constant|if|autodie|re|builtin|subs|locale|Perl|IO::)$/;
    return 0 if $name =~ /^v5/;
    return 0 if $name =~ /^[a-z]$/;
    return 1;
}

sub get_base_module {
    my ($mod) = @_;
    my @parts = split(/::/, $mod);
    return $parts[0] if @parts > 0;
    return $mod;
}

# ============================================================
# 8. Extract dependencies from file
# ============================================================

sub extract_dependencies_from_file {
    my ($file) = @_;
    my @deps;
    my $in_pod = 0;
    my $in_data = 0;
    
    print "Debug: Reading dependencies from: $file\n" if $debug;
    
    open my $fh, '<', $file or do {
        warn "Cannot open $file: $!\n";
        return ();
    };
    
    # Escape module name for regex
    my $module_orig_quoted = quotemeta($module_orig);
    
    while (my $line = <$fh>) {
        next if $line =~ /^#!/;
        
        if ($line =~ /^=(?:head|over|item|back|for|begin|end|pod)/) {
            $in_pod = 1;
            next;
        }
        if ($line =~ /^=cut/) {
            $in_pod = 0;
            next;
        }
        next if $in_pod;
        
        if ($line =~ /^__DATA__/ || $line =~ /^__END__/) {
            $in_data = 1;
            next;
        }
        next if $in_data;
        
        next if $line =~ /^\s*#/;
        
        if ($line =~ /\b(?:use|require)\s+([A-Za-z_][A-Za-z0-9_:]*)/) {
            my $dep = $1;
            next if $dep =~ /^\d/;
            next if !is_valid_module_name($dep);
            next if $dep eq $module_orig;
            next if $false_positives{$dep};
            next if $no_core && is_core_module($dep);
            
            # Skip sub-modules of the main module - they'll be handled by the distribution
            if ($dep =~ /^\Q$module_orig\E::/) {		    
                print "Debug: Found sub-module: $dep (will be handled by distribution)\n" if $debug;
                next;
            }
            
            push @deps, $dep;
            print "Debug: Found dependency: $dep\n" if $debug;
        }
    }
    close $fh;
    
    my %seen;
    @deps = grep { !$seen{$_}++ } @deps;
    return @deps;
}

# ============================================================
# 9. Analyze dependencies
# ============================================================

sub analyze_distribution_deps {
    my ($dist) = @_;
    my @deps;
    
    return () unless $dist && $dist->{files};
    
    for my $file (@{$dist->{files}}) {
        if (-f $file) {
            my @file_deps = extract_dependencies_from_file($file);
            for my $dep (@file_deps) {
                next if $dep eq $module_orig;
                next if $no_core && is_core_module($dep);
                next if $dep =~ /^(C|of|for|in|the|it|this|that|with|without|from|to|by|on|at)$/i;
                next if $dep =~ /^v5/;
                next if $dep =~ /^[a-z]$/;
                next if $false_positives{$dep};
                next if grep { $_ eq $dep } @deps;
                push @deps, $dep;
            }
        }
    }
    
    return @deps;
}

sub get_all_dependencies {
    my ($mod, $visited, $depth, $temp_dir, $fetched_files) = @_;
    $depth //= 0;
    $visited //= {};
    $temp_dir //= undef;
    $fetched_files //= {};
    
    return if $visited->{$mod};
    return if $depth > $max_depth;
    return if $false_positives{$mod};
    
    if ($depth > 0 && $optional_deps{$mod}) {
        print "  " x $depth . "Skipping optional dependency: $mod\n" if $verbose;
        return ();
    }
    
    # Check if this is a sub-module of the main module
    if ($mod ne $module_orig && $mod =~ /^\Q$module_orig\E::/) {
        print "  " x $depth . "Module $mod is a sub-module of $module_orig, skipping fetch.\n" if $verbose;
        my @sub_deps;
        my $mod_path = find_module_path($mod);
        if ($mod_path) {
            print "  " x $depth . "Found at: $mod_path\n" if $verbose;
            my @found = extract_dependencies_from_file($mod_path);
            for my $dep (@found) {
                next if $dep eq $mod;
                next if $no_core && is_core_module($dep);
                next if $dep =~ /^(C|of|for|in|the|it|this|that|with|without|from|to|by|on|at)$/i;
                next if $dep =~ /^v5/;
                next if $dep =~ /^[a-z]$/;
                next if $false_positives{$dep};
                next if grep { $_ eq $dep } @sub_deps;
                next if $visited->{$dep};
                push @sub_deps, $dep;
            }
        }
        return @sub_deps;
    }
    
    $visited->{$mod} = 1;
    print "  " x $depth . "Analyzing: $mod\n" if $verbose;
    
    my @deps;
    my $mod_path = find_module_path($mod);
    my $base = get_base_module($mod);
    
    # Check if we already have the distribution cached
    if ($seen_distributions{$base}) {
        print "  " x $depth . "Using cached distribution for $base\n" if $verbose;
        my $dist = $seen_distributions{$base};
        if ($dist && $dist->{dir}) {
            push @INC, $dist->{dir};
            my $lib_dir = File::Spec->catdir($dist->{dir}, 'lib');
            if (-d $lib_dir) {
                push @INC, $lib_dir;
            }
        }
        my @found = analyze_distribution_deps($dist);
        for my $dep (@found) {
            next if $dep eq $mod;
            next if $no_core && is_core_module($dep);
            next if $false_positives{$dep};
            next if $visited->{$dep};
            push @deps, $dep;
            my @sub_deps = get_all_dependencies($dep, $visited, $depth + 1, $temp_dir, $fetched_files);
            for my $sub_dep (@sub_deps) {
                next if grep { $_ eq $sub_dep } @deps;
                push @deps, $sub_dep;
            }
        }
        return @deps;
    }
    
    my $should_fetch = ($force_download || (!$mod_path && $fetch_missing && $temp_dir && !$fetched_files->{$mod}));
    if ($mod eq $module_orig && $force_download) {
        $should_fetch = 1;
    }
    
    if ($mod_path && !$should_fetch) {
        print "  " x $depth . "Found at: $mod_path\n" if $verbose;
        my @found = extract_dependencies_from_file($mod_path);
        for my $dep (@found) {
            next if $dep eq $mod;
            next if $no_core && is_core_module($dep);
            next if $dep =~ /^(C|of|for|in|the|it|this|that|with|without|from|to|by|on|at)$/i;
            next if $dep =~ /^v5/;
            next if $dep =~ /^[a-z]$/;
            next if $false_positives{$dep};
            next if grep { $_ eq $dep } @deps;
            next if $visited->{$dep};
            push @deps, $dep;
        }
        for my $dep (@found) {
            next if $dep eq $mod;
            next if $no_core && is_core_module($dep);
            next if $dep =~ /^(C|of|for|in|the|it|this|that|with|without|from|to|by|on|at)$/i;
            next if $dep =~ /^v5/;
            next if $dep =~ /^[a-z]$/;
            next if $false_positives{$dep};
            next if $visited->{$dep};
            my @sub_deps = get_all_dependencies($dep, $visited, $depth + 1, $temp_dir, $fetched_files);
            for my $sub_dep (@sub_deps) {
                next if grep { $_ eq $sub_dep } @deps;
                push @deps, $sub_dep;
            }
        }
    } elsif ($should_fetch && $temp_dir) {
        if (is_core_module($mod)) {
            print "  " x $depth . "Module '$mod' is a core module, skipping.\n" if $verbose;
            return @deps;
        }
        print "  " x $depth . "Fetching $mod from CPAN...\n" if $verbose;
        $fetched_files->{$mod} = 1;
        my $dist = get_module_distribution($mod, $temp_dir, 1);
        if (!$dist) {
            return @deps;
        }
        if ($dist->{dir}) {
            push @INC, $dist->{dir};
            my $lib_dir = File::Spec->catdir($dist->{dir}, 'lib');
            if (-d $lib_dir) {
                push @INC, $lib_dir;
            }
        }
        my @found = analyze_distribution_deps($dist);
        for my $dep (@found) {
            next if $dep eq $mod;
            next if $no_core && is_core_module($dep);
            next if $false_positives{$dep};
            next if $visited->{$dep};
            push @deps, $dep;
            my @sub_deps = get_all_dependencies($dep, $visited, $depth + 1, $temp_dir, $fetched_files);
            for my $sub_dep (@sub_deps) {
                next if grep { $_ eq $sub_dep } @deps;
                push @deps, $sub_dep;
            }
        }
    } else {
        warn "  " x $depth . "WARNING: Cannot find module '$mod'\n" if $debug || $verbose;
    }
    
    return @deps;
}

# ============================================================
# 10. Group by distribution
# ============================================================

sub group_by_distribution {
    my (@deps) = @_;
    my %groups;
    
    for my $dep (@deps) {
        next if $false_positives{$dep};
        next if $optional_deps{$dep} && !is_module_installed($dep);
        
        my $base = get_base_module($dep);
        my $is_core = is_core_module($dep);
        my $is_installed = is_module_installed($dep);
        
        $groups{$base}->{modules}->{$dep} = 1;
        $groups{$base}->{is_core} = $is_core if $is_core;
        $groups{$base}->{is_installed} = $is_installed if $is_installed;
        $groups{$base}->{version} = get_module_version($dep) if $is_installed;
        $groups{$base}->{display_name} = $dep if scalar(keys %{$groups{$base}->{modules}}) == 1;
    }
    
    my @result;
    for my $base (keys %groups) {
        my @sub_mods = keys %{$groups{$base}->{modules}};
        my $display_name = $groups{$base}->{display_name} || $base;
        push @result, {
            name => $display_name,
            base => $base,
            modules => \@sub_mods,
            is_core => $groups{$base}->{is_core} || 0,
            is_installed => $groups{$base}->{is_installed} || 0,
            version => $groups{$base}->{version} || undef,
            count => scalar(@sub_mods),
        };
    }
    
    return @result;
}

# ============================================================
# 11. Show build dependencies
# ============================================================

sub show_build_dependencies {
    my ($meta_deps) = @_;
    
    return unless $meta_deps && keys %$meta_deps;
    
    print "\n" . "=" x 60 . "\n";
    print "Build/Test Dependencies (from META.json):\n";
    print "=" x 60 . "\n";
    
    my @sections = (
        { key => 'configure', label => 'CONFIGURE DEPENDENCIES' },
        { key => 'build', label => 'BUILD DEPENDENCIES' },
        { key => 'test', label => 'TEST DEPENDENCIES' },
        { key => 'develop', label => 'DEVELOPMENT DEPENDENCIES' },
        { key => 'recommends', label => 'RECOMMENDED DEPENDENCIES' },
    );
    
    my $total = 0;
    for my $section (@sections) {
        my $key = $section->{key};
        next unless $meta_deps->{$key};
        
        my $deps = $meta_deps->{$key};
        print "\n" . $section->{label} . ":\n";
        print "-" x 60 . "\n";
        
        my $i = 1;
        for my $mod (sort keys %$deps) {
            my $version = $deps->{$mod};
            my $version_info = $version && $version ne '0' ? " (>= $version)" : "";
            my $installed = is_module_installed($mod) ? " [INSTALLED]" : " [MISSING]";
            print sprintf("%3d. %s%s%s\n", $i++, $mod, $version_info, $installed);
            $total++;
        }
    }
    
    print "\n" . "-" x 60 . "\n";
    print "Total build/test dependencies: $total\n";
    
    my @missing;
    for my $section (qw(configure build test develop)) {
        next unless $meta_deps->{$section};
        for my $mod (keys %{$meta_deps->{$section}}) {
            if (!is_module_installed($mod) && !is_core_module($mod)) {
                push @missing, $mod;
            }
        }
    }
    
    if (@missing) {
        print "\nTo install missing build/test dependencies:\n";
        print "  cpan " . join(" \\\n    ", @missing) . "\n";
    }
    
    print "\nNote: Build/Test dependencies are only needed when installing or developing the module.\n";
}

# ============================================================
# 12. Main logic
# ============================================================

my $temp_dir;
if ($fetch_missing || $force_download) {
    $TMPDIR = check_tmpdir();
    $temp_dir = create_temp_dir($TMPDIR);
    $temp_dir_created = 1;
    print "Debug: Will use temporary directory for fetched modules\n" if $debug;
}

if ($debug) {
    if ($has_json_module) {
        print "Debug: JSON Perl module is available\n";
    } elsif ($has_jq) {
        print "Debug: jq is available\n";
    } else {
        print "Debug: Neither JSON Perl module nor jq is available\n";
    }
}

# Check if module exists
my $module_path_check = "$module_path.pm";
my $module_installed = 0;

if (exists $INC{$module_path_check}) {
    $module_installed = 1;
} else {
    eval "require $module_orig";
    if (!$@ && exists $INC{$module_path_check}) {
        $module_installed = 1;
    } else {
        if (is_core_module($module_orig)) {
            $module_installed = 1;
            if ($verbose) {
                print "Note: '$module_orig' is a Perl core module.\n";
            }
        }
    }
}

if (!$module_installed && !$fetch_missing) {
    print "\n" . "=" x 60 . "\n";
    print "ERROR: Module '$module_orig' is not installed.\n";
    print "=" x 60 . "\n";
    print "\n";
    print "Options:\n";
    print "  1. Install the module: cpan $module_orig\n";
    print "  2. Use --fetch to analyze from CPAN: $0 --fetch $module_orig\n";
    print "  3. Use --force-download to force analysis: $0 --force-download $module_orig\n";
    print "\n";
    print "Example:\n";
    print "  $0 --fetch $module_orig\n";
    print "\n";
    exit(1);
}

if ($fetch_missing && !$quiet) {
    print "Fetching $module_orig from CPAN...\n";
}

if ($debug) {
    print "Debug: @INC contains:\n";
    for my $dir (@INC) {
        print "  $dir\n";
    }
    print "\n";
}

my @original_inc = @INC;

if (($fetch_missing || $force_download) && $temp_dir) {
    push @INC, $temp_dir;
    print "Debug: Added temporary directory to \@INC: $temp_dir\n" if $debug;
}

my %visited;
my %fetched_files;
my @all_deps = get_all_dependencies($module_orig, \%visited, 0, $temp_dir, \%fetched_files);

@INC = @original_inc;

if ($no_duplicates) {
    my %seen;
    @all_deps = grep { !$seen{$_}++ } @all_deps;
}

if ($no_core) {
    @all_deps = grep { !is_core_module($_) } @all_deps;
}

@all_deps = grep { is_valid_module_name($_) } @all_deps;
@all_deps = grep { !$false_positives{$_} } @all_deps;

# ============================================================
# 13. Output
# ============================================================

if (@all_deps) {
    if ($show_all) {
        my $i = 1;
        my $core_count = 0;
        my $non_core_count = 0;
        my $installed_count = 0;
        my $missing_count = 0;
        my @to_install;
        
        my @sorted = sort { 
            (is_core_module($a) ? 0 : 1) <=> (is_core_module($b) ? 0 : 1) ||
            $a cmp $b
        } @all_deps;
        
        print "\nDependencies for '$module_orig' (all modules):\n";
        print "=" x 60 . "\n";
        
        for my $dep (@sorted) {
            my $is_core = is_core_module($dep);
            my $core_status = $is_core ? " [Core]" : "";
            my $installed = 0;
            my $install_status = "";
            
            if ($check_installed || $fetch_missing) {
                $installed = is_module_installed($dep);
                if ($installed) {
                    $install_status = " [INSTALLED]";
                    $installed_count++;
                } else {
                    $install_status = " [MISSING]";
                    $missing_count++;
                    push @to_install, $dep;
                }
            }
            
            my $version_info = "";
            if ($installed) {
                my $version = get_module_version($dep);
                if (defined $version) {
                    $version_info = " (v$version)";
                }
            }
            
            print sprintf("%3d. %s%s%s%s\n", $i++, $dep, $core_status, $install_status, $version_info);
            
            if ($is_core) {
                $core_count++;
            } else {
                $non_core_count++;
            }
        }
        
        print "\n" . "-" x 60 . "\n";
        print "Total: " . scalar(@sorted) . " dependencies\n";
        print "  Core modules: $core_count (already in Perl)\n";
        
        if ($check_installed || $fetch_missing) {
            print "  Installed: $installed_count\n";
            print "  Missing: $missing_count\n";
        }
        
        print "  Non-core modules: $non_core_count (need to install)\n";
        
        if (@to_install) {
            print "\n" . "=" x 60 . "\n";
            print "MODULES TO INSTALL:\n";
            print "-" x 60 . "\n";
            my $j = 1;
            for my $dep (@to_install) {
                print sprintf("%3d. %s\n", $j++, $dep);
            }
            print "\nTo install missing modules:\n";
            print "  cpan " . join(" \\\n    ", @to_install) . "\n";
        }
        
    } else {
        my @grouped = group_by_distribution(@all_deps);
        
        print "\nDependencies for '$module_orig' (grouped by distribution):\n";
        print "=" x 60 . "\n";
        
        my $i = 1;
        my $core_count = 0;
        my $non_core_count = 0;
        my $installed_count = 0;
        my $missing_count = 0;
        my @to_install;
        
        my @sorted = sort { 
            ($a->{is_core} ? 0 : 1) <=> ($b->{is_core} ? 0 : 1) ||
            $a->{name} cmp $b->{name}
        } @grouped;
        
        for my $group (@sorted) {
            my $name = $group->{name};
            my $is_core = $group->{is_core};
            my $is_installed = $group->{is_installed};
            my $version = $group->{version};
            my $count = $group->{count};
            
            my $core_status = $is_core ? " [Core]" : "";
            my $install_status = "";
            
            if ($is_core) {
                $install_status = " [Core Module]";
                $core_count++;
            } elsif ($is_installed) {
                $install_status = " [INSTALLED]";
                $installed_count++;
            } else {
                $install_status = " [MISSING]";
                $missing_count++;
                push @to_install, $name;
            }
            
            my $version_info = "";
            if ($version) {
                $version_info = " (v$version)";
            }
            
            my $module_info = "";
            if ($count > 1) {
                $module_info = " ($count modules)";
            }
            
            print sprintf("%3d. %s%s%s%s%s\n", $i++, $name, $core_status, $install_status, $version_info, $module_info);
            
            if ($verbose && $count > 1) {
                for my $sub_mod (sort @{$group->{modules}}) {
                    next if $sub_mod eq $name;
                    print "       └── $sub_mod\n";
                }
            }
            
            if (!$is_core) {
                $non_core_count++;
            }
        }
        
        print "\n" . "-" x 60 . "\n";
        print "Total: " . scalar(@sorted) . " distributions\n";
        print "  Core modules: $core_count (already in Perl)\n";
        
        if ($check_installed || $fetch_missing) {
            print "  Installed: $installed_count\n";
            print "  Missing: $missing_count\n";
        }
        
        print "  Non-core modules: $non_core_count (need to install)\n";
        
        if (@to_install) {
            print "\n" . "=" x 60 . "\n";
            print "MODULES TO INSTALL (distributions):\n";
            print "-" x 60 . "\n";
            my $j = 1;
            for my $dep (@to_install) {
                print sprintf("%3d. %s\n", $j++, $dep);
            }
            print "\nTo install missing modules:\n";
            print "  cpan " . join(" \\\n    ", @to_install) . "\n";
        }
    }
    
} else {
    if ($module_installed) {
        print "No runtime dependencies found for '$module_orig'\n";
    } else {
        print "\n" . "=" x 60 . "\n";
        print "No dependencies found for '$module_orig'\n";
        print "=" x 60 . "\n";
        print "\n";
        print "The module was analyzed from CPAN but no dependencies were found.\n";
        print "This might be a minimal module with no dependencies, or the analysis\n";
        print "might have been incomplete. Try running with --debug for more info.\n";
    }
}

# ============================================================
# 14. Show build/test dependencies if requested
# ============================================================

if ($show_build_deps && ($force_download || $fetch_missing)) {
    my $meta_deps;
    for my $base (keys %seen_distributions) {
        if ($seen_distributions{$base}->{meta} && keys %{$seen_distributions{$base}->{meta}}) {
            $meta_deps = $seen_distributions{$base}->{meta};
            last;
        }
    }
    
    if ($meta_deps) {
        show_build_dependencies($meta_deps);
    } else {
        print "\nWarning: Could not find META.json/META.yml in the fetched distribution.\n";
        print "Build/Test dependencies not available.\n";
    }
}

# ============================================================
# 15. Cleanup
# ============================================================

if ($temp_dir_created && $temp_dir) {
    cleanup_temp_dir($temp_dir);
}

# ============================================================
# 16. Additional information
# ============================================================

if ($verbose || $debug) {
    print "\n" . "=" x 60 . "\n";
    print "Information:\n";
    print "- Runtime dependencies: needed when using the module\n";
    print "- Build/Test dependencies: only needed when installing/developing\n";
    print "- Use --build-deps to see build and test dependencies\n";
    print "- Use --force-download to download even if module is installed\n";
    print "- Use --fetch to download and analyze from CPAN\n";
    print "- Use --depth=N to control dependency depth\n";
    print "- Temporary files are stored in TMPDIR: $ENV{TMPDIR}\n";
    print "- Use --debug for troubleshooting\n";
    if (!$has_json_module && $has_jq) {
        print "- Using jq for JSON parsing (Perl JSON module not available)\n";
    } elsif ($has_json_module) {
        print "- Using Perl JSON module\n";
    } else {
        print "- WARNING: Neither JSON Perl module nor jq available\n";
    }
}

exit(0);
