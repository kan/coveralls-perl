use strict;
use warnings;
use utf8;
use Test::More;

use FindBin;
use Devel::Cover::Report::Coveralls;

subtest 'get_config' => sub {
    local $ENV{TRAVIS}        = 'true';
    local $ENV{TRAVIS_JOB_ID} = 100000;

    my $got = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_job_id}, 100000, 'config service_job_id';
    is $got->{service_name}, 'travis-ci', 'config service_name';
};

subtest 'get_config github' => sub {
    local $ENV{TRAVIS}          = undef; # reset on travis
    local $ENV{GITHUB_ACTIONS}  = 1;
    local $ENV{GITHUB_SHA}      = '123456789';

    my $got = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_name}, 'github-actions', 'config service_name';
    is $got->{service_number}, '123456789', 'config service_number';
};

subtest 'get_config local' => sub {
    local $ENV{TRAVIS}         = undef; # reset on travis
    local $ENV{GITHUB_ACTIONS} = undef; # reset on github

    my $got = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_name}, 'coveralls-perl', 'config service_name';
    is $got->{service_event_type}, 'manual', 'config service_event_type';
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

