#!/system/bin/env perl
# perl_env_check.pl - Perl installation self-test; uses Perl core modules only.
# Usage: perl perl_env_check.pl [--network] [--verbose]

use strict;
use warnings;
use Config;
use File::Spec;
use File::Temp qw(tempfile);
use IO::Socket::INET;

my %arg = map { $_ => 1 } @ARGV;
my $network = $arg{'--network'} || 0;
my @results;
my $required_failures = 0;
my $warnings = 0;
my $skipped = 0;

sub report {
    my ($status, $kind, $name, $detail) = @_;
    $detail = '' unless defined $detail;
    push @results, [$status, $kind, $name, $detail];
    $required_failures++ if $status eq 'FAIL' && $kind eq 'required';
    $warnings++ if $status eq 'WARN';
    $skipped++ if $status eq 'SKIP';
    print "$status [$kind] $name";
    print " — $detail" if length $detail;
    print "\n";
}

sub check {
    my ($kind, $name, $code) = @_;
    my ($detail, $ok);
    eval { $detail = $code->(); $ok = 1; 1 } or do {
        $detail = $@ || 'unknown error';
        $detail =~ s/\s+\z//;
        $ok = 0;
    };
    report($ok ? 'PASS' : 'FAIL', $kind, $name, $detail);
}

# Fängt STDOUT UND STDERR des Kindprozesses ein und liefert den Exitcode mit.
sub run_capture {
    my (@cmd) = @_;
    my $pid = open(my $fh, '-|') // die "fork failed for @cmd: $!";
    if ($pid == 0) {
        open STDERR, '>&', \*STDOUT or die "cannot dup stderr: $!";
        exec @cmd or die "cannot execute @cmd: $!";
    }
    local $/;
    my $out = <$fh>;
    $out = '' unless defined $out;
    close $fh;
    my $status = $? >> 8;
    return ($out, $status);
}

# Kompatibilitäts-Wrapper: liefert nur STDOUT+STDERR, stirbt bei Exitcode != 0.
sub command_output {
    my (@cmd) = @_;
    my ($out, $status) = run_capture(@cmd);
    die "command failed (@cmd), exit=$status" if $status != 0;
    return $out;
}

print "Perl installation self-test\n============================\n";

check('required', 'interpreter metadata', sub {
    die "Perl version too old" unless $] >= 5.008;
    return "perl=$^X; version=$^V; archname=$Config{archname}; os=$Config{osname}";
});

check('required', 'configuration paths', sub {
    my @keys = qw(prefix privlibexp archlibexp sitearchexp sitelibexp binexp);
    return join ' | ', map {
        $_ . '=' . (defined $Config{$_} && length $Config{$_} ? $Config{$_} : '(unset)')
    } @keys;
});

check('required', 'basic language/runtime', sub {
    my @a = (1, 2, 3);
    my %h = (answer => 42);
    my $sum = 0;
    $sum += $_ for @a;
    die "array/hash/loop test failed" unless $sum == 6 && $h{answer} == 42;
    my $unicode = "Perl \x{2713}";
    die "Unicode scalar test failed" unless length($unicode) >= 6;
    return 'scalars, arrays, hashes, loops and Unicode scalar operations succeeded';
});

check('required', 'core module loading', sub {
    my @mods = qw(strict warnings Config Cwd File::Spec File::Temp Getopt::Long
                  IPC::Open3 Scalar::Util Storable Digest::SHA JSON::PP Encode
                  MIME::Base64 IO::Socket::INET Socket Fcntl POSIX Time::HiRes
                  Sys::Hostname);
    my @bad;
    for my $mod (@mods) {
        (my $file = "$mod.pm") =~ s{::}{/}g;
        eval { require $file; 1 } or push @bad, "$mod: $@";
    }
    die join("; ", @bad) if @bad;
    return scalar(@mods) . ' Perl core modules loaded successfully';
});

check('optional', 'optional modules', sub {
    my @mods = qw(threads threads::shared DB_File GDBM_File Compress::Zlib
                  IO::Socket::SSL Net::SSLeay DBD::SQLite);
    my (@yes, @no);
    for my $mod (@mods) {
        (my $file = "$mod.pm") =~ s{::}{/}g;
        if (eval { require $file; 1 }) { push @yes, $mod }
        else {
            my $e = $@ || 'unavailable';
            $e =~ s/\s+/ /g;
            push @no, "$mod ($e)";
        }
    }
    return 'available=[' . join(', ', @yes) . ']; unavailable=[' . join(', ', @no) . ']';
});

check('required', 'temporary filesystem I/O', sub {
    my ($fh, $path) = tempfile('perlcheck-XXXXXX', TMPDIR => 1, UNLINK => 1);
    binmode $fh, ':encoding(UTF-8)';
    print {$fh} "Perl self-test\nGrüße\n" or die "write failed: $!";
    close $fh or die "close failed: $!";
    open my $in, '<:encoding(UTF-8)', $path or die "read open failed: $!";
    local $/;
    my $data = <$in>;
    close $in or die "read close failed: $!";
    die "content mismatch" unless $data eq "Perl self-test\nGrüße\n";
    return 'temporary file create/write/read and UTF-8 succeeded';
});

check('required', 'source compilation', sub {
    my ($fh, $path) = tempfile('perlcompile-XXXXXX', SUFFIX => '.pl', TMPDIR => 1, UNLINK => 1);
    print {$fh} "use strict; use warnings; my \$x = 21 * 2; exit(\$x == 42 ? 0 : 1);\n"
        or die "write source failed: $!";
    close $fh or die "close source failed: $!";
    my ($out, $status) = run_capture($^X, '-c', $path);
    $out =~ s/\s+\z//;
    die "perl -c failed (exit $status): $out" unless $status == 0;
    die "perl -c unexpected output: $out" unless $out =~ /syntax OK/i;
    return "perl -c succeeded: $out";
});

check('required', 'subprocess execution', sub {
    my ($out, $status) = run_capture($^X, '-e', 'print 3 * 15');
    die "child failed (exit $status): $out" unless $status == 0;
    die "unexpected child output: $out" unless $out eq '45';
    return "child interpreter ran and returned $out";
});

check('required', 'SHA-256 hash', sub {
    require Digest::SHA;
    my $got = Digest::SHA::sha256_hex('abc');
    my $expected = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
    die "SHA-256 known-answer test failed: $got" unless $got eq $expected;
    return 'Digest::SHA known-answer test passed';
});

check('required', 'JSON encode/decode', sub {
    require JSON::PP;
    # $JSON::PP::true ist eine Blessed Reference (Klasse JSON::PP::Boolean).
    # Ein Bareword JSON::PP::true wäre unter strict subs ein Fehler und
    # würde hier nur einen String "JSON::PP::true" erzeugen, kein echtes
    # JSON-Boolean. Daher zwingend das $-Sigil verwenden.
    my $json = JSON::PP->new->canonical->encode({
        answer => 42,
        ok     => $JSON::PP::true,
    });
    my $obj = JSON::PP->new->decode($json);
    die "JSON round-trip failed" unless $obj->{answer} == 42 && $obj->{ok};
    return 'JSON::PP encode/decode round-trip succeeded';
});

check('required', 'process exit status', sub {
    my $rc = system($^X, '-e', 'exit 7');
    die "system() could not start child: $!" if $rc == -1;
    my $exit = $rc >> 8;
    die "expected child exit 7, got $exit (raw=$rc)" unless $exit == 7;
    return 'system() correctly reported child exit status 7';
});

check('optional', 'TCP loopback', sub {
    my $server = IO::Socket::INET->new(
        LocalAddr => '127.0.0.1', LocalPort => 0,
        Listen => 1, ReuseAddr => 1, Proto => 'tcp'
    ) or die "cannot create loopback listener: $!";
    my $port = $server->sockport();
    my $pid = fork();
    die "fork failed: $!" unless defined $pid;
    if ($pid == 0) {
        close $server;
        my $client = IO::Socket::INET->new(
            PeerAddr => '127.0.0.1', PeerPort => $port,
            Proto => 'tcp', Timeout => 3
        ) or exit 11;
        print {$client} "ping\n" or exit 12;
        my $reply = <$client>;
        close $client;
        exit(defined($reply) && $reply eq "pong\n" ? 0 : 13);
    }
    my $peer = $server->accept() or die "accept failed: $!";
    $peer->autoflush(1);
    my $line = <$peer>;
    die "unexpected request" unless defined($line) && $line eq "ping\n";
    print {$peer} "pong\n" or die "reply failed: $!";
    close $peer;
    close $server;
    waitpid($pid, 0);
    my $status = $? >> 8;
    die "TCP child failed with status $status" if $status != 0;
    return "TCP loopback request/reply succeeded on port $port";
});

check('optional', 'OS command availability', sub {
    my @commands = qw(sh uname id pwd);
    my @found;
    for my $cmd (@commands) {
        my $path;
        for my $dir (File::Spec->path()) {
            my $candidate = File::Spec->catfile($dir, $cmd);
            if (-f $candidate && -x $candidate) { $path = $candidate; last }
        }
        push @found, "$cmd=" . ($path || 'not found');
    }
    my $uname = eval { command_output('uname', '-s', '-m') };
    $uname = 'uname unavailable' if $@;
    $uname =~ s/\s+\z//;
    return join('; ', @found) . "; system=$uname";
});

if ($network) {
    check('optional', 'outbound HTTPS', sub {
        require IO::Socket::SSL;
        my $sock = IO::Socket::SSL->new(
            PeerHost => 'www.perl.org', PeerPort => 443,
            SSL_hostname => 'www.perl.org', Timeout => 8,
            SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_PEER(),
        ) or die "TLS connection failed: " . IO::Socket::SSL::errstr();
        print {$sock} "GET / HTTP/1.0\r\nHost: www.perl.org\r\nConnection: close\r\n\r\n"
            or die "HTTPS request write failed: $!";
        my $line = <$sock>;
        close $sock;
        die "no valid HTTP response" unless defined $line && $line =~ m{^HTTP/\d(?:\.\d)?\s+\d+};
        return "TLS certificate validation and HTTPS succeeded: $line";
    });
} else {
    report('SKIP', 'optional', 'outbound HTTPS',
           'not run; pass --network (requires IO::Socket::SSL and network access)');
}

print "\nSummary: " . scalar(@results) . " checks; required failures=$required_failures; warnings=$warnings; skipped=$skipped\n";
print "Optional modules and platform-specific capabilities may legitimately be unavailable.\n";
exit($required_failures ? 1 : 0);

