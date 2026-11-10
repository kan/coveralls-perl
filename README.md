[![Actions Status](https://github.com/kan/coveralls-perl/actions/workflows/master.yml/badge.svg?branch=master)](https://github.com/kan/coveralls-perl/actions?workflow=master) [![Actions Status](https://github.com/kan/coveralls-perl/actions/workflows/windows.yml/badge.svg?branch=master)](https://github.com/kan/coveralls-perl/actions?workflow=windows) [![Actions Status](https://github.com/kan/coveralls-perl/actions/workflows/mac.yml/badge.svg?branch=master)](https://github.com/kan/coveralls-perl/actions?workflow=mac) [![Coverage Status](https://img.shields.io/coveralls/kan/coveralls-perl/master.svg?style=flat)](https://coveralls.io/r/kan/coveralls-perl?branch=master)
# NAME

Devel::Cover::Report::Coveralls - Coveralls backend for Devel::Cover

# USAGE

## GitHub Actions

1\. Add your repo to Coveralls. [https://coveralls.io/repos/new](https://coveralls.io/repos/new)

2\. Add a workflow, e.g. `.github/workflows/test.yml`. The `GITHUB_TOKEN` of the workflow is
enough to send the report; you do not need the repo token of Coveralls.

```perl
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
```

3\. Push the change to GitHub. Coveralls shows the build, and on a pull request it reports the
coverage back to the pull request.

To send the coverage of several jobs (a matrix) as one build, mark each job as parallel, give
each its own flag name, and close the build when all of them are done. The build is the run of
the workflow, so the jobs and the closing step agree on it without any setting.

```perl
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
```

## Travis CI

1\. Add your repo to Coveralls. [https://coveralls.io/repos/new](https://coveralls.io/repos/new)

2\. In the settings of your repository on Travis CI, set the environment variable
`COVERALLS_REPO_TOKEN` to the repo token shown on your project page in Coveralls.

3\. Add the settings to `.travis.yml`:

```
language: perl
perl:
  - "5.30"
before_install:
  - cpanm -n Devel::Cover::Report::Coveralls
script:
  - perl Build.PL && ./Build build && cover -test -report coveralls
```

4\. Push the change. Coveralls shows the build.

## Other CI services

GitLab CI, CircleCI, Jenkins, Azure Pipelines, Drone and Semaphore are detected from their
environment variables, and the build number, branch, commit and pull request they give are sent.

1\. Get the repo token from your project page in Coveralls.

2\. Give it to the job as `COVERALLS_REPO_TOKEN`, as a secret variable of the CI service.
Or write it in `.coveralls.yml` in the directory you run `cover` from, and do not commit
that file to a public repository:

```
repo_token: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

3\. Run `cover -test -report coveralls` in the job.

## When the report cannot be sent

`cover -report coveralls` prints the error and exits with a non-zero status, so the job fails.
To keep the job green, e.g. on pull requests from forks, which get no secrets, set
["COVERALLS\_NO\_FAIL"](#coveralls_no_fail).

# DESCRIPTION

This module is a report of [Devel::Cover](https://metacpan.org/pod/Devel%3A%3ACover) that sends the coverage of your Perl project to
[Coveralls](https://coveralls.io/). Run it as `cover -report coveralls` after the tests, or
as `cover -test -report coveralls` to run them too.

It sends the coverage of each line of each source file, with the git commit, branch and
remotes of the working tree. On the CI services listed in ["USAGE"](#usage), it also sends the
build number, job, branch and pull request the CI service gives.

When [Devel::Cover](https://metacpan.org/pod/Devel%3A%3ACover) collected the branch coverage (it does by default), it is sent too: how
many times each side of each decision (`if`, `unless`, `elsif`, the ternary operator and so
on) was taken. Branches marked `uncoverable` are left out. The condition coverage of
Devel::Cover (`&&`, `||` and `//`) is not sent. Whether Coveralls counts branches
in the coverage of the repository is a setting of the repository on Coveralls.

# ENVIRONMENT

These environment variables change what is sent. The variables that the CI services set are
read as well; you do not need to set them.

## COVERALLS\_REPO\_TOKEN

The Coveralls authentication token for this particular repo. It is used before `repo_token`
in `.coveralls.yml`. On GitHub Actions, `GITHUB_TOKEN` is used when neither is set.

## COVERALLS\_ENDPOINT

The URL of the Coveralls server, for Coveralls Enterprise. The default is
`https://coveralls.io`. The report is sent to this URL followed by `/api/v1/jobs`, so give
it without a path.

## COVERALLS\_FLAG\_NAME

Describe the particular tests being done, e.g. `Unit` or `Functional`.
On GitHub Actions it is also added to the job ID, so give each leg of a matrix that reports
to the same parallel build its own flag name.

## COVERALLS\_PARALLEL

Set this to `true` when several jobs send their coverage to one build. Any value other than
empty, `false` and `0` turns it on. Coveralls then keeps the build open until the parallel
build webhook is called, so call it when all the jobs are done. The jobs must send the same build
number; the CI services above give one per run (on GitHub Actions, the run of the workflow).

See [https://docs.coveralls.io/api-parallel-build-webhook](https://docs.coveralls.io/api-parallel-build-webhook)

## COVERALLS\_NO\_FAIL

When the report cannot be sent to Coveralls (the upload fails, or there is no repo token),
`cover -report coveralls` prints the error and exits with a non-zero status, so that the CI
job fails. Set this to `true` to exit 0 instead, e.g. when coverage is optional for the build or
pull requests from forks get no repo token. When `cover` makes several reports, the ones after
`coveralls` are not made after a failure, so put `coveralls` last. Any value other than empty, `false` and `0` turns it on.

## COVERALLS\_SERVICE\_NAME, COVERALLS\_SERVICE\_NUMBER, COVERALLS\_SERVICE\_JOB\_ID, COVERALLS\_SERVICE\_JOB\_NUMBER, COVERALLS\_PULL\_REQUEST

Send these as the name of the CI service, the build number, the job ID, the job number and the
number of the pull request, in place of what is detected from the CI service. On a CI service
not listed in ["USAGE"](#usage), set them to send what the CI service knows. `COVERALLS_PULL_REQUEST`
set to `false` means that the build is not for a pull request.

When no CI service is detected, the build is sent as a manual upload (`service_event_type`
`manual`), unless one of these variables other than `COVERALLS_PULL_REQUEST` is set, or
`COVERALLS_PERL_SERVICE_NAME`: then it is sent as a CI build, without an event type.

## COVERALLS\_EVENT\_TYPE

Send this as the event type of the build (`service_event_type`), as the official
coverage-reporter does.

## COVERALLS\_PERL\_SERVICE\_NAME

Another name of `COVERALLS_SERVICE_NAME`, which wins when both are set.

## COVERALLS\_GIT\_BRANCH, COVERALLS\_GIT\_COMMIT

Send these as the branch and the commit ID, in place of the ones detected from the CI service
and from git.

## GIT\_ID, GIT\_BRANCH, GIT\_AUTHOR\_NAME, GIT\_AUTHOR\_EMAIL, GIT\_COMMITTER\_NAME, GIT\_COMMITTER\_EMAIL, GIT\_MESSAGE

The commit ID, the branch, the author, the committer and the message of the commit, for a build
outside a git repository (e.g. from another version control system, or from a tarball). There
git is not run, and what is not set is not sent. In a git repository, what git says comes first,
and these only fill in what git does not give: CI jobs often set `GIT_AUTHOR_NAME` and the
like for the commits they make, and Jenkins sets `GIT_BRANCH` to `origin/<branch>`.
To give the branch or the commit ID in a git repository, use `COVERALLS_GIT_BRANCH` and
`COVERALLS_GIT_COMMIT`.

# SEE ALSO

- [Devel::Cover](https://metacpan.org/pod/Devel%3A%3ACover)
- [https://coveralls.io/](https://coveralls.io/) and its documentation, [https://docs.coveralls.io/](https://docs.coveralls.io/)
- [https://github.com/coverallsapp/coverage-reporter](https://github.com/coverallsapp/coverage-reporter), the official reporter of Coveralls.
This module sends the values it sends on each CI service.

## EXAMPLE

The coverage of this module: [https://coveralls.io/github/kan/coveralls-perl](https://coveralls.io/github/kan/coveralls-perl)

# LICENSE

Copyright (C) Kan Fushihara

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Kan Fushihara <kan.fushihara@gmail.com>
