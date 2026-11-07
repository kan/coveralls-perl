/**
 * **打たれなかったタグを探すための、CHANGELOG の読み取り（issue #4）。** 共通の workflow
 * （`.github/workflows/tagpr.yml`）の missed のジョブが、tagpr の前に使う。GitHub の API は
 * workflow の側で呼び、ここは CHANGELOG を読むだけにする。
 *
 *     node scripts/tagpr/missed-tags.mjs untagged < タグの ref の一覧
 *     node scripts/tagpr/missed-tags.mjs latest < タグの ref の一覧
 *     node scripts/tagpr/missed-tags.mjs newest < ある commit の CHANGELOG.md
 *
 * - `untagged`: repo のルートの CHANGELOG.md で、最新のタグより新しい版の節を古い順に 1 行に 1 つ
 *   書く。版のタグが 1 つも無ければ何も書かない（タグの無い repo の最初のマージの run は tagpr が打つ。
 *   打ち損ねを見分けられない）
 * - `latest`: 最新の版のタグの版（`X.Y.Z`。`v` は付けない）を書く。無ければ `0.0.0`
 * - `newest`: 標準入力の CHANGELOG のいちばん新しい版の見出しを書く。版の節が無ければ何も書かない。
 *   リリース PR のマージコミットの CHANGELOG に使い、そのマージがどの版のリリースかを決める
 *
 * **Node の組み込みしか使わない**（ほかのスクリプトと同じ）。
 */
import { readFileSync } from 'node:fs';
import { ReleaseError, changelogPath, latestVersion, readRootFile, untaggedVersions } from './changelog.mjs';

const usage = 'usage: missed-tags.mjs untagged|latest|newest < input';

try {
  const input = readFileSync(0, 'utf8');
  switch (process.argv[2]) {
    case 'untagged': {
      const latest = latestVersion(input);
      if (latest === '0.0.0') break;
      for (const v of untaggedVersions(readRootFile(changelogPath), latest)) console.log(v);
      break;
    }
    case 'latest':
      console.log(latestVersion(input));
      break;
    case 'newest': {
      const newest = untaggedVersions(input, '0.0.0').at(-1);
      if (newest !== undefined) console.log(newest);
      break;
    }
    default:
      throw new ReleaseError(usage);
  }
} catch (e) {
  if (!(e instanceof ReleaseError)) throw e;
  console.error(e.message);
  process.exit(1);
}
