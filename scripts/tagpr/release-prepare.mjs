/**
 * **リリース PR の中身を作る。** tagpr が `postVersionCommand`（`.tagpr`）として、
 * リリースのブランチ（main など）からリリース PR を作り直すたびに走らせる。**repo のルートで実行する。**
 *
 *     TAGPR_CURRENT_VERSION=vX.Y.Z TAGPR_NEXT_VERSION=vX.Y.Z node scripts/tagpr/release-prepare.mjs
 *     TAGPR_CURRENT_VERSION=vX.Y.Z TAGPR_NEXT_VERSION=vX.Y.Z node scripts/tagpr/release-prepare.mjs --changelog-only
 *     TAGPR_CURRENT_VERSION=vX.Y.Z TAGPR_NEXT_VERSION=vX.Y.Z node scripts/tagpr/release-prepare.mjs --cargo src-tauri
 *
 * `TAGPR_CURRENT_VERSION` は最新のタグ、`TAGPR_NEXT_VERSION` は tagpr が提案する版。
 * どちらも tagpr が渡す。
 *
 * 0. `.tagpr` の `versionFile` の全部のファイルが、提案の版になっているかを確かめる
 *    （`version-files.mjs`。tagpr は各ファイルで今の版の最初の 1 か所だけを書き換えるため）
 * 1. `package-lock.json` の版を `package.json` に揃える（`npm-lock.mjs`）。
 *    `--changelog-only` では `package.json` も lock も読まない（版のファイルが無い repo や、
 *    版と lock を自分のラッパーで揃える repo 向け）
 * 2. `--cargo <dir>` を付けたら、`<dir>/Cargo.lock` の自分のパッケージの版を
 *    `<dir>/Cargo.toml` に揃える（`cargo-lock.mjs`）。Cargo.toml は tagpr が `versionFile` として書く
 * 3. `CHANGELOG.md` の `## [Unreleased]` を `## [X.Y.Z] - <日本時間の日付>` にし、
 *    その上に空の `## [Unreleased]` を置き直し、末尾のリンク定義の先頭にその版の
 *    リンクを足す（`changelog.mjs` の `stampRelease`）。リンク先の repo は
 *    Actions では `GITHUB_REPOSITORY`、それ以外では `origin` から決める
 *
 * **検査をすべて済ませてから書く。** 落ちるときは何も書き換えない（tagpr は失敗しても
 * リリース PR を更新するので、版だけ上がった PR を残さない）。それでも run が赤なら、
 * そのリリース PR はマージしない。
 *
 * **Node の組み込みしか使わない** —— このジョブはリポジトリへ push できるトークンを
 * 持つので、依存のコードを走らせない。
 */
import { writeFileSync } from 'node:fs';
import { relative } from 'node:path';
import { parseArgs } from 'node:util';
import { ReleaseError, changelogPath, currentGithubRepo, readRootFile, releaseDate, stampRelease } from './changelog.mjs';
import { syncCargoLock } from './cargo-lock.mjs';
import { lockPath, syncPackageLock } from './npm-lock.mjs';
import { checkVersionFiles } from './version-files.mjs';

/** `[--changelog-only] [--cargo <dir>]` を読む。知らない引数や値の無い `--cargo` は使い方を出して落とす */
function readArgs(args) {
  // 取り込み先では repo のルートから見たパス（`scripts/tagpr/release-prepare.mjs`）になる
  const usage = () =>
    new ReleaseError(
      `usage: node ${relative(process.cwd(), import.meta.filename)} [--changelog-only] [--cargo <dir>] (got: ${args.join(' ')})`,
    );
  let values;
  try {
    // --cargo は複数を受けてから 1 つに限る（parseArgs は既定で最後の 1 つを黙って残す）
    ({ values } = parseArgs({
      args,
      options: { 'changelog-only': { type: 'boolean' }, cargo: { type: 'string', multiple: true } },
      strict: true,
    }));
  } catch {
    // 知らない引数、値の無い --cargo。parseArgs の文言は Node の版で変わるので出さない
    throw usage();
  }
  if ((values.cargo?.length ?? 0) > 1) throw usage();
  return { changelogOnly: values['changelog-only'] === true, cargoDir: values.cargo?.[0] ?? null };
}

/** 環境変数の `vX.Y.Z` から `X.Y.Z` を取り出す。形が違えば落とす */
function versionFromEnv(name) {
  const value = process.env[name] ?? '';
  const version = value.replace(/^v/, '');
  if (!/^\d+\.\d+\.\d+$/.test(version)) {
    throw new ReleaseError(`${name} must be vX.Y.Z, got "${value}"`);
  }
  return version;
}

try {
  const { changelogOnly, cargoDir } = readArgs(process.argv.slice(2));
  const version = versionFromEnv('TAGPR_NEXT_VERSION');
  const current = versionFromEnv('TAGPR_CURRENT_VERSION');

  // --- 検査（ここでは何も書かない） ---

  checkVersionFiles(version);
  const lock = changelogOnly ? null : syncPackageLock(version);
  const cargoLock = cargoDir === null ? null : syncCargoLock(version, cargoDir);
  const changelog = stampRelease(readRootFile(changelogPath), {
    version,
    current,
    repo: currentGithubRepo(),
    date: releaseDate(),
  });

  // --- 書き換え ---

  if (lock !== null) {
    writeFileSync(lockPath, lock);
    console.log(`${lockPath}: -> ${version}`);
  }
  if (cargoLock !== null) {
    writeFileSync(cargoLock.path, cargoLock.text);
    console.log(`${cargoLock.path}: -> ${version}`);
  }
  writeFileSync(changelogPath, changelog);
  console.log(`CHANGELOG.md: "## [Unreleased]" -> "## [${version}]"`);
} catch (e) {
  if (!(e instanceof ReleaseError)) throw e;
  console.error(e.message);
  process.exit(1);
}
