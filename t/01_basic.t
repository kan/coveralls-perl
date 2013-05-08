use strict;
use warnings;
use utf8;
use Test::More;

use FindBin;
use Devel::Cover::Report::Coveralls;

subtest 'get_config' => sub {
    local $ENV{TRAVIS}        = 'true';
    local $ENV{TRAVIS_JOB_ID} = 100000;

    my $config = {
        service_job_id => 100000,
        service_name => 'travis-ci',
    };

    is_deeply Devel::Cover::Report::Coveralls::get_config(), $config, 'config';
};

subtest 'get_config local' => sub {
    local $ENV{TRAVIS}        = undef; # reset on travis
    local $ENV{COVERALLS_REPO_TOKEN} = 'xxxxx';

    my $config = {
        repo_token => 'xxxxx',
        service_name => 'coveralls-perl',
        service_event_type => 'manual',
    };

    is_deeply Devel::Cover::Report::Coveralls::get_config(), $config, 'config';
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

