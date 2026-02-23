#!/usr/bin/perl

$config   = "/var/openssl/openssl.cnf";
$capath   = "/usr/bin/openssl";
die "CERTPASS environment variable not set" unless $ENV{CERTPASS};
umask 0077;
use File::Temp qw(tempfile);
my ($tempca_fh,  $tempca)  = tempfile("cliXXXXXX",  UNLINK => 0);
my ($tempout_fh, $tempout) = tempfile("certtmpXXXXXX", UNLINK => 0);
$CAcert   = "/var/openssl/localCA/cacert.pem";
$spkac	  = "";

&ReadForm;

$spkac = $FIELDS{'SPKAC'};
$spkac =~ s/\n//g;

print $tempca_fh "C = $FIELDS{'country'}\n";
print $tempca_fh "ST = $FIELDS{'state'}\n";
print $tempca_fh "O = $FIELDS{'organization'}\n";
print $tempca_fh "Email = $FIELDS{'email'}\n";
print $tempca_fh "CN = $FIELDS{'who'}\n";
print $tempca_fh "SPKAC = $spkac\n";
close($tempca_fh);
close($tempout_fh);

system($capath, "ca",
    "-batch",
    "-config", $config,
    "-spkac", $tempca,
    "-out", $tempout,
    "-passin", "env:CERTPASS",
    "-cert", $CAcert);
open(CERT,"$tempout") || die &Error;
@certificate = <CERT>;
close(CERT);

unlink $tempca;
unlink $tempout;

print "Content-type: application/x-x509-user-cert\n\n";
print @certificate;

##############################################################
####
####     Procedures
####

sub ReadForm {

   if ($ENV{'REQUEST_METHOD'} eq 'GET') {
      @pairs = split(/&/, $ENV{'QUERY_STRING'});
   }
   elsif ($ENV{'REQUEST_METHOD'} eq 'POST') {
      read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
      @pairs = split(/&/, $buffer);
   }
   foreach $pair (@pairs) {
      ($name, $value) = split(/=/, $pair);
      $name =~ tr/+/ /;
      $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
      $value =~ tr/+/ /;
      $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
      $value =~ s/<!--(.|\n)*-->//g;
      $FIELDS{$name} = $value;
      }
}

sub Error {
    print "Content-type: text/html\n\n";
    print "<P><P><center><H1>Can't open file</H1></center>\n";
}
