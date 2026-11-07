use strict;
use warnings;
use utf8;
use Test::More;

use FindBin;
use Devel::Cover::Report::Coveralls;

my $normal_endpoint = 'https://coveralls.io/api/v1/jobs';
my $endpoint_stem = '/api/v1/jobs';

subtest 'get_config (travis)' => sub {
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{TRAVIS}        = 'true';
    local $ENV{TRAVIS_JOB_ID} = 100000;
    local $ENV{GITHUB_TOKEN} = undef;
    local $ENV{CIRCLECI} = undef;
    local $ENV{TRAVIS_PULL_REQUEST} = 'false';
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_job_id}, 100000, 'config service_job_id';
    is $got->{service_name}, 'travis-ci', 'config service_name';
    ok !exists $got->{service_pull_request},'not a pull request';
    local $ENV{TRAVIS_PULL_REQUEST} = '456';
    ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_pull_request},'456','config pull request';
    is $endpoint, $normal_endpoint, 'config endpoint';
};

subtest 'get_config extra env (travis)' => sub {
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{TRAVIS}        = 'true';
    local $ENV{TRAVIS_JOB_ID} = 100000;
    my $diff_endpoint = 'http://localhost';
    local $ENV{COVERALLS_ENDPOINT} = $diff_endpoint;
    local $ENV{COVERALLS_FLAG_NAME} = 'Unit';
    local $ENV{GITHUB_TOKEN} = undef;
    local $ENV{CIRCLECI} = undef;
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_job_id}, 100000, 'config service_job_id';
    is $got->{service_name}, 'travis-ci', 'config service_name';
    is $got->{flag_name}, 'Unit', 'config flag_name';
    is $endpoint, $diff_endpoint . $endpoint_stem, 'new endpoint';
};

subtest 'get_config github' => sub {
    local $ENV{TRAVIS}          = undef; # reset on travis
    local $ENV{DRONE}           = undef; # reset on drone
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{GITHUB_ACTIONS}  = 1;
    local $ENV{GITHUB_SHA}      = '123456789';
    local $ENV{GITHUB_TOKEN} = undef;
    local $ENV{CIRCLECI} = undef;
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_name}, 'github-actions', 'config service_name';
    is $got->{service_number}, '123456789', 'config service_number';
    is $endpoint, $normal_endpoint;
};

subtest 'get_config github actions improved' => sub {
    local $ENV{TRAVIS} = undef;
    local $ENV{DRONE} = undef; # reset on drone
    local $ENV{COVERALLS_REPO_TOKEN} = undef;
    local $ENV{GITHUB_TOKEN} = 'abcdef';
    local $ENV{GITHUB_RUN_ID} = '123456789';
    local $ENV{CIRCLECI} = undef;
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_name}, 'github', 'config service_name';
    is $got->{service_job_id}, '123456789', 'config service_job_id';
};

subtest 'get_config azure' => sub {
    local $ENV{TRAVIS}         = undef; # reset on travis
    local $ENV{GITHUB_ACTIONS} = undef; # reset on github
    local $ENV{GITHUB_REF}     = undef; # reset on github
    local $ENV{DRONE}           = undef; # reset on drone
    local $ENV{SYSTEM_TEAMFOUNDATIONSERVERURI} = 1;
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{BUILD_SOURCEBRANCHNAME} = 'feature';
    local $ENV{BUILD_BUILDID} = '123456789';
    local $ENV{GITHUB_TOKEN} = undef;
    local $ENV{CIRCLECI} = undef;
    
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_name}, 'azure-pipelines', 'config service_name';
    is $got->{service_number}, '123456789', 'config service_number';
    is $endpoint, $normal_endpoint;

    $got = Devel::Cover::Report::Coveralls::get_git_info();
    is $got->{branch}, 'feature', 'git branch';
};

subtest 'get_config drone' => sub {
    local $ENV{TRAVIS}         = undef; # reset on travis
    local $ENV{GITHUB_ACTIONS} = undef; # reset on github
    local $ENV{GITHUB_REF}     = undef; # reset on github
    local $ENV{CIRCLECI}       = undef;
    local $ENV{DRONE_PULL_REQUEST} = '666';
    local $ENV{DRONE_BUILD_NUMBER} = '123';
    local $ENV{DRONE} = "drone";
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';

    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_name}, 'drone', 'config service_name';
    is $got->{service_number}, '123', 'config service_number';
    is $got->{service_pull_request}, '666', 'config service_pull_request';
    is $endpoint, $normal_endpoint;
};

subtest 'get_config local' => sub {
    local $ENV{TRAVIS}         = undef; # reset on travis
    local $ENV{GITHUB_ACTIONS} = undef; # reset on github
    local $ENV{DRONE}           = undef; # reset on drone
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{GITHUB_TOKEN} = undef;
    local $ENV{CIRCLECI} = undef;
    
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_name}, 'coveralls-perl', 'config service_name';
    is $got->{service_event_type}, 'manual', 'config service_event_type';
    is $endpoint, $normal_endpoint;
};

subtest 'strip_url_credentials' => sub {
    my %cases = (
        'https://gitlab-ci-token:SECRET@gitlab.example.com/x/y.git' => 'https://gitlab.example.com/x/y.git',
        'https://user@github.com/x/y.git'                         => 'https://github.com/x/y.git',
        'https://user:p@ss@github.com/x/y.git'                    => 'https://github.com/x/y.git',
        'ssh://git@github.com/x/y.git'                            => 'ssh://github.com/x/y.git',
        'https://github.com/x/y.git'                              => 'https://github.com/x/y.git',
        'https://github.com/x/y@z.git'                            => 'https://github.com/x/y@z.git',
        'https://github.com?x=a@b'                                => 'https://github.com?x=a@b',
        'git@github.com:x/y.git'                                  => 'git@github.com:x/y.git',
        '/path/to/repo.git'                                       => '/path/to/repo.git',
    );
    for my $url (sort keys %cases) {
        is Devel::Cover::Report::Coveralls::strip_url_credentials($url), $cases{$url}, $url;
    }
};

subtest 'parse_git_remotes' => sub {
    my $text = join '', map { "$_\n" }
        "origin\thttps://gitlab-ci-token:SECRET\@gitlab.example.com/x/y.git (fetch)",
        "origin\thttps://gitlab-ci-token:SECRET\@gitlab.example.com/x/y.git (push)",
        "upstream\tgit\@github.com:x/y.git (fetch)",
        "upstream\tgit\@github.com:x/y.git (push)",
        "local\tC:/Users/John Doe/repo (fetch)\r",
        "local\tC:/Users/John Doe/repo (push)\r";

    is_deeply Devel::Cover::Report::Coveralls::parse_git_remotes($text), [
        { name => 'origin',   url => 'https://gitlab.example.com/x/y.git' },
        { name => 'upstream', url => 'git@github.com:x/y.git' },
        { name => 'local',    url => 'C:/Users/John Doe/repo' },
    ], 'one fetch URL per remote, without credentials';

    is_deeply Devel::Cover::Report::Coveralls::parse_git_remotes(''), [], 'no remotes';
    is_deeply Devel::Cover::Report::Coveralls::parse_git_remotes(undef), [], 'git not available';
};

subtest 'get_git_info remotes' => sub {
    my $inside = `git rev-parse --is-inside-work-tree 2>&1`;
    plan skip_all => 'not in a git work tree' unless defined $inside && $inside =~ /^true/;

    my @names = split /\n/, `git remote`;
    my $got = Devel::Cover::Report::Coveralls::get_git_info();
    is_deeply [ map { $_->{name} } @{ $got->{remotes} } ], \@names, 'every remote, once each';
};

subtest 'get_source' => sub {
    my $source = {
        name => "$FindBin::Bin/example.pl",
        source => <<EOS,
#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

print "hello, world";
EOS
        coverage => [undef, undef, undef, undef, undef, 0]
    };

    is_deeply Devel::Cover::Report::Coveralls::get_source("$FindBin::Bin/example.pl",
        sub { $_[0] == 6 ? 0 : undef } ), $source, 'source';
};

done_testing;
