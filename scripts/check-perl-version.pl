#!/usr/bin/env perl
# Checks that the Perl of the development container (the FROM line of Dockerfile) is the version
# used everywhere else that has to move with it (AGENTS.md, "テスト"). Dependabot updates only the
# Dockerfile; without this check, its pull request passes CI on the old version.
#
# Usage: perl scripts/check-perl-version.pl
use strict;
use warnings;
use FindBin;

# A version such as 5.44, without a trailing dot from the prose around it.
my $V = qr/[0-9]+(?:\.[0-9]+)*/;

chdir "$FindBin::Bin/.." or die "cannot chdir to the repository root: $!\n";

sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or die "cannot open $path: $!\n";
    local $/;
    return scalar <$fh>;
}

my ($want) = slurp('Dockerfile') =~ /^FROM\s+perl:($V)/m
    or die "Dockerfile: no FROM perl:<version> line\n";

my $compose = slurp('docker-compose.yml');
my $master  = slurp('.github/workflows/master.yml');
my $publish = slurp('.github/workflows/publish.yml');

# Each entry: where it is, and the versions found there. An empty list is an error too, so that a
# rewritten file does not pass by no longer matching.
my @found = (
    [ 'docker-compose.yml: the volume name (perl-local-<version>)',
        [ $compose =~ /perl-local-($V)/g ] ],
    [ 'master.yml: the newest perl-version of the perl matrix',
        [ newest(matrix_versions($master)) ] ],
    [ 'master.yml: the newest perl-version of the matrix include',
        [ newest($master =~ /^\s*-\s*perl-version:\s*["']?($V)["']?\s*$/mg) ] ],
    [ 'master.yml: the container image perl:<version> (dist)',
        [ $master =~ /^\s*image:\s*perl:($V)/mg ] ],
    [ 'publish.yml: perl-version passed to publish-cpan.yml',
        [ $publish =~ /^\s*perl-version:\s*["']?($V)["']?\s*$/mg ] ],
);

my @errors;
for my $entry (@found) {
    my ($where, $versions) = @$entry;
    if (!@$versions) {
        push @errors, "$where: not found";
        next;
    }
    for my $got (@$versions) {
        push @errors, "$where: $got" if $got ne $want;
    }
}

if (@errors) {
    print STDERR "The Perl of Dockerfile is $want, but:\n";
    print STDERR "  $_\n" for @errors;
    print STDERR "Update them in the same pull request (AGENTS.md, \"テスト\").\n";
    exit 1;
}
print "Perl $want everywhere\n";

# The block list under a `perl-version:` line with no value (the matrix of the perl job). Blank
# lines and comments inside the list are skipped; the first other line ends it.
sub matrix_versions {
    my ($yaml) = @_;
    my ($in_list, @versions);
    for my $line (split /\n/, $yaml) {
        if (!$in_list) {
            $in_list = $line =~ /^\s*perl-version:\s*$/;
            next;
        }
        next if $line =~ /^\s*(?:#.*)?$/;
        if ($line =~ /^\s*-\s*["']?($V)["']?\s*$/) {
            push @versions, $1;
            next;
        }
        last;
    }
    return @versions;
}

sub newest {
    my @sorted = sort { version_cmp($a, $b) } @_;
    return @sorted ? $sorted[-1] : ();
}

sub version_cmp {
    my @a = split /\./, $_[0];
    my @b = split /\./, $_[1];
    while (@a || @b) {
        my $c = (shift(@a) // 0) <=> (shift(@b) // 0);
        return $c if $c;
    }
    return 0;
}
