# Changelog

All notable changes to Devel-Cover-Report-Coveralls are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions up to 0.32.1 were released from `Changes`, before this file existed.

## [Unreleased]

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
