# Changelog

All notable changes to Devel-Cover-Report-Coveralls are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions up to 0.32.1 were released from `Changes`, before this file existed.

## [Unreleased]

- Rewrite the description, `COVERALLS_ENDPOINT` and the links in the documentation, and add a Coveralls badge to the README (#67)
- Leave the bots (tagpr's release pull requests and Dependabot) out of the contributors in the distribution's metadata (#71)
- Work outside a git repository: git is not run there, so it prints no errors, and values that are not known are left out instead of sent empty. The commit, its author and the branch can be given there as `GIT_ID`, `GIT_BRANCH`, `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` and `GIT_MESSAGE`, the names of the official coverage-reporter (#35)
- Override what the CI service gives with `COVERALLS_SERVICE_NAME`, `COVERALLS_SERVICE_NUMBER`, `COVERALLS_SERVICE_JOB_ID`, `COVERALLS_SERVICE_JOB_NUMBER`, `COVERALLS_PULL_REQUEST`, `COVERALLS_GIT_BRANCH` and `COVERALLS_GIT_COMMIT`, as in the official coverage-reporter (#35)
- Send the job in the form the Coveralls jobs API documents: a JSON file in the multipart field `json_file`, in place of the form field `json`, with the MD5 digest of each source file as `source_digest` (#55)
- Send the branch coverage that Devel::Cover collected, leaving out the branches marked uncoverable (#31)
- Send source files written in UTF-8 as their characters, so that the non-ASCII text in them is not garbled on Coveralls. Files that are not valid UTF-8 are sent as their bytes, as before (#81)
## [1.0.0] - 2026-11-07

- Update the usage examples for GitHub Actions (with parallel builds), Travis CI and the other CI services, and document `COVERALLS_NO_FAIL` and `COVERALLS_PERL_SERVICE_NAME` (#58)
- Do not wrap the commit ID, names, e-mail addresses and message from `git log` in single quotes on Windows (#54)
- **Breaking:** `cover -report coveralls` exits with a non-zero status when the upload to Coveralls fails, so the CI job fails. Set `COVERALLS_NO_FAIL=1` to exit 0, which also covers a missing repo token, e.g. on pull requests from forks (#56)
- **Breaking:** On GitHub Actions, report as `github` with the values of the official coverage-reporter: the build number is the run (`GITHUB_RUN_ID`) instead of the commit, pull requests send their number and source branch instead of `<number>/merge`, and parallel jobs can be grouped. GitHub Actions is detected by `GITHUB_ACTIONS` instead of `GITHUB_TOKEN`, and a repo token from `COVERALLS_REPO_TOKEN` or `.coveralls.yml` comes before `GITHUB_TOKEN`. Repositories that reported as `github-actions` now report as `github` (#52)
- **Breaking:** Travis CI also needs `COVERALLS_REPO_TOKEN` (or `repo_token` in `.coveralls.yml`), as Coveralls requires it there too (#53)
- Support GitLab CI, read `BUILD_NUMBER` on Jenkins, treat `COVERALLS_PARALLEL=false` and `0` as off, and send the branch, commit and pull request that CircleCI, Jenkins and Azure Pipelines give (#53)
- Require Perl 5.20 or later, the version the current Devel::Cover needs (#57)
- Do not send credentials in git remote URLs, and send each remote once with its fetch URL (#51)

## [0.32.1] - 2023-05-19

- Fix test (thanks chylli-deriv)

## [0.32] - 2023-04-25

- Decode git log output (thanks voegelas)
- Some bug fix (thanks voegelas)

## [0.31] - 2022-01-31

- Add support for pull requests (thanks sirtoobii)
- Fixed CircleCI workflow_id (thanks sirtoobii)

## [0.30] - 2022-01-18

- Support DroneCI (thanks sirtoobii)
- Support coveralls parallel mode (thanks sirtoobii)

## [0.20] - 2020-11-08

- Support COVERALLS_FLAG_NAME, different COVERALLS_ENDPOINT (thanks mohawk2)
- Support GitHub actions in more native way without special secret (thanks mohawk2)

## [0.15] - 2020-04-29

- Support Azure-Pipeline (thanks jacquesg)
- Setting and code fix (thanks bayashi)

## [0.14] - 2020-03-13

- Fix Github Actions service_name "github-actions" to "github" (thanks Songmu)

## [0.13] - 2020-01-30

- Support for getting branch name on Github Actions (thanks bayashi)

## [0.12] - 2020-01-29

- Support Github Actions (thanks bayashi)

## [0.11] - 2014-10-08

- Depends HTTP::Tiny 0.043 or later (thanks tobyink)

## [0.10] - 2014-10-04

- Fixed metadata (thanks pjfl)
- Support uncoverable statement comment (thanks tobyink)
- Fix source file path

## [0.09] - 2014-10-02

- Use core HTTP::Tiny instead of Furl (thanks JRaspass)

## [0.08] - 2014-06-16

- Add IO::Socket::SSL prereq (thanks haarg)

## [0.07] - 2014-06-16

- Depend JSON::XS to JSON::PP (thanks fioux, karenetheridge)

## [0.06] - 2013-07-14

- Fixed pod (thanks dsteinbrunner)

## [0.05] - 2013-05-27

- Need Devel::Cover 1.02 (cover -test exists with the staus of the underlying test run)

## [0.04] - 2013-05-22

- Fixed bugs at coveralls API result broken (thanks songmu)

## [0.03] - 2013-05-22

- Fixed document
- Remove debug print (thanks songmu)

## [0.02] - 2013-05-08

- Fixed test at travis ci

## [0.01] - 2013-04-15

- Original version

[1.0.0]: https://github.com/kan/coveralls-perl/releases/tag/v1.0.0
[0.32.1]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.32.1
[0.32]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.32
[0.31]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.31
[0.30]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.30
[0.20]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.20
[0.15]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.15
[0.14]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.14
[0.13]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.13
[0.12]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.12
[0.11]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.11
[0.10]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.10
[0.09]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.09
[0.08]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.08
[0.07]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.07
[0.06]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.06
[0.05]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.05
[0.04]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.04
[0.03]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.03
[0.02]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.02
[0.01]: https://metacpan.org/release/KAN/Devel-Cover-Report-Coveralls-0.01
