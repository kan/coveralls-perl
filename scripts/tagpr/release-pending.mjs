/**
 * **出すものがあるかを判定する。** 共通の workflow（`.github/workflows/tagpr.yml`）が、tagpr の前に
 * 走らせる。**repo のルートで実行する。** 標準入力にタグの ref（`refs/tags/v1.2.3`）を 1 行に 1 つ
 * 受け取り、出すものがあれば `true`、無ければ `false` を標準出力に書く。理由は標準エラーに書く
 * （issue #13）。
 *
 *     gh api --paginate repos/OWNER/REPO/git/matching-refs/tags/ --jq '.[].ref' | node scripts/tagpr/release-pending.mjs
 *
 * 出すものが無いのは、`## [Unreleased]` が空で、最新のタグより新しい版の節も無いときだけ。
 * リリースの直後に CHANGELOG へ書かない変更を入れると、`release-prepare.mjs` が「空」で落ち、
 * 既定のブランチの CI が本当の失敗と見分けの付かない赤になる。中身の無いリリース PR もできる。
 * そのときは tagpr を走らせない。
 *
 * それ以外は `true` にして、tagpr に任せる。
 * - 最新のタグより新しい版の節がある: リリース PR のマージの run（タグを打つ）か、タグを打ち損ねた
 *   状態（`release-prepare.mjs` が落として知らせる）
 * - `## [Unreleased]` が無い、2 つある: `release-prepare.mjs` が理由を出して落とす
 *
 * 版のタグは `vX.Y.Z` だけを見る（取り込み先はすべて `vPrefix = true`）。プレリリース
 * （`v1.2.3-rc.1`）やほかの接頭辞（hokora の `sdk/v1.2.3`、`tagPrefix`）は数えない。数えないタグが
 * あっても、最新のタグが古く見えるだけで、`true`（tagpr を走らせる）の側に倒れる。版のタグが
 * 1 つも無ければ、版の節が 1 つでもあると `true` になる（タグの無い repo の最初のマージの run）。
 */
import { readFileSync } from 'node:fs';
import { ReleaseError, changelogPath, compareVersions, findSection, readRootFile, untaggedVersions } from './changelog.mjs';

/**
 * タグの ref の一覧から、最新の版を返す。版のタグが無ければ、tagpr と同じく `0.0.0`
 * @param {string} refs 1 行に 1 つの `refs/tags/...`
 * @returns {string}
 */
function latestVersion(refs) {
  let latest = '0.0.0';
  for (const ref of refs.split('\n')) {
    const m = /^refs\/tags\/v(\d+\.\d+\.\d+)$/.exec(ref.trim());
    if (m && compareVersions(m[1], latest) > 0) latest = m[1];
  }
  return latest;
}

/**
 * 出すものがあるかと、その理由
 * @param {string} text CHANGELOG.md の中身
 * @param {string} latest 最新のタグの版
 * @returns {{ pending: boolean, reason: string }}
 */
function releasePending(text, latest) {
  let unreleased;
  try {
    unreleased = findSection(text, 'Unreleased');
  } catch (e) {
    if (!(e instanceof ReleaseError)) throw e;
    return { pending: true, reason: e.message };
  }
  if (unreleased === null) return { pending: true, reason: 'CHANGELOG.md has no "## [Unreleased]" section' };
  if (unreleased !== '') return { pending: true, reason: '"## [Unreleased]" has entries' };
  const [oldest] = untaggedVersions(text, latest);
  if (oldest !== undefined) {
    return { pending: true, reason: `CHANGELOG.md has "## [${oldest}]", newer than the latest tag v${latest}` };
  }
  return {
    pending: false,
    reason: `"## [Unreleased]" of CHANGELOG.md is empty, and no section is newer than the latest tag v${latest}: nothing to release`,
  };
}

try {
  const { pending, reason } = releasePending(readRootFile(changelogPath), latestVersion(readFileSync(0, 'utf8')));
  console.error(reason);
  console.log(String(pending));
} catch (e) {
  if (!(e instanceof ReleaseError)) throw e;
  console.error(e.message);
  process.exit(1);
}
