#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';

use Digest::SHA;
use Getopt::Long;
use Email::MIME;
use Email::Simple;
use File::Slurp;
use File::Spec;

sub generate_fingerprint {
    my ( $filename ) = @_;

    my $content = read_file($filename);
    my $email   = Email::Simple->new($content);

    my @headers = $email->header_names;
    my $body    = $email->body;

    @headers = grep {
        !/received/i
    } @headers;

    my $copy = Email::Simple->create(body => $body);

    foreach my $name ( sort @headers ) {
        my @values = $email->header($name);
        $copy->header_set($name, @values);
    }

    $copy->header_set(Date => undef);

    my $digest = Digest::SHA->new(1);
    $digest->add($copy->as_string);
    return $digest->hexdigest;
}

die "usage: $0 [-n] [directory]\n" unless @ARGV;

my $dry_run;

my $ok = GetOptions(
    'n' => \$dry_run,
);

exit unless $ok;

my ( $directory ) = @ARGV;

my @files = read_dir($directory);

my %seen_fingerprints;

foreach my $filename ( @files ) {
    $filename       = File::Spec->catfile($directory, $filename);
    my $fingerprint = generate_fingerprint($filename);

    if($seen_fingerprints{$fingerprint}) {
        if($dry_run) {
            say "deleting $filename";
        } else {
            unless(unlink $filename) {
                say STDERR "unable to delete $filename: $!";
            }
        }
    } else {
        $seen_fingerprints{$fingerprint} = 1;
    }
}
