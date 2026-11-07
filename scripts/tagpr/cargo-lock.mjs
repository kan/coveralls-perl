/**
 * **Cargo のパッケージの版と lock**（`release-prepare.mjs --cargo <dir>` の側）。import しても
 * 何も実行しない。`npm-lock.mjs` と同じ分担で、版を書くのは tagpr（`.tagpr` の `versionFile` に
 * `<dir>/Cargo.toml` を並べる）、ここは版を確かめて `Cargo.lock` を揃えるだけ。
 *
 * `cargo` は呼ばない。tagpr のジョブはリポジトリへ push できるトークンを持つので、ネットワークにも
 * 出ず、lock の自分の行だけを書き換える（`cargo update --workspace` と同じ結果になる）。
 */
import { existsSync } from 'node:fs';
// メッセージのパスを OS によらず `/` で出す（`.tagpr` の versionFile と同じ書き方）。
// Windows でも `/` 区切りのパスで読める
import { posix } from 'node:path';
import { ReleaseError, readRootFile } from './changelog.mjs';

/**
 * `<dir>/Cargo.toml` の `[package]` の `name` と `version` を読む。tagpr は版の文字列の最初の
 * 1 か所を書き換えるだけなので、`[package]` の版が提案と違えば、tagpr が別の行を書き換えたか、
 * `versionFile` に入っていない。
 * @param {string} text Cargo.toml の中身
 * @param {string} path メッセージに出すパス
 */
export function readPackage(text, path) {
  const lines = text.split('\n');
  // 表の見出しの行（`[x]` / `[[x]]`、後ろにコメントがあってもよい）。配列の続きの行
  // （`  ["a", "b"],`）は末尾が `]` で終わらないので当たらない
  const header = /^\s*\[\[?\s*([^\]]+?)\s*\]\]?\s*(?:#.*)?$/;
  const start = lines.findIndex((l) => header.exec(l)?.[1] === 'package');
  if (start === -1) throw new ReleaseError(`${path} has no [package] table`);
  const end = lines.findIndex((l, i) => i > start && header.test(l));
  const table = lines.slice(start + 1, end === -1 ? undefined : end);
  const field = (key) => {
    // 基本の文字列（"..."）とリテラルの文字列（'...'）
    const re = new RegExp(`^\\s*${key}\\s*=\\s*(?:"([^"]*)"|'([^']*)')`);
    const hits = table.map((l) => l.match(re)).filter(Boolean);
    if (hits.length !== 1) {
      // `version.workspace = true` などの、文字列でない書き方は扱わない
      throw new ReleaseError(`${path}: expected one ${key} = "..." in [package], found ${hits.length}`);
    }
    return hits[0][1] ?? hits[0][2];
  };
  return { name: field('name'), version: field('version') };
}

/**
 * `<dir>/Cargo.lock` の自分のパッケージの版を、tagpr が書き換えた `<dir>/Cargo.toml` の版に
 * 揃えた中身を返す。揃っていれば `null`。ファイルには書かない。**lock は tagpr に任せない**:
 * tagpr は `*.lock` を自動では探さず、versionFile に書けば書き換えるが、今の版の最初の 1 か所だけ
 * なので、同じ版の依存クレートの行に当たりうる。
 * @param {string} version tagpr が提案する版（`X.Y.Z`）
 * @param {string} dir Cargo.toml と Cargo.lock のあるディレクトリ（repo のルートからの相対パス）
 * @returns {{ path: string, text: string } | null}
 */
export function syncCargoLock(version, dir) {
  const manifestPath = posix.join(dir, 'Cargo.toml');
  const path = posix.join(dir, 'Cargo.lock');
  // readRootFile の「ルートで実行せよ」は、ここでは原因と違うことが多い（lock が workspace の
  // ルートにある、など）ので、先に確かめて別のことを言う
  for (const p of [manifestPath, path]) {
    if (!existsSync(p)) {
      throw new ReleaseError(
        `${p} not found: --cargo <dir> needs Cargo.toml and Cargo.lock in that directory, relative to the repository root (a workspace whose Cargo.lock is elsewhere is not supported)`,
      );
    }
  }
  const pkg = readPackage(readRootFile(manifestPath), manifestPath);
  if (pkg.version !== version) {
    throw new ReleaseError(
      `${manifestPath} says ${pkg.version} in [package], but tagpr proposes ${version} (check versionFile in .tagpr)`,
    );
  }
  const lock = readRootFile(path);
  if (lock.includes('\r')) {
    throw new ReleaseError(`${path} has CR line endings; save it with LF (on Windows, add \`Cargo.lock text eol=lf\` to .gitattributes)`);
  }
  // 自分のパッケージ（workspace のメンバー）は `source` の行を持たない。同じ名前のクレートが
  // レジストリにあっても、そちらは `source` の行があるので当たらない
  const name = pkg.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const entry = new RegExp(`^(\\[\\[package\\]\\]\\nname = "${name}"\\nversion = ")([^"]*)("\\n)(?!source = )`, 'gm');
  const hits = [...lock.matchAll(entry)];
  if (hits.length !== 1) {
    throw new ReleaseError(`${path}: expected one [[package]] for ${pkg.name} without a source, found ${hits.length}`);
  }
  const [hit] = hits;
  if (hit[2] === version) return null;
  // 版の文字列だけを差し替える（前後は元のまま）
  const at = hit.index + hit[1].length;
  return { path, text: lock.slice(0, at) + version + lock.slice(at + hit[2].length) };
}
