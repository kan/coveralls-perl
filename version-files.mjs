/**
 * **tagpr が書いた版のファイルを確かめる**（`release-prepare.mjs` の検査）。import しても何も
 * 実行しない。
 *
 * tagpr は `.tagpr` の `versionFile` に並べた各ファイルで、今の版の文字列の**最初の 1 か所**を
 * 書き換える。その前に同じ文字列（依存の版など）があると、そちらが書き換わり、本来の版の行は
 * 古いまま残る。何も落ちず、マージ後のタグは先頭のファイルの版から決まる。そこで、並べた全部の
 * ファイルで、本来の版の場所が提案の版になっているかを見る。
 */
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { basename, extname } from 'node:path';
import { readPackage } from './cargo-lock.mjs';
import { ReleaseError, readRootFile } from './changelog.mjs';

/** 作業ディレクトリ（repo のルート）からの相対パス */
const tagprPath = '.tagpr';

/**
 * `.tagpr` の `versionFile` の一覧。`.tagpr` が無いか、`versionFile = -`（版をタグだけで持つ）
 * なら空。読み方は tagpr と同じ git config の形式なので、`git config` に任せる。
 * @returns {string[]}
 */
function tagprVersionFiles() {
  let value;
  try {
    value = execFileSync('git', ['config', '--file', tagprPath, '--get', 'tagpr.versionFile'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  } catch (e) {
    // 終了コード 1 はキーが無い。ファイルが無いときも 1 になる
    if (e?.status === 1) return [];
    throw new ReleaseError(`Cannot read versionFile from ${tagprPath}: ${String(e?.stderr ?? e?.message).trim()}`);
  }
  if (value === '-') return [];
  return value.split(',').map((f) => f.trim()).filter((f) => f !== '');
}

/**
 * `VERSION` の版を読む。中身は版の文字列の 1 行だけ（末尾の LF は 1 つまで）。booch / booch-win の
 * 形（issue #8）。ほかの行があると、どれが本来の版かを決められないので落とす。
 * @param {string} text
 * @param {string} path
 * @returns {string}
 */
function readVersionOnly(text, path) {
  if (text.includes('\r')) {
    throw new ReleaseError(`${path} has CR line endings; save it with LF (on Windows, add \`VERSION text eol=lf\` to .gitattributes)`);
  }
  // BOM は見えないので、「1 行だけ」の誤りと分けて伝える（Windows のエディタが付けることがある）
  if (text.charCodeAt(0) === 0xfeff) throw new ReleaseError(`${path} starts with a BOM; save it as UTF-8 without a BOM`);
  const m = /^(\S+)\n?$/.exec(text);
  if (!m) throw new ReleaseError(`${path} must hold only the version, on one line`);
  return m[1];
}

/**
 * Perl のモジュール（`*.pm`）の版を読む。`our $VERSION = "X.Y.Z";` の形の行がちょうど 1 つあること
 * を求める（coveralls-perl の形、issue #12）。`__END__` / `__DATA__` より後と POD は読まない。
 * `$VERSION` への代入がほかにもあるか、引用符の文字列でない代入（`eval $VERSION` など）か、
 * `package NAME VERSION;` の形なら、どれが本来の版かを決められないので落とす。
 * @param {string} text
 * @param {string} path
 * @returns {string}
 */
function readPerlVersion(text, path) {
  const found = [];
  let pod = false;
  for (const [i, line] of text.split(/\r?\n/).entries()) {
    const at = `${path} line ${i + 1}`;
    if (pod) {
      if (/^=cut\b/.test(line)) pod = false;
      continue;
    }
    if (/^=[a-zA-Z]/.test(line)) {
      pod = true;
      continue;
    }
    if (/^__(?:END|DATA)__\b/.test(line)) break;
    if (/^\s*package\s+[\w:]+\s+v?\d/.test(line)) {
      throw new ReleaseError(`${at} gives the version as "package NAME VERSION"; only our $VERSION = "X.Y.Z"; can be checked`);
    }
    // `$VERSION` で始まる文（`$Foo::VERSION`、`our ($X, $VERSION)` も）だけを見る。コメントや文字列の
    // 中、式の途中の `$VERSION` は拾わない。始まる文は、決まった形でなければ（`||=`、`=~`、`eval`）落とす
    if (!/^\s*(?:(?:our|my|local)\s*)?(?:\([^)]*)?\$(?:[\w:]*::)?VERSION\b/.test(line)) continue;
    const m = /^\s*(?:our\s+)?\$VERSION\s*=\s*(["'])(\d[^"'$@\\\s]*)\1\s*;\s*(?:#.*)?$/.exec(line);
    if (!m) throw new ReleaseError(`${at} sets $VERSION in a form that cannot be checked; write it as our $VERSION = "X.Y.Z";`);
    found.push({ line: i + 1, version: m[2] });
  }
  if (found.length === 0) throw new ReleaseError(`${path} has no our $VERSION = "X.Y.Z"; line to check`);
  if (found.length > 1) {
    throw new ReleaseError(`${path} sets $VERSION more than once (lines ${found.map((f) => f.line).join(', ')}); keep only one`);
  }
  return found[0].version;
}

/**
 * 1 つのファイルの本来の版を読む。`.json` は最上位の `"version"`、`Cargo.toml` は `[package]` の
 * `version`、`VERSION` は中身の全体、`*.pm` は `$VERSION` の行。ほかの種類は、どこが本来の版かを
 * 決められないので落とす。
 * @param {string} path
 * @returns {string | undefined}
 */
function ownVersion(path) {
  const json = extname(path) === '.json';
  const perl = extname(path) === '.pm';
  const name = basename(path);
  if (!json && !perl && name !== 'Cargo.toml' && name !== 'VERSION') {
    throw new ReleaseError(
      `${path} is in versionFile of ${tagprPath}, but only *.json ("version"), Cargo.toml ([package] version), VERSION (the version alone) and *.pm (our $VERSION) can be checked`,
    );
  }
  // readRootFile の「ルートで実行せよ」は、ここでは versionFile の誤りのことが多い
  if (!existsSync(path)) throw new ReleaseError(`${path} is in versionFile of ${tagprPath}, but does not exist`);
  const text = readRootFile(path);
  if (name === 'VERSION') return readVersionOnly(text, path);
  if (perl) return readPerlVersion(text, path);
  if (!json) return readPackage(text, path).version;
  let data;
  try {
    data = JSON.parse(text);
  } catch (e) {
    throw new ReleaseError(`${path} is not valid JSON: ${e.message}`);
  }
  if (typeof data?.version !== 'string') {
    // 入れ子の版（Expo の expo.version など）は、どこが本来の版かを決められないので扱わない
    throw new ReleaseError(`${path} has no top-level "version" string to check`);
  }
  return data.version;
}

/**
 * `.tagpr` の `versionFile` の全部のファイルが、提案の版になっているかを確かめる。
 * package.json と Cargo.toml は npm-lock.mjs / cargo-lock.mjs も確かめるが、そちらは
 * 「versionFile に入っていない」ときに気付くためのもので、ここと役目が違う
 * @param {string} version tagpr が提案する版（`X.Y.Z`）
 */
export function checkVersionFiles(version) {
  for (const path of tagprVersionFiles()) {
    const found = ownVersion(path);
    if (found !== version) {
      throw new ReleaseError(
        `${path} says ${found}, but tagpr proposes ${version}. tagpr rewrites only the first occurrence of the current version in each versionFile; if the same string appears earlier in the file, that one was rewritten instead`,
      );
    }
  }
}
