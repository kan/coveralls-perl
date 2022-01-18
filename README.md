[![Actions Status](https://github.com/kan/coveralls-perl/workflows/master/badge.svg)](https://github.com/kan/coveralls-perl/actions) [![Actions Status](https://github.com/kan/coveralls-perl/workflows/windows/badge.svg)](https://github.com/kan/coveralls-perl/actions) [![Actions Status](https://github.com/kan/coveralls-perl/workflows/mac/badge.svg)](https://github.com/kan/coveralls-perl/actions) [![Build Status](https://travis-ci.org/kan/coveralls-perl.svg?branch=master)](https://travis-ci.org/kan/coveralls-perl)
# NAME

Devel::Cover::Report::Coveralls - coveralls backend for Devel::Cover

# USAGE

## GitHub Actions

1\. Add your repo to coveralls. [https://coveralls.io/repos/new](https://coveralls.io/repos/new)

2\. Add settings to one of your GitHub workflows. Here assuming you're
calling it `.github/workflows/ci.yml`:

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

3\. Push new change to GitHub

4\. Coveralls should update your project page

## Travis CI

1\. Add your repo to coveralls. [https://coveralls.io/repos/new](https://coveralls.io/repos/new)

2\. Add setting to `.travis.yaml` (`before_install` and `script` section)

    language: perl
    perl:
      - 5.16.3
      - 5.14.4
    before_install:
      cpanm -n Devel::Cover::Report::Coveralls
    script:
      perl Build.PL && ./Build build && cover -test -report coveralls

3\. push new change to github

4\. updated coveralls your project page

<div>
    <img src="http://kan.github.io/images/p5-ltsv.png" />
</div>

## another CI

1\. Get repo\_token from your project page in coveralls.

2\. Write `.coveralls.yml` (don't add this to public repo)

    repo_token: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

3\. Run CI.

# DESCRIPTION

[https://coveralls.io/](https://coveralls.io/) is service to publish your coverage stats online with a lot of nice features. This module provides seamless integration with [Devel::Cover](https://metacpan.org/pod/Devel%3A%3ACover) in your perl projects.

# ENVIRONMENT

Set these environment variables to control the behaviour. Various other
variables, set by particular CI environments, will be interpreted silently
and correctly.

## COVERALLS\_REPO\_TOKEN

The Coveralls authentication token for this particular repo.

## COVERALLS\_ENDPOINT

If you have an enterprise installation, set this to change from the
default of `https://coveralls.io`. The rest of the URL (`/api`, etc)
won't change, and will be correct.

## COVERALLS\_FLAG\_NAME

Describe the particular tests being done, e.g. `Unit` or `Functional`.

## COVERALLS\_PARALLEL

Set this to `true` in case you run your tests in a parallel environment. It is important to note though:
If you use this feature, you must ensure that your CI solution calls the parallel webhook when everything is done. Moreover,
regardless of what CI you use, you have to make sure that the `build_number` is constant across the different jobs, otherwise
coveralls is unable to group them together as one build.

See also [https://docs.coveralls.io/parallel-build-webhook](https://docs.coveralls.io/parallel-build-webhook>)

# SEE ALSO

[https://coveralls.io/](https://coveralls.io/)
[https://coveralls.io/docs](https://coveralls.io/docs)
[https://github.com/coagulant/coveralls-python](https://github.com/coagulant/coveralls-python)
[Devel::Cover](https://metacpan.org/pod/Devel%3A%3ACover)

## EXAMPLE

[https://coveralls.io/r/kan/p5-smart-options](https://coveralls.io/r/kan/p5-smart-options)

# LICENSE

Copyright (C) Kan Fushihara

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Kan Fushihara <kan.fushihara@gmail.com>
