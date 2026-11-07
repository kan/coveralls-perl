use strict;
use warnings;
use utf8;
use Test::More;

use FindBin;
use File::Temp ();
use Devel::Cover::Report::Coveralls;

my $normal_endpoint = 'https://coveralls.io/api/v1/jobs';
my $endpoint_stem = '/api/v1/jobs';

# The variables that get_config and get_git_info read to pick the CI service, or the values for it.
# Every get_config subtest clears them all with `local @ENV{@CI_VARS}`, so that the CI running the
# tests does not leak in.
my @CI_VARS = qw(
    TRAVIS TRAVIS_JOB_ID TRAVIS_PULL_REQUEST
    CIRCLECI CIRCLE_WORKFLOW_ID CIRCLE_PULL_REQUEST CI_PULL_REQUEST CIRCLE_BRANCH CIRCLE_SHA1
    DRONE DRONE_BUILD_NUMBER DRONE_PULL_REQUEST
    SEMAPHORE SEMAPHORE_BUILD_NUMBER SEMAPHORE_WORKFLOW_ID SEMAPHORE_GIT_PR_NUMBER
    JENKINS_URL BUILD_NUMBER BUILD_ID BRANCH_NAME CHANGE_BRANCH CHANGE_ID
    GITLAB_CI CI_PIPELINE_IID CI_JOB_NAME CI_MERGE_REQUEST_IID CI_COMMIT_REF_NAME CI_COMMIT_SHA
    TF_BUILD SYSTEM_TEAMFOUNDATIONSERVERURI BUILD_BUILDID SYSTEM_PULLREQUEST_PULLREQUESTNUMBER
    BUILD_SOURCEVERSION BUILD_SOURCEBRANCHNAME
    GITHUB_ACTIONS GITHUB_TOKEN GITHUB_RUN_ID GITHUB_RUN_ATTEMPT GITHUB_JOB GITHUB_SHA
    GITHUB_REF GITHUB_REF_NAME GITHUB_HEAD_REF GITHUB_EVENT_PATH
    COVERALLS_REPO_TOKEN COVERALLS_ENDPOINT COVERALLS_FLAG_NAME COVERALLS_PARALLEL
    COVERALLS_PERL_SERVICE_NAME COVERALLS_NO_FAIL
);

subtest 'get_config (travis)' => sub {
    local @ENV{@CI_VARS};
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{TRAVIS}        = 'true';
    local $ENV{TRAVIS_JOB_ID} = 100000;
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
    local @ENV{@CI_VARS};
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{TRAVIS}        = 'true';
    local $ENV{TRAVIS_JOB_ID} = 100000;
    my $diff_endpoint = 'http://localhost';
    local $ENV{COVERALLS_ENDPOINT} = $diff_endpoint;
    local $ENV{COVERALLS_FLAG_NAME} = 'Unit';
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_job_id}, 100000, 'config service_job_id';
    is $got->{service_name}, 'travis-ci', 'config service_name';
    is $got->{flag_name}, 'Unit', 'config flag_name';
    is $endpoint, $diff_endpoint . $endpoint_stem, 'new endpoint';
};

subtest 'get_config github actions (push)' => sub {
    local @ENV{@CI_VARS};
    local $ENV{GITHUB_ACTIONS} = 'true';
    local $ENV{GITHUB_TOKEN} = 'from-github';
    local $ENV{GITHUB_RUN_ID} = '123456789';
    local $ENV{GITHUB_RUN_ATTEMPT} = '2';
    local $ENV{GITHUB_JOB} = 'test';
    local $ENV{GITHUB_SHA} = 'abc123';
    local $ENV{GITHUB_REF} = 'refs/heads/master';
    local $ENV{GITHUB_REF_NAME} = 'master';
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_name}, 'github', 'service_name';
    is $got->{repo_token}, 'from-github', 'GITHUB_TOKEN without COVERALLS_REPO_TOKEN';
    is $got->{service_number}, '123456789', 'service_number is the run';
    is $got->{service_attempt}, '2', 'service_attempt';
    is $got->{service_job_id}, 'test', 'service_job_id is the job';
    is $got->{service_branch}, 'master', 'service_branch';
    is $got->{commit_sha}, 'abc123', 'commit_sha';
    ok !exists $got->{service_pull_request}, 'not a pull request';
    is $endpoint, $normal_endpoint;

    local $ENV{COVERALLS_REPO_TOKEN} = 'from-coveralls';
    local $ENV{COVERALLS_FLAG_NAME} = 'perl-5.20';
    ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{repo_token}, 'from-coveralls', 'COVERALLS_REPO_TOKEN first';
    is $got->{service_job_id}, 'test-perl-5.20', 'the flag name tells the legs of a matrix apart';
};

subtest 'get_config github actions (pull request)' => sub {
    local @ENV{@CI_VARS};
    local $ENV{GITHUB_ACTIONS} = 'true';
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{GITHUB_REF} = 'refs/pull/49/merge';
    local $ENV{GITHUB_REF_NAME} = '49/merge';
    local $ENV{GITHUB_HEAD_REF} = 'feature';
    my ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_pull_request}, '49', 'service_pull_request from GITHUB_REF';
    is $got->{service_branch}, 'feature', 'the source branch, not 49/merge';
    ok !exists $got->{service_job_id}, 'no service_job_id without GITHUB_JOB';

    local $ENV{COVERALLS_FLAG_NAME} = 'unit';
    ($got) = Devel::Cover::Report::Coveralls::get_config();
    ok !exists $got->{service_job_id}, 'nor with only the flag name';
};

subtest 'get_config github actions (pull_request_target)' => sub {
    local @ENV{@CI_VARS};
    local $ENV{GITHUB_ACTIONS} = 'true';
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{GITHUB_REF} = 'refs/heads/master';
    local $ENV{GITHUB_HEAD_REF} = 'feature';
    local $ENV{GITHUB_EVENT_PATH} = "$FindBin::Bin/no-such-event.json";
    my ($got) = Devel::Cover::Report::Coveralls::get_config();
    ok !exists $got->{service_pull_request}, 'no number without an event file';

    my $dir = File::Temp::tempdir(CLEANUP => 1);
    my $event = "$dir/event.json";
    open my $fh, '>', $event or die $!;
    print $fh '{"pull_request":{"number":12}}';
    close $fh;
    local $ENV{GITHUB_EVENT_PATH} = $event;
    ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_pull_request}, '12', 'the number from the event payload';
    is $got->{service_branch}, 'feature', 'service_branch';
};

subtest 'get_config github actions (older runner)' => sub {
    local @ENV{@CI_VARS};
    local $ENV{GITHUB_ACTIONS} = 'true';
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{GITHUB_REF} = 'refs/heads/release/1.0';
    my ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_branch}, 'release/1.0', 'the branch from GITHUB_REF without GITHUB_REF_NAME';
};

subtest 'GITHUB_TOKEN alone is not GitHub Actions' => sub {
    local @ENV{@CI_VARS};
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{GITHUB_TOKEN} = 'set for another tool';
    my ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_name}, 'coveralls-perl', 'service_name';
    is $got->{repo_token}, 'abcdef', 'the token is not GITHUB_TOKEN';
};

subtest 'get_config azure' => sub {
    local @ENV{@CI_VARS};
    local $ENV{SYSTEM_TEAMFOUNDATIONSERVERURI} = 1;
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{BUILD_SOURCEBRANCHNAME} = 'feature';
    local $ENV{BUILD_BUILDID} = '123456789';

    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_name}, 'azure-pipelines', 'config service_name';
    is $got->{service_number}, '123456789', 'config service_number';
    is $endpoint, $normal_endpoint;

    $got = Devel::Cover::Report::Coveralls::get_git_info();
    is $got->{branch}, 'feature', 'git branch';
};

subtest 'get_config drone' => sub {
    local @ENV{@CI_VARS};
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
    local @ENV{@CI_VARS};
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';

    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_name}, 'coveralls-perl', 'config service_name';
    is $got->{service_event_type}, 'manual', 'config service_event_type';
    is $endpoint, $normal_endpoint;
};

subtest 'get_config travis requires repo_token' => sub {
    local @ENV{@CI_VARS};
    local $ENV{TRAVIS} = 'true';
    ok !eval { Devel::Cover::Report::Coveralls::get_config(); 1 }, 'dies without a token';
    like $@, qr/COVERALLS_REPO_TOKEN/, 'says which variable to set';
};

subtest 'get_config circleci' => sub {
    local @ENV{@CI_VARS};
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{CIRCLECI} = 'true';
    local $ENV{CIRCLE_WORKFLOW_ID} = 'wf-1';
    local $ENV{CI_PULL_REQUEST} = 'https://github.com/kan/coveralls-perl/pull/42';
    local $ENV{CIRCLE_BRANCH} = 'feature';
    local $ENV{CIRCLE_SHA1} = 'abc123';
    my ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_name}, 'circleci', 'service_name';
    is $got->{service_number}, 'wf-1', 'service_number';
    is $got->{service_pull_request}, '42', 'the number at the end of the pull request URL';
    is $got->{service_branch}, 'feature', 'service_branch';
    is $got->{commit_sha}, 'abc123', 'commit_sha';

    local $ENV{CIRCLE_PULL_REQUEST} = 'https://github.com/kan/coveralls-perl/pull/43';
    ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_pull_request}, '43', 'CIRCLE_PULL_REQUEST first';
};

subtest 'get_config jenkins' => sub {
    local @ENV{@CI_VARS};
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{JENKINS_URL} = 'https://jenkins.example.com/';
    local $ENV{BUILD_NUMBER} = '17';
    local $ENV{BUILD_ID} = '17';
    local $ENV{BRANCH_NAME} = 'PR-9';
    local $ENV{CHANGE_BRANCH} = 'feature';
    local $ENV{CHANGE_ID} = '9';
    my ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_name}, 'jenkins', 'service_name';
    is $got->{service_number}, '17', 'service_number from BUILD_NUMBER';
    is $got->{service_job_id}, '17', 'service_job_id';
    is $got->{service_branch}, 'feature', 'the source branch of a pull request, not PR-9';
    is $got->{service_pull_request}, '9', 'service_pull_request';

    local $ENV{CHANGE_BRANCH};
    local $ENV{BRANCH_NAME} = 'master';
    ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_branch}, 'master', 'BRANCH_NAME outside a pull request';
};

subtest 'get_config gitlab' => sub {
    local @ENV{@CI_VARS};
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{GITLAB_CI} = 'true';
    local $ENV{GITHUB_TOKEN} = 'set for another tool';
    local $ENV{CI_PIPELINE_IID} = '5';
    local $ENV{CI_JOB_NAME} = 'test';
    local $ENV{CI_MERGE_REQUEST_IID} = '3';
    local $ENV{CI_COMMIT_REF_NAME} = 'feature';
    local $ENV{CI_COMMIT_SHA} = 'abc123';
    my ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_name}, 'gitlab-ci', 'GitLab CI even with GITHUB_TOKEN set';
    is $got->{repo_token}, 'abcdef', 'the token is not GITHUB_TOKEN';
    is $got->{service_number}, '5', 'service_number';
    is $got->{service_job_id}, 'test', 'service_job_id';
    is $got->{service_pull_request}, '3', 'service_pull_request';
    is $got->{service_branch}, 'feature', 'service_branch';
    is $got->{commit_sha}, 'abc123', 'commit_sha';
};

subtest 'get_config azure (TF_BUILD)' => sub {
    local @ENV{@CI_VARS};
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{TF_BUILD} = 'True';
    local $ENV{GITHUB_TOKEN} = 'set for another tool';
    local $ENV{BUILD_BUILDID} = '123';
    local $ENV{SYSTEM_PULLREQUEST_PULLREQUESTNUMBER} = '8';
    local $ENV{BUILD_SOURCEVERSION} = 'abc123';
    my ($got) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_name}, 'azure-pipelines', 'Azure Pipelines even with GITHUB_TOKEN set';
    is $got->{repo_token}, 'abcdef', 'the token is not GITHUB_TOKEN';
    is $got->{service_number}, '123', 'service_number';
    is $got->{service_pull_request}, '8', 'service_pull_request';
    is $got->{commit_sha}, 'abc123', 'commit_sha';
};

subtest 'COVERALLS_PARALLEL' => sub {
    local @ENV{@CI_VARS};
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    for my $value (undef, '', 'false', '0') {
        local $ENV{COVERALLS_PARALLEL} = $value;
        my ($got) = Devel::Cover::Report::Coveralls::get_config();
        ok !exists $got->{parallel}, 'off for ' . ($value // 'unset');
    }
    for my $value ('true', '1') {
        local $ENV{COVERALLS_PARALLEL} = $value;
        my ($got) = Devel::Cover::Report::Coveralls::get_config();
        ok ${ $got->{parallel} }, "on for $value";
    }
};

subtest 'apply_ci_git_info' => sub {
    my $git = { branch => 'HEAD', head => { id => 'from-git', author_name => 'a' } };
    Devel::Cover::Report::Coveralls::apply_ci_git_info(
        { service_branch => 'feature', commit_sha => 'from-ci' }, $git);
    is $git->{branch}, 'feature', 'branch from the CI service';
    is $git->{head}{id}, 'from-ci', 'commit from the CI service';
    is $git->{head}{author_name}, 'a', 'the rest of head is kept';

    $git = { branch => 'master', head => { id => 'from-git' } };
    Devel::Cover::Report::Coveralls::apply_ci_git_info({}, $git);
    is_deeply $git, { branch => 'master', head => { id => 'from-git' } }, 'unchanged without CI values';
};

subtest 'parse_response' => sub {
    my $parse = \&Devel::Cover::Report::Coveralls::parse_response;
    is_deeply [ $parse->({ success => 1, status => 200, reason => 'OK',
        content => '{"message":"Job ##1.1","url":"https://coveralls.io/jobs/1"}' }) ],
        [ 'https://coveralls.io/jobs/1', undef ], 'success gives the URL';
    is_deeply [ $parse->({ success => '', status => 422, reason => 'Unprocessable Entity',
        content => '{"message":"Couldn\'t find a repository matching this job.","error":true}' }) ],
        [ undef, "Couldn't find a repository matching this job." ], 'the message of an API error';
    is_deeply [ $parse->({ success => '', status => 500, reason => 'Internal Server Error',
        content => '<html>oops</html>' }) ],
        [ undef, '500 Internal Server Error: <html>oops</html>' ], 'a response that is not JSON';
    is_deeply [ $parse->({ success => '', status => 599, reason => 'Internal Exception',
        content => "Could not connect\n" }) ],
        [ undef, "599 Internal Exception: Could not connect" ], 'a failed connection';
    is_deeply [ $parse->({ success => 1, status => 200, reason => 'OK',
        content => '{"message":"could not register","error":true}' }) ],
        [ undef, 'could not register' ], 'a 2xx response without the URL of a job';
    is_deeply [ $parse->({ success => '', status => 422, reason => 'Unprocessable Entity',
        content => '{"message":"","error":true}' }) ],
        [ undef, '422 Unprocessable Entity' ], 'the status when the message is empty';
    my (undef, $error) = $parse->({ success => '', status => 502, reason => 'Bad Gateway',
        content => 'x' x 1000 });
    is $error, '502 Bad Gateway: ' . ('x' x 200) . '...', 'only the start of a long body';
};

subtest 'report exits non-zero when the upload fails' => sub {
    local @ENV{@CI_VARS};
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    my $db = bless {}, 'Local::FakeDB';
    no warnings 'once', 'redefine';
    local *Local::FakeDB::cover = sub { bless {}, 'Local::FakeCover' };
    # Never reach Coveralls from the tests.
    my $response;
    local *HTTP::Tiny::post_form = sub { $response };
    my $run = sub {
        my $out = '';
        open my $fh, '>', \$out or die $!;
        my $old = select $fh;
        my $ok = eval { Devel::Cover::Report::Coveralls->report($db, { file => [] }); 1 };
        my $err = $@;
        select $old;
        return ($ok, $err, $out);
    };

    $response = { success => '', status => 422, reason => 'Unprocessable Entity',
        content => '{"message":"Couldn\'t find a repository matching this job."}' };
    my ($ok, $err, $out) = $run->();
    ok !$ok, 'dies on an API error';
    like $err, qr/COVERALLS_NO_FAIL/, 'says how to exit 0';
    like $out, qr/^error: Couldn't find a repository/m, 'prints the error';

    $response = { success => '', status => 599, reason => 'Internal Exception',
        content => "Could not connect to 'coveralls.io:443'\n" };
    ($ok, $err, $out) = $run->();
    ok !$ok, 'dies on a failed connection';
    like $out, qr/^error: 599 Internal Exception: Could not connect/m, 'prints the error';

    {
        local $ENV{COVERALLS_REPO_TOKEN};
        ($ok, $err, $out) = $run->();
        ok !$ok, 'dies without a repo token';
        like $err, qr/COVERALLS_REPO_TOKEN/, 'says which variable to set';

        local $ENV{COVERALLS_NO_FAIL} = '1';
        ($ok, $err, $out) = $run->();
        ok $ok, 'returns without a repo token with COVERALLS_NO_FAIL';
        like $out, qr/^error: required repo_token/m, 'prints the error';
    }

    local $ENV{COVERALLS_NO_FAIL} = 'true';
    ($ok, $err, $out) = $run->();
    ok $ok, 'returns with COVERALLS_NO_FAIL';
    like $out, qr/^error: /m, 'still prints the error';

    local $ENV{COVERALLS_NO_FAIL} = 'false';
    $response = { success => 1, status => 200, reason => 'OK',
        content => '{"url":"https://coveralls.io/jobs/1"}' };
    ($ok, $err, $out) = $run->();
    ok $ok, 'returns on success';
    like $out, qr{^register: https://coveralls.io/jobs/1$}m, 'prints the job';
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
