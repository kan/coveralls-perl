package Devel::Cover::Report::Coveralls;
use strict;
use warnings;
use 5.008005;
our $VERSION = "0.11";

our $CONFIG_FILE = '.coveralls.yml';
our $API_ENDPOINT = 'https://coveralls.io/api/v1/jobs';
our $SERVICE_NAME = 'coveralls-perl';

use Devel::Cover::DB;
use HTTP::Tiny;
use JSON::PP;
use YAML;

sub get_source {
    my ($file, $callback) = @_;

    my $source = '';
    my @coverage;

    open F, $file or warn("Unable to open $file: $!\n"), return;

    while (defined(my $l = <F>)) {
        chomp $l;
        my $n = $.;

        $source .= "$l\n";
        push @coverage, $callback->($n);
    }

    close(F);

    $file =~ s!^blib/!!;

    return +{
        name => $file,
        source => $source,
        coverage => \@coverage,
    };
}

sub get_git_info {
    my $git = {
        head => {
            id              => `git log -1 --pretty=format:'%H'`,
            author_name     => `git log -1 --pretty=format:'%aN'`,
            author_email    => `git log -1 --pretty=format:'%ae'`,
            committer_name  => `git log -1 --pretty=format:'%cN'`,
            committer_email => `git log -1 --pretty=format:'%ce'`,
            message         => `git log -1 --pretty=format:'%s'`
        },
        remotes => [
              map {
                  my ( $name, $url ) = split( " ", $_ );
                  +{ name => $name, url => $url }
              } split( "\n", `git remote -v` )
        ],
    };
    my ($branch,) = grep { /^\* / } split( "\n", `git branch` );
    $branch =~ s/^\* //;
    $git->{branch} = $branch;

    return $git;
}

sub get_config {
    my $config = {};
    if (-f $CONFIG_FILE) {
        $config = YAML::LoadFile($CONFIG_FILE);
    }

    my $json = {};
    $json->{repo_token} = $config->{repo_token} if $config->{repo_token};
    $json->{repo_token} = $ENV{COVERALLS_REPO_TOKEN} if $ENV{COVERALLS_REPO_TOKEN};

    my $is_travis;
    if ($ENV{TRAVIS}) {
        $is_travis = 1;
        $json->{service_name} = $config->{service_name} || 'travis-ci';
        $json->{service_job_id} = $ENV{TRAVIS_JOB_ID};
    } elsif ($ENV{CIRCLECI}) {
        $json->{service_name} = 'circleci';
        $json->{service_number} = $ENV{CIRCLE_BUILD_NUM};
    } elsif ($ENV{SEMAPHORE}) {
        $json->{service_name} = 'semaphore';
        $json->{service_number} = $ENV{SEMAPHORE_BUILD_NUMBER};
    } elsif ($ENV{JENKINS_URL}) {
        $json->{service_name} = 'jenkins';
        $json->{service_number} = $ENV{BUILD_NUM};
    } else {
        $is_travis = 0;
        $json->{service_name} = $config->{service_name} || $SERVICE_NAME;
        $json->{service_event_type} = 'manual';
    }

    die "required repo_token in $CONFIG_FILE, or launch via Travis" if !$json->{repo_token} && !$is_travis;

    return $json;
}

sub _parse_line ($) {
    my $c = shift;

    return sub {
        my $l = $c->location(shift);

        return $l unless $l;

        if ($l->[0]->uncoverable) {
            return undef;
        } else {
            return $l->[0]->covered;
        }
    };
}

sub report {
    my ($pkg, $db, $options) = @_;

    my $cover = $db->cover;

    my @sfs;

    for my $file (@{$options->{file}}) {
        my $f = $cover->file($file);
        my $c = $f->statement();

        push @sfs, get_source( $file, _parse_line $c );
    }

    my $json = get_config();
    $json->{git} = eval { get_git_info() } || {};
    $json->{source_files} = \@sfs;

    my $response = HTTP::Tiny->new( verify_SSL => 1 )
        ->post_form( $API_ENDPOINT, { json => encode_json $json } );

    my $res = eval { decode_json $response->{content} };

    if ($@) {
        print "error: " . $response->{content};
    } elsif ($response->{success}) {
        print "register: " . $res->{url} . "\n";
    } else {
        print "error: " . $res->{message} . "\n";
    }
}


1;
__END__

=encoding utf-8

=head1 NAME

Devel::Cover::Report::Coveralls - coveralls backend for Devel::Cover

=head1 USAGE

=head2 Travis CI

1. Add your repo to coveralls. https://coveralls.io/repos/new

2. Add setting to .travis.yaml (before_install and script section)

    language: perl
    perl:
      - 5.16.3
      - 5.14.4
    before_install:
      cpanm -n Devel::Cover::Report::Coveralls
    script:
      perl Build.PL && ./Build build && cover -test -report coveralls

3. push new change to github

4. updated coveralls your project page

=begin html

<img src="http://kan.github.io/images/p5-ltsv.png" />

=end html

=head2 another CI

1. Get repo_token from your project page in coveralls.

2. Write .coveralls.yml (don't add this to public repo)

    repo_token: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

3. Run CI.

=head1 DESCRIPTION

L<https://coveralls.io/> is service to publish your coverage stats online with a lot of nice features. This module provides seamless integration with L<Devel::Cover> in your perl projects.

=head1 SEE ALSO

L<https://coveralls.io/>
L<https://coveralls.io/docs>
L<https://github.com/coagulant/coveralls-python>
L<Devel::Cover>

=head2 EXAMPLE

L<https://coveralls.io/r/kan/p5-smart-options>

=head1 LICENSE

Copyright (C) Kan Fushihara

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kan Fushihara E<lt>kan.fushihara@gmail.comE<gt>

