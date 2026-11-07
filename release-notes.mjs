/**
 * **`CHANGELOG.md` の 1 つの節の本文を出す**（見出しは含めない）。**repo のルートで実行する。**
 *
 *     node scripts/tagpr/release-notes.mjs 0.6.0        # "## [0.6.0] - <日付>" の節
 *     node scripts/tagpr/release-notes.mjs v0.6.0       # タグ。その版の節
 *     node scripts/tagpr/release-notes.mjs v0.6.0-rc.1  # プレリリースのタグ。Unreleased の節
 *     node scripts/tagpr/release-notes.mjs Unreleased
 *
 * publish のワークフローがタグを渡し、出力を GitHub Release の本文にする。段落と項目の
 * 中の折り返しは 1 行につないで出す（`unwrapLines`。GitHub は改行をそのまま表示するため）。
 * プレリリースは tagpr を通さず main に手で打つので、その変更はまだ `## [Unreleased]` にある
 * （roji がこの使い方をしている）。
 * 節が無いか、重複しているか、空なら exit 1（読み方は `changelog.mjs`）。
 */
import { relative } from 'node:path';
import { ReleaseError, changelogPath, readRootFile, readSection, unwrapLines } from './changelog.mjs';

const arg = process.argv[2];
if (!arg) {
  // 取り込み先では repo のルートから見たパス（`scripts/tagpr/release-notes.mjs`）になる
  console.error(`usage: node ${relative(process.cwd(), import.meta.filename)} <version|tag|Unreleased>`);
  process.exit(1);
}
// タグ（`v0.6.0`）は節の名前（`0.6.0`）に、プレリリースのタグ（`v0.6.0-rc.1`）は `Unreleased` にする
const name = /^v\d+\.\d+\.\d+-/.test(arg) ? 'Unreleased' : /^v\d/.test(arg) ? arg.slice(1) : arg;
try {
  console.log(unwrapLines(readSection(readRootFile(changelogPath), name)));
} catch (e) {
  if (!(e instanceof ReleaseError)) throw e;
  console.error(e.message);
  process.exit(1);
}
