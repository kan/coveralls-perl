# Security Policy

## Reporting a Vulnerability

If you find a vulnerability in tagpr-scripts, do not open a public issue. Report it through GitHub's [Private vulnerability reporting](https://github.com/kan/tagpr-scripts/security/advisories/new) instead. Only the maintainer can see the report until a fix is published.

Please include:

- What the vulnerability is
- Steps to reproduce it
- The expected impact (for example, what a crafted `CHANGELOG.md`, tag or pull request could make the release workflow do)

Reports are checked and answered as soon as possible.

## Scope

In scope are the scripts and the reusable workflows in this repository (the latest `main` branch). There are no release versions, so fixes are not applied to older commits. The repositories that pull this one in with `git subtree` pick up a fix with their next `subtree pull`.

Please report these elsewhere:

- Problems in tagpr itself: [Songmu/tagpr](https://github.com/Songmu/tagpr)
- Problems that exist only in one of the repositories using these scripts: that repository's security policy
