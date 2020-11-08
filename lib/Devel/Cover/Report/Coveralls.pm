package Devel::Cover::Report::Coveralls;
use strict;
use warnings;
use 5.008005;
our $VERSION = "0.20";

our $CONFIG_FILE = '.coveralls.yml';
our $API_ENDPOINT_STEM = '/api/v1/jobs';
our $API_ENDPOINT = 'https://coveralls.io';
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

    if ($ENV{GITHUB_REF} && $ENV{GITHUB_REF} =~ m![^/]+/[^/]+/(.+)$!) {
        $git->{branch} = $1;
    } elsif ($ENV{BUILD_SOURCEBRANCHNAME}) {
        $git->{branch} = $ENV{BUILD_SOURCEBRANCHNAME};
    }

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
    $json->{flag_name} = $ENV{COVERALLS_FLAG_NAME} if $ENV{COVERALLS_FLAG_NAME};

    my $is_travis;
    my $endpoint = ($ENV{COVERALLS_ENDPOINT} || $API_ENDPOINT) . $API_ENDPOINT_STEM;
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
    } elsif ($ENV{GITHUB_TOKEN}) {
        # from info as at 2020-11-07
        # https://github.com/coverallsapp/github-action/blob/master/src/run.ts
        # https://github.com/nickmerwin/node-coveralls/blob/master/lib/getOptions.js
        # we use GITHUB_TOKEN just to differentiate from still-working setup
        # in next option, but which requires a secret setting up
        $json->{service_name} = 'github';
        $json->{repo_token} = $ENV{GITHUB_TOKEN};
        $json->{service_job_id} = $ENV{GITHUB_RUN_ID};
        if (($ENV{GITHUB_EVENT_NAME}||'') eq 'pull_request') {
            if (open my $fh, '<:raw', $ENV{GITHUB_EVENT_PATH}) {
                local $/;
                my $text = <$fh>;
                my $pr = decode_json $text;
                if (my ($match) = ($pr->{number}||'') =~ /(\d+)$/) {
                    $json->{service_pull_request} = $match;
                }
            }
        }
    } elsif ($ENV{GITHUB_ACTIONS} && $ENV{GITHUB_SHA}) {
        $json->{service_name}   = 'github-actions';
        $json->{service_number} = substr($ENV{GITHUB_SHA}, 0, 9);
    } elsif ($ENV{SYSTEM_TEAMFOUNDATIONSERVERURI}) {
        $json->{service_name}   = 'azure-pipelines';
        $json->{service_number} = $ENV{BUILD_BUILDID};
    } else {
        $is_travis = 0;
        $json->{service_name} = $config->{service_name} || $SERVICE_NAME;
        $json->{service_event_type} = 'manual';
    }

    die "required repo_token in $CONFIG_FILE, or launch via Travis" if !$json->{repo_token} && !$is_travis;

    if (exists $ENV{COVERALLS_PERL_SERVICE_NAME} && $ENV{COVERALLS_PERL_SERVICE_NAME}) {
        $json->{service_name} = $ENV{COVERALLS_PERL_SERVICE_NAME};
    }

    return ($json, $endpoint);
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

    my ($json, $endpoint) = get_config();
    $json->{git} = eval { get_git_info() } || {};
    $json->{source_files} = \@sfs;

    my $response = HTTP::Tiny->new( verify_SSL => 1 )
        ->post_form( $endpoint, { json => encode_json $json } );

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

=head2 GitHub Actions

1. Add your repo to coveralls. L<https://coveralls.io/repos/new>

2. Add settings to one of your GitHub workflows. Here assuming you're
calling it F<.github/workflows/ci.yml>:

  jobs:
    ubuntu:
      runs-on: ${{ matrix.os }}
      strategy:
        fail-fast: false
        matrix:
          os: [ubuntu-latest]
          perl-version: ['5.10', '5.14', '5.20']
          include:
            - perl-version: '5.30'
              os: ubuntu-latest
              release-test: true
              coverage: true
      container: perl:${{ matrix.perl-version }}
      steps:
        - uses: actions/checkout@v2
        # do other stuff like installing external deps here
        - run: cpanm -n --installdeps .
        - run: perl -V
        - name: Run release tests # before others as may install useful stuff
          if: ${{ matrix.release-test }}
          env:
            RELEASE_TESTING: 1
          run: |
            cpanm -n --installdeps --with-develop .
            prove -lr xt
        - name: Run tests (no coverage)
          if: ${{ !matrix.coverage }}
          run: prove -l t
        - name: Run tests (with coverage)
          if: ${{ matrix.coverage }}
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          run: |
            cpanm -n Devel::Cover::Report::Coveralls
            cover -test -report Coveralls

3. Push new change to GitHub

4. Coveralls should update your project page

=head2 Travis CI

1. Add your repo to coveralls. L<https://coveralls.io/repos/new>

2. Add setting to F<.travis.yaml> (C<before_install> and C<script> section)

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

2. Write F<.coveralls.yml> (don't add this to public repo)

    repo_token: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

3. Run CI.

=head1 DESCRIPTION

L<https://coveralls.io/> is service to publish your coverage stats online with a lot of nice features. This module provides seamless integration with L<Devel::Cover> in your perl projects.

=head1 ENVIRONMENT

Set these environment variables to control the behaviour. Various other
variables, set by particular CI environments, will be interpreted silently
and correctly.

=head2 COVERALLS_REPO_TOKEN

The Coveralls authentication token for this particular repo.

=head2 COVERALLS_ENDPOINT

If you have an enterprise installation, set this to change from the
default of C<https://coveralls.io>. The rest of the URL (C</api>, etc)
won't change, and will be correct.

=head2 COVERALLS_FLAG_NAME

Describe the particular tests being done, e.g. C<Unit> or C<Functional>.

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

