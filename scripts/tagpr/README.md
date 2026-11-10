# tagpr-scripts

The scripts that let [tagpr](https://github.com/Songmu/tagpr) release an npm package whose
`CHANGELOG.md` is written by hand. Shared by [lily](https://github.com/kan/lily),
[wema](https://github.com/kan/wema) and [wema-kake](https://github.com/kan/wema-kake),
which pull this repository in with `git subtree` at `scripts/tagpr/`.
The Go projects [roji](https://github.com/kan/roji),
[notify-slack](https://github.com/kan/notify-slack) and [hokora](https://github.com/kan/hokora),
which have no version file, use only the CHANGELOG part (`--changelog-only`). The Tauri apps
[musql](https://github.com/kan/musql) (`--changelog-only --cargo src-tauri`) and
[pike](https://github.com/kan/pike) (`--cargo src-tauri`, with `package.json` too) also
bring `Cargo.lock` along. The CPAN module
[coveralls-perl](https://github.com/kan/coveralls-perl) (`--changelog-only`) keeps its
version in a Perl module and `META.json`, and releases from `master`. The shell tools
[booch](https://github.com/kan/booch) and [booch-win](https://github.com/kan/booch-win)
(`--changelog-only`) keep their version in a `VERSION` file.

| File | Run by | Does |
|---|---|---|
| `release-prepare.mjs` | tagpr, as `postVersionCommand` | Turns `## [Unreleased]` into `## [X.Y.Z] - <date in JST>`, adds the version's link definition, and brings `package-lock.json` to the version tagpr put in `package.json` (not with `--changelog-only`) |
| `release-notes.mjs` | The publish workflow | Prints one section of `CHANGELOG.md`, to check that it exists before publishing and to use it as the GitHub release notes. Given a tag `vX.Y.Z` it prints `## [X.Y.Z]`; given a pre-release tag (`vX.Y.Z-rc.1`, tagged by hand on `main`) it prints `## [Unreleased]` |
| `release-tag.mjs` | The npm and CPAN publish workflows, before any dependency is installed | Checks that the tag is `v` + the version of `package.json` (when there is one) and of every `versionFile` of `.tagpr`, and that its commit is on `releaseBranch` of `.tagpr`. Prints `prerelease=`, and `spec=` (`name@version`) when there is a `package.json`, for `$GITHUB_OUTPUT` |
| `release-pending.mjs` | The tagpr workflow, before tagpr | Prints `false` when there is nothing to release (`## [Unreleased]` is empty, and no section is newer than the latest tag), so that tagpr is not run; `true` otherwise |
| `missed-tags.mjs` | The tagpr workflow, before tagpr | Reads `CHANGELOG.md` to find the versions whose tag was missed, and the version a release pull request's merge commit released, so that the workflow can re-run the run of that merge |
| `changelog.mjs` | (imported by the others) | How a `CHANGELOG.md` is read and stamped. Written in one place so the release pull request and the publish never disagree. Knows nothing about npm |
| `npm-lock.mjs` | (imported by `release-prepare.mjs`) | The `package.json` / `package-lock.json` part |
| `cargo-lock.mjs` | (imported by `release-prepare.mjs`) | The `Cargo.toml` / `Cargo.lock` part, with `--cargo <dir>` |
| `version-files.mjs` | (imported by `release-prepare.mjs`) | Checks that every `versionFile` in `.tagpr` is at the proposed version |

**Only Node's built-in modules.** The tagpr job holds a token that can push to the
repository, so it runs no dependency code: no `npm ci`, nothing fetched at run time. That
is also why this is a subtree and not an npm package — the code is committed in each
repository and reviewed in its diffs.

Run both from the repository root: `CHANGELOG.md`, and for `release-prepare.mjs` also
`.tagpr`, the files its `versionFile` lists, and without `--changelog-only` `package.json`
and `package-lock.json` (lockfile version 2 or later), are read from the working directory.

`release-prepare.mjs` reads `versionFile` from `.tagpr` (with `git config`) and checks that
each file listed is at the proposed version: the top-level `"version"` of a `*.json`, the
`[package]` `version` of a `Cargo.toml`, the whole of a `VERSION` (the version alone, on
one line, with or without a final LF), the `our $VERSION = "X.Y.Z";` line of a Perl module
`*.pm` (exactly one line that sets `$VERSION`, to a quoted string; POD and anything after
`__END__` or `__DATA__` are skipped). tagpr rewrites only the first occurrence of the
current version in each file, so a dependency at the same version above the file's own
version line would take the change and leave the real one behind, with nothing failing;
the tag is then made from the first file's version. Other kinds of files cannot be checked
and fail. With no `.tagpr`, or `versionFile = -`, nothing is checked.

`release-prepare.mjs --changelog-only` reads neither `package.json` nor its lock, for a
repository with no npm package: one with no version file (`versionFile = -`), or one that
brings its own version files and locks up to date in a wrapper of its own.

`release-prepare.mjs --cargo <dir>` also brings `<dir>/Cargo.lock` to the version, with or
without `--changelog-only`. List `<dir>/Cargo.toml` in `versionFile`, and not the lock:
tagpr rewrites only the first occurrence of the current version in each file, which in a
`Cargo.lock` can be a dependency at the same version (and in a `package-lock.json` leaves
the second one behind). This checks that
the `version` in its `[package]` table is the proposed one, then rewrites the version line
of the package's own `[[package]]` entry in `Cargo.lock` (the one without a `source`).
`cargo` is not run, so nothing is fetched. A `version.workspace = true` is not supported.

## What the CHANGELOG has to look like

[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), with these rules:

- Each pull request that changes what users get adds its line under `## [Unreleased]`.
  That section becomes the release notes word for word.
- A section ends at the next `## ` heading, or at the block of link definitions
  (`[x]: url`) at the end of the file. Headings inside code fences are not headings.
- Entries may be wrapped. `release-notes.mjs` joins the lines of a paragraph or a list
  item into one, because GitHub shows every line break in release notes: with nothing
  between two Japanese characters (kanji, kana, full-width) or next to full-width
  punctuation and brackets (`、` `。` `（` `）` and so on), and with one space anywhere
  else. Code fences, headings, tables, block quotes, HTML blocks, thematic breaks and hard
  breaks (two trailing spaces or `\`) are left as they are. A wrapped line that starts with
  a number and a period (`2026. ...`) is taken for the next numbered item and not joined, so
  do not wrap there. Indented code blocks are not supported; use fences.
- Links inside entries are written inline. A reference link's definition sits outside the
  section, so it would not be a link in the release notes.
- Each release gets `[X.Y.Z]: https://github.com/<owner>/<repo>/releases/tag/vX.Y.Z` at
  the top of that final block. `<owner>/<repo>` is `GITHUB_REPOSITORY` in GitHub Actions
  (`GITHUB_ACTIONS=true`), and the `origin` remote's anywhere else (GitHub only);
  `repository` in `package.json` is not read. There is no `[Unreleased]: .../compare/...` link; nothing
  would keep it up to date.
- LF line endings. In a repository worked on from Windows, keep Git from checking it out
  with CRLF:

  ```gitattributes
  CHANGELOG.md text eol=lf
  ```

`release-prepare.mjs` checks everything before it writes anything, and writes nothing when
it fails. It fails when:

- `## [Unreleased]` is missing, empty or duplicated. (Right after a release, the tagpr
  workflow does not run tagpr at all: see "With nothing to release" below.)
- **A version section newer than the latest tag is already there** (the latest tag is
  `TAGPR_CURRENT_VERSION`, which tagpr passes along with `TAGPR_NEXT_VERSION`). tagpr
  rebuilds the release pull request from the release branch every time, so this means a release pull request
  was merged and its tag was never made — usually because the tagpr run of the merge
  commit was cancelled by a later push, or because the tag was deleted to be made again.
  The tagpr workflow re-runs a cancelled run of the merge before it runs tagpr (see "A
  missed tag is made by re-running the run of its merge" below), so this fails only when
  that could not be done. Then re-run the run of the merge commit (or push the tag again, annotated:
  `git tag -a -m "Release vX.Y.Z" vX.Y.Z <commit>`).
  Merging a new release pull request would tag a
  later commit with changes the CHANGELOG does not list.

  It checks every section, not only the proposed version's. tagpr counts from the latest
  tag, so if a pull request labelled for a minor release lands while `1.2.4` is untagged,
  it proposes `1.3.0`; a check for `## [1.3.0]` alone would pass and stack `1.3.0` on an
  untagged `1.2.4`.

  It only compares with the latest tag. **Once a later tag exists, an older untagged
  section is no longer caught** (tag `v1.2.5` by hand while `1.2.4` is untagged, and
  `1.2.4` never gets a tag). That is why the message lists every untagged section, oldest
  first: tag them in that order. With no tags at all (tagpr passes `v0.0.0`) the check is
  skipped, so a repository that released without tags can adopt tagpr.
- A file in `versionFile` is not at the version tagpr proposes, or is not a `*.json`, a
  `Cargo.toml`, a `VERSION` or a `*.pm`. A `*.pm` also fails when it sets `$VERSION` on no
  line or on more than one, or in any other form (`$VERSION = eval $VERSION;`,
  `package NAME VERSION;`), since then which line is the module's own version is unclear.
- `package.json` is not at the version tagpr proposes (not checked with `--changelog-only`).
- With `--cargo <dir>`, the `[package]` version in `<dir>/Cargo.toml` is not the proposed
  one, or `<dir>/Cargo.lock` does not have exactly one entry for the package without a
  `source`.
- The GitHub repository cannot be told: outside GitHub Actions, `origin` is missing or not
  on GitHub.

tagpr still updates the release pull request when the command fails, so **do not merge a
release pull request whose tagpr run is red.**

## Using it

```bash
git subtree add -S --prefix=scripts/tagpr https://github.com/kan/tagpr-scripts.git main --squash
```

**Pass `-S`.** `git subtree` makes its commits with `commit-tree`, which ignores
`commit.gpgsign`, so without it they are left unsigned.

**Let GitHub Actions create pull requests** (Settings → Actions → General → "Allow GitHub
Actions to create and approve pull requests", or `can_approve_pull_request_reviews` in the
API). Without it, the first tagpr run fails with 403 "GitHub Actions is not permitted to
create or approve pull requests". The default token permissions can stay read-only.

### The tagpr workflow

`.github/workflows/tagpr.yml` here is a reusable workflow that runs tagpr and, once a tag
is made, starts the repository's publish workflow on that tag with `workflow_dispatch`.
Call it from the repository's own `.github/workflows/tagpr.yml`:

```yaml
name: tagpr
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
jobs:
  tagpr:
    uses: kan/tagpr-scripts/.github/workflows/tagpr.yml@<commit SHA>
    permissions:
      contents: write       # push the release branch and the tag
      pull-requests: write  # open and update the release pull request
      issues: read          # read labels
      actions: write        # start the publish workflow
    with:
      release-workflow: publish.yml
```

- **Call it by a full commit SHA, the same commit as `scripts/tagpr/`.** A reusable
  workflow from another repository is not pinned by the caller's `actions.lock`. The
  actions inside it (tagpr included) are pinned by this repository's `actions.lock`.
- **Check that in the CI of pull requests**, from the root of the repository:

  ```yaml
  - name: Check scripts/tagpr/ against the tagpr workflow pin
    run: node scripts/tagpr/verify-subtree.mjs
  ```

  It compares the tree of `HEAD:scripts/tagpr` with the tree of the commit that the
  `uses: kan/tagpr-scripts/...@<SHA>` lines call, and fails when a subtree pull did not move
  the line, when the line moved without a pull, or when `scripts/tagpr/` was edited by hand.
  It fetches that one commit into a temporary repository, so a shallow checkout is enough
  and no token is needed.
- The calling job's `permissions` are the most the workflow gets. List all four, even
  with an empty `release-workflow`: GitHub checks every job's permissions when the run
  starts, including jobs that will be skipped.
- Do not give the calling workflow a `concurrency` of its own. The tagpr job already
  queues the runs one at a time.
- **Rebuild the release pull request when its version label changes.** Add
  `.github/workflows/tagpr-label.yml`, calling `tagpr-label.yml` here at the same commit:

  ```yaml
  name: tagpr-label
  on:
    pull_request_target:
      types: [labeled, unlabeled]
  permissions: {}
  jobs:
    rebuild:
      uses: kan/tagpr-scripts/.github/workflows/tagpr-label.yml@<commit SHA>
      permissions:
        actions: write        # start the tagpr workflow
        pull-requests: write  # mark the release pull request draft
  ```

  When a label is added to or removed from the open release pull request (`tagpr:minor`,
  `tagpr:major` or any other), it marks the pull request draft and starts `tagpr.yml`
  with `workflow_dispatch` on the release branch, so the release pull request is rebuilt
  at the version its labels ask for and marked ready again. Without it, a release pull
  request merged before a rebuild releases the version it had before the label. It checks
  nothing out, so `pull_request_target` runs no code from the pull request. It needs no
  GitHub App: a label added by a member with write access starts the run without the
  approval that `pull_request` asks for on a pull request made by `GITHUB_TOKEN` (labels
  from outside collaborators may still wait for approval, depending on the repository's
  Actions settings).
  - It starts `.github/workflows/tagpr.yml`, so keep that name and its
    `workflow_dispatch:` trigger. A run started by `workflow_dispatch` always runs tagpr,
    even with nothing to release.
  - A label changed on a merged pull request (one listed in `minorLabels`, say) does not
    start it. Start `tagpr.yml` by hand then: `gh workflow run tagpr.yml`.
  - The rebuild queues behind a merge run like any other run. A label changed while a
    merge run waits can replace that run (the same as a push); the next run re-runs it to
    make the tag (see "A missed tag is made by re-running the run of its merge").
  - If the repository pins its actions with `actions.lock`, run `gh actions-lock` after
    adding the file. It adds an empty entry for `tagpr-label.yml`; without it,
    `gh actions-lock --verify` fails with "Not pinned".
- **Keep Dependabot off the calling line.** Add this to the `github-actions` entry of
  `.github/dependabot.yml`:

  ```yaml
      ignore:
        # Moved together with scripts/tagpr/ by git subtree pull, never on its own
        - dependency-name: 'kan/tagpr-scripts*'
  ```

  A pull request that moved the SHA alone would leave `scripts/tagpr/` behind the
  workflow that runs, and nothing would fail. This repository has no tags, so Dependabot
  has nothing to move it to today, but that would change the day a tag is made.
- Inputs:
  - `release-workflow`: the workflow file to start on the new tag. Leave it empty to
    start it yourself, after a job of your own (hokora tags `sdk/vX.Y.Z` first).
  - `artifact`: the name of an artifact made by an earlier job of the same run. It is
    downloaded before tagpr runs, and its directory is passed to `postVersionCommand` as
    `TAGPR_ARTIFACT_DIR`. Make what needs dependency code (a credits list, say) in a job
    without write access, and give the calling job `needs: <that job>` and
    `if: ${{ !cancelled() }}`: the run that tags a merged release pull request does not use
    the artifact, so a failed credits job must not keep it from tagging. When the download
    fails, `TAGPR_ARTIFACT_DIR` is empty, and the wrapper should fail before it writes.
  - `timeout-minutes`: for the tagpr job (default 10).
- `postVersionCommand` runs on Node 24, the version the tests here run on.
- Output: `tag`, the tag this run made (or found already made, on a re-run), or empty.
- **When a tagpr run fails, the release pull request is turned into a draft.** tagpr
  rebuilds the release pull request even when `postVersionCommand` fails: the version files
  are bumped, but `CHANGELOG.md` and the locks are not. Merged, it would make a tag with no
  CHANGELOG section, which the publish then refuses. The draft cannot be merged; the next
  run that succeeds marks it ready again.
- **With nothing to release, tagpr is not run.** When `## [Unreleased]` is empty and no
  section is newer than the latest tag (a push right after a release that changes nothing
  in `CHANGELOG.md`), `release-pending.mjs` says so, and the run passes with a notice and
  no release pull request. A run of a merge, or one after a tag was missed, still runs
  tagpr, and so does a run while a release pull request is open and ready (it is rebuilt
  and turned into a draft), and a run started by `workflow_dispatch` (a rebuild asked for
  by hand or by `tagpr-label.yml`). If the check itself fails, tagpr is run, so a tag is never left
  unmade for it. A run with nothing to release closes every release pull request (label
  `tagpr`, branch `tagpr-from-v`) that is open as a draft, with a comment, and keeps their
  branches. Such a draft was left by a run that failed, or by a label change whose rebuild
  has not run yet; either way there is nothing in it to release, and the next pull request
  that writes `CHANGELOG.md` gets a new one.
- **A successful run marks ready only the release pull request it rebuilt, and closes the
  others.** tagpr looks only at the branch `tagpr-from-v<latest tag>`, so once a tag is made,
  an older release pull request (say, the draft left behind when the run of a merge was
  cancelled) is never rebuilt again. The run closes it with a comment and keeps its branch.
  Do not reopen and merge it. Only a run that rebuilt the release pull request does this:
  a run that makes a tag, or one that fails, leaves the old one open until the next
  successful run on a push to the release branch. Only pull requests with the label `tagpr`
  and a branch starting `tagpr-from-v` are closed.
- **The tag is made annotated.** tagpr makes a lightweight tag unless `tag.gpgSign` is set,
  and `git describe` without `--tags` skips lightweight tags. The workflow replaces it with
  an annotated tag on the same commit before starting `release-workflow`. To get the commit
  from the tag, use `$TAG^{commit}` (or follow the tag object in the API), not `$TAG` alone.
  If that step fails, the tag stays lightweight and `release-workflow` is not started.
- **A missed tag is made by re-running the run of its merge.** When the run of a merge is
  cancelled (a push came while it waited), the version has a section in `CHANGELOG.md` but
  no tag. Before tagpr, each run looks for the oldest such version (`missed-tags.mjs`) and
  the merge commit of its release pull request between the latest tag and the run's
  commit: merged, labelled `tagpr`, from a `tagpr-from-v` branch, with that version as the
  newest section of its `CHANGELOG.md`. If the tagpr job of the push run on that commit
  was cancelled, it re-runs that run's cancelled and failed jobs, the same as doing it by
  hand: tagpr makes the tag, and the rest of the run (the annotated tag, the `tag` output,
  `release-workflow`) goes as usual. The run that asked for it does not run tagpr: it waits
  for the re-run to finish, and starts `tagpr.yml` again on the release branch, which picks
  up the next missing tag or rebuilds the release pull request. The release was decided
  when the pull request was merged, so nobody is asked again. A merge whose tagpr job
  failed is not re-run (fix the cause first). When the merge or its run cannot be found,
  only a warning is given and tagpr runs; if the tag is still missing, it fails as above.
  A repository with no version tag yet is left to tagpr, which tags its first merge.
- **When the run of a merge made the tag but failed after it, re-run that run.** This covers
  a failed step that makes the tag annotated, and a failed start of `release-workflow`.
  tagpr accepts a tag that already points at the merged commit, and outputs it again, so the
  rest of the run goes through once more. It fails if the tag points at another commit.
  **Do not re-run a run whose `release-workflow` already went out**: it would start it again
  on the same tag.

  When the run can no longer be re-run (GitHub allows it for 30 days), do it by hand. The
  tag is made on the runner, so a local clone often lacks it, or holds an old tag of the same
  name on another commit; fetch it first, and look at what it is:

  ```bash
  git fetch --force origin tag vX.Y.Z
  git cat-file -t vX.Y.Z   # "tag": annotated, "commit": lightweight
  ```

  If it is annotated, only the start failed: `gh workflow run <release-workflow> --ref vX.Y.Z`.
  If it is lightweight, make it annotated and push it:

  ```bash
  git tag -a -f -m "Release vX.Y.Z" vX.Y.Z 'vX.Y.Z^{commit}' && git push -f origin vX.Y.Z
  ```

  A tag pushed by hand starts `push: tags`. When `release-workflow` has that trigger, the
  push starts it, so do not also run `gh workflow run` (it would run twice on the tag);
  otherwise, start it with `gh workflow run` as above.

`.tagpr` for an npm package:

```ini
[tagpr]
	releaseBranch = main
	vPrefix = true
	versionFile = package.json
	changelog = false
	release = false
	postVersionCommand = node scripts/tagpr/release-prepare.mjs
	minorLabels = enhancement
```

The publish workflow that `tagpr.yml` starts (`release-workflow: publish.yml`) calls the
npm publish workflow here (see "The npm publish workflow" below).
[lily's workflows](https://github.com/kan/lily/tree/main/.github/workflows) are a complete
example: `tagpr.yml` starts `publish.yml` with `workflow_dispatch` on the new tag.

For a repository that keeps its version only in tags (Go, for example), set
`versionFile = -` and `postVersionCommand = node scripts/tagpr/release-prepare.mjs --changelog-only`.
[notify-slack's workflows](https://github.com/kan/notify-slack/tree/main/.github/workflows)
are a complete example with GoReleaser.

For a Tauri app, list every file that holds the version, and let `--cargo` bring
`Cargo.lock` along (drop `--changelog-only` when `package.json` is in the list too):

```ini
	versionFile = src-tauri/tauri.conf.json,src-tauri/Cargo.toml
	postVersionCommand = node scripts/tagpr/release-prepare.mjs --changelog-only --cargo src-tauri
```

All of the files listed are checked, `tauri.conf.json` included, so a wrapper does not need
to check them again.

For a repository that keeps its version in a `VERSION` file holding only the version, list
that file:

```ini
	versionFile = VERSION
	postVersionCommand = node scripts/tagpr/release-prepare.mjs --changelog-only
```

For a Perl module, list the module and every other file that holds the version, such as
the `META.json` that Minilla writes:

```ini
	versionFile = lib/Foo/Bar.pm,META.json
	postVersionCommand = node scripts/tagpr/release-prepare.mjs --changelog-only
```

With Minilla, set `manage_changes = false` in `minil.toml` once `Changes` is replaced by
`CHANGELOG.md`: `minil dist` otherwise tries to rewrite `Changes`.

The release branch does not have to be `main`. Set `releaseBranch` in `.tagpr` and
`on.push.branches` of the calling workflow to the same branch (`master`, for example).

### The npm publish workflow

`.github/workflows/publish-npm.yml` here is a reusable workflow that publishes a version
tag to npm with Trusted Publishing and then creates its GitHub release. Call it from the
workflow that `tagpr.yml` starts as `release-workflow`:

```yaml
name: Publish
on:
  push:
    tags: ['v*']
  workflow_dispatch:
concurrency:
  group: publish-${{ github.ref }}
  cancel-in-progress: false
permissions: {}
jobs:
  publish:
    uses: kan/tagpr-scripts/.github/workflows/publish-npm.yml@<commit SHA>
    permissions:
      contents: write  # read the repository, create the release
      id-token: write  # npm Trusted Publishing
    with:
      check: npm run lint && npm test
      access: public
```

- **Call it by the same commit SHA as `tagpr.yml` and `scripts/tagpr/`.**
  `verify-subtree.mjs` checks this line too.
- **Keep the name of the calling file.** npm's Trusted Publisher checks the name of the
  calling workflow, not of this one, so the Trusted Publisher stays registered with the
  repository's own file (`publish.yml`, say). Let it allow direct publishing: with only
  "npm stage publish" allowed, `npm publish` fails with "403 OIDC permission denied".
- **Keep the `concurrency` in the calling workflow**, one run per tag that is never
  cancelled: stopped halfway, a version could be on npm with no release. This workflow
  has none of its own, so the two do not deadlock.
- The jobs are split by what they may do. Dependency code (the install scripts of
  `npm ci`, the checks, the build) runs only in `build`, which can write nothing.
  `publish` (`id-token: write`) publishes the tarball from `build` with no checkout and no
  `npm ci`; `release` (`contents: write`) only makes the release.
- `build` runs only on a `refs/tags/v*` ref. Before `npm ci`, it checks that the tag is
  `v` + the version of `package.json` and of every `versionFile` of `.tagpr`, and that the
  tag's commit is on `releaseBranch` of `.tagpr` (`release-tag.mjs`), and that `release-notes.mjs` finds the tag's section of
  `CHANGELOG.md`.
- **A prerelease (`vX.Y.Z-rc.1`) goes to npm under the dist-tag `next`**, so it does not
  become `latest`, and its GitHub release is marked as a prerelease. `package.json` and
  every `versionFile` of `.tagpr` have to hold that version (`X.Y.Z-rc.1`) on the tagged
  commit, as for any other tag.
- A version that `npm view` cannot look up for a reason other than E404 (a registry error,
  say) fails the run instead of being published: whether it is already out is not known.
- The files of `release-files` are attached by their names, so two of them with the same
  name fail `build`, before anything is published.
- A version already on npm is not published again, so "Re-run all jobs" goes on to the
  release. A release that is already there gets the notes, the title and the files again.
  When only `release` fails, re-run it alone: `gh run rerun <run ID> --failed`.
- The release's title is the tag (`vX.Y.Z`), and its text is the tag's section of
  `CHANGELOG.md`.
- Inputs:
  - `check` (required): the commands to run after `npm ci`, with bash, from the root
    (`npm run typecheck && npm test`, say).
  - `check-tarball`: commands to run after `npm pack`, with the path of the tarball in
    `TARBALL`. For checks of what is published, such as installing it into a template.
  - `pack-ignore-scripts`: pass `--ignore-scripts` to `npm pack`, to pack the build that
    `check` made instead of building again in `prepare` (default `false`).
  - `access`: passed to `npm publish --access` (`public` for a public scoped package).
    Not passed when empty.
  - `release-files`: files to attach to the release, one path per line from the root,
    made by `check` (wema's `dist/wema.html`, say).
  - `timeout-minutes`: for the `build` job (default 30).
- If the repository pins its actions with `actions.lock`, run `gh actions-lock` after
  changing the calling file. The calling file then has no actions of its own.

### The CPAN publish workflow

`.github/workflows/publish-cpan.yml` here is a reusable workflow that uploads a version tag
of a Perl module made with Minilla to PAUSE and then creates its GitHub release. Call it
from the workflow that `tagpr.yml` starts as `release-workflow`:

```yaml
name: publish
on:
  push:
    tags: ['v*']
  workflow_dispatch:
concurrency:
  group: publish-${{ github.ref }}
  cancel-in-progress: false
permissions: {}
jobs:
  publish:
    uses: kan/tagpr-scripts/.github/workflows/publish-cpan.yml@<commit SHA>
    permissions:
      contents: write  # read the repository, create the release
    secrets: inherit
    with:
      cpanm-modules: Module::Build::Tiny
```

- **Call it by the same commit SHA as `tagpr.yml` and `scripts/tagpr/`.**
  `verify-subtree.mjs` checks this line too.
- **Keep `PAUSE_USER` and `PAUSE_PASSWORD` in an environment named `cpan` of the calling
  repository**, not in its repository secrets, so that only the `upload` job reads them.
  The `environment: cpan` of that job is the calling repository's. Pass
  `secrets: inherit` too; whether the job sees the environment's secrets without it has
  not been tried. Limit which refs may deploy to the environment (tags `v*`).
- **Keep the `concurrency` in the calling workflow**, one run per tag that is never
  cancelled: stopped after the upload, a version would be on CPAN with no release. This
  workflow has none of its own, so the two do not deadlock.
- The jobs are split by what they may do. Dependency code (Minilla, the modules from
  CPAN, the tests) runs only in `build`, which can write nothing. `upload` has no
  permissions and no checkout, and sends the tarball from `build` to PAUSE with curl;
  `release` (`contents: write`) only makes the release.
- **An upload cannot be taken back**: PAUSE never takes the same file name twice, so a
  version that went out broken needs a new version. `build` checks all it can first.
- `build` runs only on a `refs/tags/v*` ref. Before anything from CPAN is installed, it
  checks that the tag has no GitHub release yet (one that has went to PAUSE already),
  that every `versionFile` of `.tagpr` holds the tag's version and that the tag's commit
  is on `releaseBranch` (`release-tag.mjs`), and that `release-notes.mjs` finds the tag's
  section of `CHANGELOG.md`. A prerelease tag (`vX.Y.Z-rc.1`) fails: it is not a Perl
  version. `.tagpr` must have a `versionFile` (the module's `.pm` and `META.json`), or
  the run fails there.
- The tarball is made with `minil dist --no-test` (the tests ran before it), named from
  `name` of `META.json` and the version, and must not hold `scripts/tagpr/`: put
  `"^scripts/"` in `exclude_match` of `[FileGatherer]` in `minil.toml`.
- "Re-run all jobs" of a finished run stops at the check for a release. When only
  `release` fails, re-run it alone: `gh run rerun <run ID> --failed`.
- The release's title is the tag (`vX.Y.Z`), and its text is the tag's section of
  `CHANGELOG.md`.
- Inputs:
  - `test`: the commands to run after the dependencies are installed, with bash, from the
    root (default `prove -lr t`).
  - `cpanm-modules`: modules to install besides Minilla and Pod::Markdown::Github,
    separated by spaces (`Module::Build::Tiny` when `module_maker` of `minil.toml` is
    `ModuleBuildTiny`).
  - `perl-version`: given to actions-setup-perl (default `5.44`).
  - `timeout-minutes`: for the `build` job (default 30).
- If the repository pins its actions with `actions.lock`, run `gh actions-lock` after
  changing the calling file.

## Changing it

**Change this repository, never the copy in `scripts/tagpr/`.** Then, in each repository:

```bash
git subtree pull -S --prefix=scripts/tagpr https://github.com/kan/tagpr-scripts.git main --squash
```

In the same pull request, move every `uses: kan/tagpr-scripts/.github/workflows/<workflow>@<SHA>`
line (`tagpr.yml`, `tagpr-label.yml`, `publish-npm.yml`, `publish-cpan.yml`) to the commit of this repository just pulled: the `git-subtree-split` line in the
message of the squash commit, or `git ls-remote https://github.com/kan/tagpr-scripts.git main`.
The squash and merge commits in your repository do not exist here.

**Merge that pull request with a merge commit, even in a repository that squashes
everything else.** `git subtree` finds the last import from the commits it made; a squash
merge folds them away and breaks the next pull.

The whole repository comes along, `.github/` included. In `scripts/tagpr/.github/` it is
inert — GitHub only reads the root's — and it stays so the copy matches this repository.

```bash
node --test 'test/*.node-test.mjs'
```

**The tests are not named `*.test.mjs`.** Vitest's default `include` would pick them up
in the repositories that pull this in, and fail on them as files with no Vitest suite.
