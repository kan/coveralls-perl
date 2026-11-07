/**
 * **npm パッケージの版と lock**（`release-prepare.mjs` の npm の側）。import しても何も実行しない。
 * CHANGELOG の処理（`changelog.mjs`）とは分けてある。npm でない repo は
 * `release-prepare.mjs --changelog-only` で、ここを通らない。
 */
import { ReleaseError, readRootFile } from './changelog.mjs';

/** 作業ディレクトリ（repo のルート）からの相対パス */
export const lockPath = 'package-lock.json';

/**
 * `package-lock.json` の版を、tagpr が書き換えた `package.json` の版に揃えた中身を返す。
 * 揃っていれば `null`。ファイルには書かない。**lock は tagpr に任せない**: tagpr は
 * `package-lock.json` を自動では探さず、versionFile に書けば書き換えるが、今の版の最初の 1 か所
 * だけなので、`version` と `packages[""].version` の 2 か所が揃わない。
 * @param {string} version tagpr が提案する版（`X.Y.Z`）
 * @returns {string | null}
 */
export function syncPackageLock(version) {
  const pkg = JSON.parse(readRootFile('package.json'));
  // tagpr が package.json を書き換えた後に走るので、ずれていたら tagpr の設定の誤り
  if (pkg.version !== version) {
    throw new ReleaseError(`package.json says ${pkg.version}, but tagpr proposes ${version} (check versionFile in .tagpr)`);
  }
  const lock = JSON.parse(readRootFile(lockPath));
  const self = lock.packages?.[''];
  if (!self) throw new ReleaseError('package-lock.json has no packages[""] (lockfileVersion 2 or later is required)');
  if (lock.version === version && self.version === version) return null;
  lock.version = version;
  self.version = version;
  // npm と同じ書き方（2 スペース + 末尾の改行）。違うと差分が全行に出る
  return `${JSON.stringify(lock, null, 2)}\n`;
}
