/**
 * **publish の前に、タグを確かめる**（共通の workflow `publish-npm.yml` と `publish-cpan.yml` の
 * build のジョブ）。**repo のルートで、タグを checkout した状態で実行する。**
 *
 *     node scripts/tagpr/release-tag.mjs v1.2.4 >> "$GITHUB_OUTPUT"
 *
 * 次のどれかなら exit 1。
 *
 * - タグが `vX.Y.Z`（プレリリースの `vX.Y.Z-*`、ビルドメタデータの `vX.Y.Z+*` を含む）の形でない
 * - `package.json` があり、その版がタグの版でない。ずれたまま出すと、違う版が publish されるか、
 *   「同じ版は出せない」で落ちて、どちらも原因をタグ名から読めない
 * - `.tagpr` の `versionFile` のどれかの版がタグの版でない（`versionFileMismatch`。リリース PR で
 *   `release-prepare.mjs` が使う `checkVersionFiles` と同じ読み方。ここで拾うのは手で打ったタグ）
 * - `.tagpr` に `releaseBranch` が無い
 * - タグの commit（`HEAD`）が `origin/<releaseBranch>` の上に無い。手でほかのブランチに打った
 *   タグを出さない。`origin/<releaseBranch>` を読むので、履歴ごと checkout しておく
 *
 * 通れば、GitHub Actions の出力の形で次を出す。
 *
 * - `prerelease=true|false`: プレリリースのタグか（`isPrereleaseTag`。`release-notes.mjs` と同じ規則）
 * - `spec=<name>@<version>`: `package.json` があるときだけ。npm にもうあるかを確かめるための名前と版
 *
 * **Node の組み込みしか使わない**（ほかのスクリプトと同じ）。依存を入れる前に走らせるため。
 */
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { relative } from 'node:path';
import { ReleaseError, isPrereleaseTag, readRootFile, tagprConfig } from './changelog.mjs';
import { versionFileMismatch } from './version-files.mjs';

/** `package.json` を読む。無ければ `null` */
function readPackageJson() {
  if (!existsSync('package.json')) return null;
  try {
    return JSON.parse(readRootFile('package.json'));
  } catch (e) {
    if (!(e instanceof SyntaxError)) throw e;
    throw new ReleaseError(`package.json is not valid JSON: ${e.message}`);
  }
}

/**
 * @param {string} tag
 * @returns {{ prerelease: boolean, spec: string | null }}
 */
function checkTag(tag) {
  const version = /^v(\d+\.\d+\.\d+(?:[-+]\S+)?)$/.exec(tag)?.[1];
  if (!version) throw new ReleaseError(`${tag} is not a version tag (vX.Y.Z)`);
  const pkg = readPackageJson();
  if (pkg && pkg.version !== version) {
    throw new ReleaseError(`The tag ${tag} does not match version ${pkg.version} of package.json`);
  }
  const m = versionFileMismatch(version);
  if (m) throw new ReleaseError(`The tag ${tag} does not match version ${m.found} of ${m.path} (versionFile of .tagpr)`);
  const branch = tagprConfig('releaseBranch');
  if (!branch) throw new ReleaseError('.tagpr has no tagpr.releaseBranch');
  const r = spawnSync('git', ['merge-base', '--is-ancestor', 'HEAD', `origin/${branch}`], { encoding: 'utf8' });
  if (r.error) throw r.error;
  // 1 は祖先でない。ほかの非 0（origin/<branch> が無いなど）は git のエラー
  if (r.status === 1) throw new ReleaseError(`The commit of ${tag} is not on ${branch}`);
  if (r.status !== 0) {
    throw new ReleaseError(`Cannot see whether ${tag} is on ${branch} (fetch the whole history): ${r.stderr.trim()}`);
  }
  return { prerelease: isPrereleaseTag(tag), spec: pkg ? `${pkg.name}@${pkg.version}` : null };
}

const tag = process.argv[2];
if (!tag) {
  // 取り込み先では repo のルートから見たパス（`scripts/tagpr/release-tag.mjs`）になる
  console.error(`usage: node ${relative(process.cwd(), import.meta.filename)} <tag>`);
  process.exit(1);
}
try {
  const { prerelease, spec } = checkTag(tag);
  console.log(`prerelease=${prerelease}`);
  if (spec !== null) console.log(`spec=${spec}`);
} catch (e) {
  if (!(e instanceof ReleaseError)) throw e;
  console.error(e.message);
  process.exit(1);
}
