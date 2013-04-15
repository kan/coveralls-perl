package Devel::Cover::Report::Coveralls;
use strict;
use warnings;
use 5.008005;
our $VERSION = "0.01";

our $CONFIG_FILE = '.coveralls.yml';
our $API_ENDPOINT = 'https://coveralls.io/api/v1/jobs';
our $SERVICE_NAME = 'coveralls-perl';

use Devel::Cover::DB;
use JSON::XS;
use YAML;
use Furl;
use Data::Dumper;

sub report {
    my ($pkg, $db, $options) = @_;

    my $cover = $db->cover;

    my @sfs;

    for my $file (@{$options->{file}}) {
        my $f = $cover->file($file);
        my $c = $f->statement();

        my $source = '';
        my @coverage;

        open F, $file or warn("Unable to open $file: $!\n"), return;

        while (defined(my $l = <F>)) {
            chomp $l;
            my $n = $.;

            $source .= "$l\n";
            my $l = $c->location($n);
            push @coverage, $l ? $l->[0]->covered : $l;
        }

        close(F);

        push @sfs, {
            name => $file,
            source => $source,
            coverage => \@coverage,
        };
    }

    my $config = {};
    if (-f $CONFIG_FILE) {
        $config = YAML::LoadFile($CONFIG_FILE);
    }

    my $json = {
        repo_token => $config->{repo_token} || '',
        source_files => \@sfs,
    };

    warn Dumper(\%ENV);

    my $is_travis;
    if ($ENV{TRAVIS}) {
        $is_travis = 1;
        $json->{service_name} = $config->{service_name} || 'travis-ci';
        $json->{service_job_id} = $ENV{TRAVIS_JOB_ID};
        $json->{repo_token} = $ENV{COVERALLS_REPO_TOKEN} if $ENV{COVERALLS_REPO_TOKEN};
    } else {
        $is_travis = 0;
        $json->{service_name} = $config->{service_name} || $SERVICE_NAME;
    }

    die "required repo_token in $CONFIG_FILE, or launch via Travis" if !$json->{repo_token} && !$is_travis;

    my $furl = Furl->new;
    my $response = $furl->post($API_ENDPOINT, [], [ json => encode_json $json ]);

    my $res = decode_json($response->content);
    if ($response->is_success) {
        print "register: " . $res->{url} . "\n";
    } else {
        print "error: " . $res->{message} . "\n";
    }
}


1;
__END__

=encoding utf-8

=head1 NAME

Devel::Cover::Report::Coveralls - It's new $module

=head1 SYNOPSIS

    use Devel::Cover::Report::Coveralls;

=head1 DESCRIPTION

Devel::Cover::Report::Coveralls is ...

=head1 LICENSE

Copyright (C) Kan Fushihara

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kan Fushihara E<lt>kan.fushihara@gmail.comE<gt>

