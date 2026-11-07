package Devel::Cover::Report::Coveralls;
use strict;
use warnings;
use 5.020;
our $VERSION = "0.32.1";

our $CONFIG_FILE = '.coveralls.yml';
our $API_ENDPOINT_STEM = '/api/v1/jobs';
our $API_ENDPOINT = 'https://coveralls.io';
our $SERVICE_NAME = 'coveralls-perl';

use Devel::Cover::DB;
use HTTP::Tiny;
use JSON::PP;
use YAML;
use Data::Dumper;

sub get_source {
    my ($file, $callback) = @_;

    my $source = '';
    my @coverage;

    open my $fh, '<', $file or warn("Unable to open $file: $!\n"), return;

    while (defined(my $l = <$fh>)) {
        chomp $l;
        my $n = $.;

        $source .= "$l\n";
        push @coverage, $callback->($n);
    }

    close($fh);

    $file =~ s!^blib/!!;

    return +{
        name => $file,
        source => $source,
        coverage => \@coverage,
    };
}

sub git_log {
    my $format = shift;

    my $text = '';

    # No quotes around the format: cmd.exe on Windows does not take single quotes as quotes, so git
    # would print them. The formats used here have no spaces and no characters a shell changes.
    my $command = "git log -1 --encoding=UTF-8 --pretty=format:$format";
    if (open(my $fh, '-|:encoding(UTF-8)', $command)) {
        $text = do { local $/; <$fh> };
        close $fh;
    }

    return $text;
}

# Turn the output of `git remote -v` into the list of remotes to send.
# Each remote is listed once (its fetch URL), and credentials are removed
# from the URL.
sub parse_git_remotes {
    my $text = shift;

    my @remotes;
    for my $line (split /\n/, defined $text ? $text : '') {
        # "<name>\t<url> (fetch)". The URL may contain spaces (a local path).
        next unless $line =~ /^(\S+)\t(.*) \(fetch\)\r?$/;
        push @remotes, +{ name => $1, url => strip_url_credentials($2) };
    }

    return \@remotes;
}

# Remove the user information from a URL with a scheme
# (https://user:pass@host/path -> https://host/path).
# scp-like URLs (git@host:path) cannot hold a password and are kept as they are.
sub strip_url_credentials {
    my $url = shift;
    $url =~ s!^([A-Za-z][A-Za-z0-9+.-]*://)[^/?#]*@!$1!;
    return $url;
}

sub get_git_info {
    my $git = {
        head => {
            id              => git_log('%H'),
            author_name     => git_log('%aN'),
            author_email    => git_log('%ae'),
            committer_name  => git_log('%cN'),
            committer_email => git_log('%ce'),
            message         => git_log('%s')
        },
        remotes => parse_git_remotes(scalar `git remote -v`),
    };
    my ($branch,) = grep { /^\* / } split( "\n", `git branch` );
    $branch =~ s/^\* //;
    $git->{branch} = $branch;

    if ($ENV{BUILD_SOURCEBRANCHNAME}) {
        $git->{branch} = $ENV{BUILD_SOURCEBRANCHNAME};
    }

    return $git;
}

# A switch in an environment variable (COVERALLS_PARALLEL, COVERALLS_NO_FAIL) is on unless it is
# unset, empty, "false" or "0", as COVERALLS_PARALLEL is in the official coverage-reporter.
sub is_enabled {
    my $value = shift;
    return defined $value && $value ne '' && $value ne 'false' && $value ne '0';
}

# Reads the response of the jobs API (an HTTP::Tiny response). Returns the URL of the job, or
# undef and the error to show.
sub parse_response {
    my $response = shift;
    my $content = $response->{content} // '';
    my $res = eval { decode_json $content };
    my $status = "$response->{status} $response->{reason}";
    if (!$res || ref $res ne 'HASH') {
        # HTTP::Tiny puts its own error (e.g. a failed connection) into the content, with status 599.
        # An error page from a proxy can be long, so only its start is shown.
        $content =~ s/\s+\z//;
        $content = substr($content, 0, 200) . '...' if length $content > 200;
        return (undef, "$status: $content");
    }
    # A job that was registered always has its URL.
    return ($res->{url}, undef) if $response->{success} && $res->{url};
    return (undef, $res->{message} || $status);
}

# The number of the pull request in the event payload of GitHub Actions, or undef.
sub github_event_pull_request {
    my $path = shift;
    return undef unless $path;
    open my $fh, '<:raw', $path or return undef;
    my $event = eval { local $/; decode_json scalar <$fh> } or return undef;
    my $number = ref $event->{pull_request} eq 'HASH' && $event->{pull_request}{number};
    return $number && $number =~ /^\d+$/ ? $number : undef;
}

# Put the branch and the commit that the CI service gave (get_config) into the
# git information, over what git itself says.
sub apply_ci_git_info {
    my ($json, $git) = @_;
    $git->{branch} = $json->{service_branch} if defined $json->{service_branch};
    $git->{head}{id} = $json->{commit_sha} if defined $json->{commit_sha};
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
    $json->{parallel} = \1 if is_enabled($ENV{COVERALLS_PARALLEL});

    my $endpoint = ($ENV{COVERALLS_ENDPOINT} || $API_ENDPOINT) . $API_ENDPOINT_STEM;
    if ($ENV{TRAVIS}) {
        $json->{service_name} = $config->{service_name} || 'travis-ci';
        $json->{service_job_id} = $ENV{TRAVIS_JOB_ID};
        if($ENV{TRAVIS_PULL_REQUEST} && $ENV{TRAVIS_PULL_REQUEST} ne 'false'){
            $json->{service_pull_request} = $ENV{TRAVIS_PULL_REQUEST};
        }
    } elsif ($ENV{CIRCLECI}) {
        $json->{service_name} = 'circleci';
        $json->{service_number} = $ENV{CIRCLE_WORKFLOW_ID};
        # The URL of the pull request; its number is at the end. CI_PULL_REQUEST is the older name.
        if (($ENV{CIRCLE_PULL_REQUEST} || $ENV{CI_PULL_REQUEST} // '') =~ /(\d+)$/) {
            $json->{service_pull_request} = $1;
        }
        $json->{service_branch} = $ENV{CIRCLE_BRANCH} if $ENV{CIRCLE_BRANCH};
        $json->{commit_sha} = $ENV{CIRCLE_SHA1} if $ENV{CIRCLE_SHA1};
    } elsif($ENV{DRONE}) {
        $json->{service_name} = 'drone';
        $json->{service_number} = $ENV{DRONE_BUILD_NUMBER};
        $json->{service_pull_request} = $ENV{DRONE_PULL_REQUEST} if $ENV{DRONE_PULL_REQUEST};
    } elsif ($ENV{SEMAPHORE}) {
        $json->{service_name} = 'semaphore';
        $json->{service_number} = $ENV{SEMAPHORE_BUILD_NUMBER} if $ENV{SEMAPHORE_BUILD_NUMBER};
        # Also support semaphore 2.x
        $json->{service_number} = $ENV{SEMAPHORE_WORKFLOW_ID} if $ENV{SEMAPHORE_WORKFLOW_ID};
        $json->{service_pull_request} = $ENV{SEMAPHORE_GIT_PR_NUMBER} if $ENV{SEMAPHORE_GIT_PR_NUMBER};
    } elsif ($ENV{JENKINS_URL}) {
        $json->{service_name} = 'jenkins';
        $json->{service_number} = $ENV{BUILD_NUMBER} if $ENV{BUILD_NUMBER};
        $json->{service_job_id} = $ENV{BUILD_ID} if $ENV{BUILD_ID};
        # Set by multibranch pipelines. In a pull request build, BRANCH_NAME is "PR-<number>" and
        # CHANGE_BRANCH is the source branch, so CHANGE_BRANCH comes first.
        my $branch = $ENV{CHANGE_BRANCH} || $ENV{BRANCH_NAME};
        $json->{service_branch} = $branch if $branch;
        $json->{service_pull_request} = $ENV{CHANGE_ID} if $ENV{CHANGE_ID};
    } elsif ($ENV{GITLAB_CI}) {
        $json->{service_name} = 'gitlab-ci';
        $json->{service_number} = $ENV{CI_PIPELINE_IID} if $ENV{CI_PIPELINE_IID};
        $json->{service_job_id} = $ENV{CI_JOB_NAME} if $ENV{CI_JOB_NAME};
        $json->{service_pull_request} = $ENV{CI_MERGE_REQUEST_IID} if $ENV{CI_MERGE_REQUEST_IID};
        $json->{service_branch} = $ENV{CI_COMMIT_REF_NAME} if $ENV{CI_COMMIT_REF_NAME};
        $json->{commit_sha} = $ENV{CI_COMMIT_SHA} if $ENV{CI_COMMIT_SHA};
    } elsif ($ENV{TF_BUILD} || $ENV{SYSTEM_TEAMFOUNDATIONSERVERURI}) {
        $json->{service_name}   = 'azure-pipelines';
        $json->{service_number} = $ENV{BUILD_BUILDID};
        $json->{service_pull_request} = $ENV{SYSTEM_PULLREQUEST_PULLREQUESTNUMBER}
            if $ENV{SYSTEM_PULLREQUEST_PULLREQUESTNUMBER};
        $json->{commit_sha} = $ENV{BUILD_SOURCEVERSION} if $ENV{BUILD_SOURCEVERSION};
    } elsif ($ENV{GITHUB_ACTIONS}) {
        # The values of the official coverage-reporter (src/coverage_reporter/ci/github.cr).
        $json->{service_name} = 'github';
        # Coveralls accepts the GITHUB_TOKEN of the workflow in place of the repo token.
        $json->{repo_token} ||= $ENV{GITHUB_TOKEN};
        # The run groups the jobs of a parallel build, and the "done" webhook names it.
        $json->{service_number} = $ENV{GITHUB_RUN_ID} if $ENV{GITHUB_RUN_ID};
        $json->{service_attempt} = $ENV{GITHUB_RUN_ATTEMPT} if $ENV{GITHUB_RUN_ATTEMPT};
        if ($ENV{GITHUB_JOB}) {
            # Every leg of a matrix has the same GITHUB_JOB; the flag name tells them apart.
            $json->{service_job_id} = $ENV{COVERALLS_FLAG_NAME}
                ? "$ENV{GITHUB_JOB}-$ENV{COVERALLS_FLAG_NAME}" : $ENV{GITHUB_JOB};
        }
        my $ref = $ENV{GITHUB_REF} // '';
        if ($ref =~ m!^refs/pull/(\d+)/!) {
            $json->{service_pull_request} = $1;
        } elsif (my $number = github_event_pull_request($ENV{GITHUB_EVENT_PATH})) {
            # pull_request_target runs on the base branch, so GITHUB_REF is not refs/pull/.
            $json->{service_pull_request} = $number;
        }
        # GITHUB_HEAD_REF is the source branch of a pull request; GITHUB_REF_NAME is "<number>/merge"
        # there. Older runners do not set GITHUB_REF_NAME.
        my ($from_ref) = $ref =~ m!^refs/(?:heads|tags)/(.+)$!;
        my $branch = $ENV{GITHUB_HEAD_REF} || $ENV{GITHUB_REF_NAME} || $from_ref;
        $json->{service_branch} = $branch if $branch;
        $json->{commit_sha} = $ENV{GITHUB_SHA} if $ENV{GITHUB_SHA};
    } else {
        $json->{service_name} = $config->{service_name} || $SERVICE_NAME;
        $json->{service_event_type} = 'manual';
    }

    # Coveralls requires the token on every CI service, Travis CI included.
    die "required repo_token in $CONFIG_FILE, make sure the environment var \"COVERALLS_REPO_TOKEN\" is set" if !$json->{repo_token};

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

    my ($json, $endpoint) = eval { get_config() };
    if (!$json) {
        # No repo token, which happens on pull requests from forks: they get no secrets.
        die $@ unless is_enabled($ENV{COVERALLS_NO_FAIL});
        print "- Report::Coveralls --------\nerror: $@----------------------------\n";
        return;
    }
    $json->{git} = apply_ci_git_info($json, eval { get_git_info() } || {});
    $json->{source_files} = \@sfs;

    my $coder = JSON::PP->new->ascii;

    my $response = HTTP::Tiny->new( verify_SSL => 1 )
        ->post_form( $endpoint, { json => $coder->encode($json) } );

    my ($url, $error) = parse_response($response);

    print("- Report::Coveralls --------\n");
    if(exists($json->{service_number})){
        print "My build number: ". $json->{service_number} ."\n";
    }
    if (defined $error) {
        print "error: $error\n";
    } else {
        print "register: $url\n";
    }
    if($json->{parallel}){
        print "Parallel mode: True". "\n"
    }
    print("----------------------------\n");

    # cover does not catch this, so it exits with a non-zero status and the CI job fails.
    die "The upload to Coveralls failed. Set COVERALLS_NO_FAIL=1 to exit 0 instead.\n"
        if defined $error && !is_enabled($ENV{COVERALLS_NO_FAIL});
}


1;
__END__

=encoding utf-8

=head1 NAME

Devel::Cover::Report::Coveralls - coveralls backend for Devel::Cover

=head1 USAGE

=head2 GitHub Actions

1. Add your repo to Coveralls. L<https://coveralls.io/repos/new>

2. Add a workflow, e.g. F<.github/workflows/test.yml>. The C<GITHUB_TOKEN> of the workflow is
enough to send the report; you do not need the repo token of Coveralls.

  name: test
  on: [push, pull_request]
  jobs:
    test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v7
        - uses: shogo82148/actions-setup-perl@v1
          with:
            perl-version: '5.42'
        - run: cpanm -n --installdeps .
        - run: cpanm -n Devel::Cover::Report::Coveralls
        - run: cover -test -report coveralls
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

3. Push the change to GitHub. Coveralls shows the build, and on a pull request it reports the
coverage back to the pull request.

To send the coverage of several jobs (a matrix) as one build, mark each job as parallel, give
each its own flag name, and close the build when all of them are done. The build is the run of
the workflow, so the jobs and the closing step agree on it without any setting.

  jobs:
    test:
      runs-on: ubuntu-latest
      strategy:
        fail-fast: false
        matrix:
          perl-version: ['5.20', '5.30', '5.42']
      steps:
        - uses: actions/checkout@v7
        - uses: shogo82148/actions-setup-perl@v1
          with:
            perl-version: ${{ matrix.perl-version }}
        - run: cpanm -n --installdeps .
        - run: cpanm -n Devel::Cover::Report::Coveralls
        - run: cover -test -report coveralls
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
            COVERALLS_PARALLEL: true
            COVERALLS_FLAG_NAME: perl-${{ matrix.perl-version }}
    finish:
      needs: test
      if: ${{ always() }}
      runs-on: ubuntu-latest
      steps:
        - uses: coverallsapp/github-action@v2
          with:
            parallel-finished: true

=head2 Travis CI

1. Add your repo to Coveralls. L<https://coveralls.io/repos/new>

2. In the settings of your repository on Travis CI, set the environment variable
C<COVERALLS_REPO_TOKEN> to the repo token shown on your project page in Coveralls.

3. Add the settings to F<.travis.yml>:

    language: perl
    perl:
      - "5.30"
    before_install:
      - cpanm -n Devel::Cover::Report::Coveralls
    script:
      - perl Build.PL && ./Build build && cover -test -report coveralls

4. Push the change. Coveralls shows the build.

=head2 Other CI services

GitLab CI, CircleCI, Jenkins, Azure Pipelines, Drone and Semaphore are detected from their
environment variables, and the build number, branch, commit and pull request they give are sent.

1. Get the repo token from your project page in Coveralls.

2. Give it to the job as C<COVERALLS_REPO_TOKEN>, as a secret variable of the CI service.
Or write it in F<.coveralls.yml> in the directory you run C<cover> from, and do not commit
that file to a public repository:

    repo_token: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

3. Run C<cover -test -report coveralls> in the job.

=head2 When the report cannot be sent

C<cover -report coveralls> prints the error and exits with a non-zero status, so the job fails.
To keep the job green, e.g. on pull requests from forks, which get no secrets, set
L</COVERALLS_NO_FAIL>.

=head1 DESCRIPTION

L<https://coveralls.io/> is service to publish your coverage stats online with a lot of nice features. This module provides seamless integration with L<Devel::Cover> in your perl projects.

=head1 ENVIRONMENT

Set these environment variables to control the behaviour. Various other
variables, set by particular CI environments, will be interpreted silently
and correctly.

=head2 COVERALLS_REPO_TOKEN

The Coveralls authentication token for this particular repo. It is used before C<repo_token>
in F<.coveralls.yml>. On GitHub Actions, C<GITHUB_TOKEN> is used when neither is set.

=head2 COVERALLS_ENDPOINT

If you have an enterprise installation, set this to change from the
default of C<https://coveralls.io>. The rest of the URL (C</api>, etc)
won't change, and will be correct.

=head2 COVERALLS_FLAG_NAME

Describe the particular tests being done, e.g. C<Unit> or C<Functional>.
On GitHub Actions it is also added to the job ID, so give each leg of a matrix that reports
to the same parallel build its own flag name.

=head2 COVERALLS_PARALLEL

Set this to C<true> when several jobs send their coverage to one build. Any value other than
empty, C<false> and C<0> turns it on. Coveralls then keeps the build open until the parallel
build webhook is called, so call it when all the jobs are done. The jobs must send the same build
number; the CI services above give one per run (on GitHub Actions, the run of the workflow).

See L<https://docs.coveralls.io/api-parallel-build-webhook>

=head2 COVERALLS_NO_FAIL

When the report cannot be sent to Coveralls (the upload fails, or there is no repo token),
C<cover -report coveralls> prints the error and exits with a non-zero status, so that the CI
job fails. Set this to C<true> to exit 0 instead, e.g. when coverage is optional for the build or
pull requests from forks get no repo token. When C<cover> makes several reports, the ones after
C<coveralls> are not made after a failure, so put C<coveralls> last. Any value other than empty, C<false> and C<0> turns it on.

=head2 COVERALLS_PERL_SERVICE_NAME

Sends this as the name of the CI service, in place of the one detected (e.g. C<github>).

=head1 SEE ALSO

L<https://coveralls.io/>
L<https://docs.coveralls.io/>
L<https://github.com/coagulant/coveralls-python>
L<Devel::Cover>

=head2 EXAMPLE

L<https://coveralls.io/github/kan/coveralls-perl>

=head1 LICENSE

Copyright (C) Kan Fushihara

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kan Fushihara E<lt>kan.fushihara@gmail.comE<gt>
