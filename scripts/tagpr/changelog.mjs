/**
 * **`CHANGELOG.md` の読み方と書き換え方、2 つのスクリプトが共有する決め方。** import しても
 * 何も実行しない（`release-notes.mjs` と `release-prepare.mjs` が import する）。
 * **npm に依存しない**（`package.json` を読まない）。npm の版と lock は `npm-lock.mjs`。
 *
 * **読み方はここにしか書かない。** 2 か所に書くと、リリース PR は通るのに publish の
 * 検査で落ちる。
 *
 * - 節の見出しは `## [名前]` か `## [名前] ...`。コードフェンスの中の見出しは数えない
 * - **節はファイル末尾のリンク定義のまとまり（`[x]: url` と空行だけが続く部分）の手前で
 *   終わる。** 項目の中にある `[x]: ...` の形の行では終わらない
 * - 改行は LF だけ
 */
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

/** 作業ディレクトリ（repo のルート）からの相対パス */
export const changelogPath = 'CHANGELOG.md';

/** 入力が要求を満たさない。呼んだ側はメッセージを出して exit 1 する */
export class ReleaseError extends Error {}

/** repo のルートにあるはずのファイルを読む。無ければ、どこで実行すべきかを言って落ちる */
export function readRootFile(name) {
  try {
    return readFileSync(name, 'utf8');
  } catch (e) {
    if (e?.code === 'ENOENT') {
      throw new ReleaseError(`${name} not found in ${process.cwd()}; run this from the repository root`);
    }
    throw e;
  }
}

const isLinkDefinition = (line) => /^\[[^\]]+\]: /.test(line);
const isSectionHeading = (line, name) =>
  line === `## [${name}]` || line.startsWith(`## [${name}] `);

// CommonMark のフェンス: 同じ記号 3 つ以上。閉じるのは開いたときと同じ記号で、同じ長さ
// 以上で、後ろに何も無い行。字下げは問わない（CommonMark の上限は 3 文字だが、入れ子の
// 項目の中のフェンスは 4 文字以上になる。CHANGELOG に字下げのコードブロックは書かない前提）
const FENCE = /^ *(`{3,}|~{3,})(.*)$/;

/**
 * 各行を `[行, コードフェンスの中か]` にする。フェンスを開く行は中、閉じる行は外に数える。
 * **フェンスの追い方はここだけに書く。**
 * @param {string} text
 * @returns {[string, boolean][]}
 */
function scan(text) {
  if (text.includes('\r')) {
    throw new ReleaseError(
      'CHANGELOG.md has CR line endings; save it with LF (on Windows, add `CHANGELOG.md text eol=lf` to .gitattributes)',
    );
  }
  /** @type {string | null} 開いているフェンスの記号の並び */
  let open = null;
  /** @type {[string, boolean][]} */
  const rows = [];
  for (const line of text.split('\n')) {
    const m = FENCE.exec(line);
    if (open === null) {
      // バッククォートのフェンスの info string にはバッククォートを書けない
      if (m && !(m[1][0] === '`' && m[2].includes('`'))) open = m[1];
      rows.push([line, open !== null]);
    } else if (m && m[1][0] === open[0] && m[1].length >= open.length && m[2].trim() === '') {
      open = null;
      rows.push([line, false]);
    } else {
      rows.push([line, true]);
    }
  }
  return rows;
}

/**
 * ファイル末尾のリンク定義のまとまりの、最初の定義の行番号。無ければ `rows.length`。
 * @param {[string, boolean][]} rows `scan` の結果
 */
function linkBlockStart(rows) {
  let start = rows.length;
  for (let i = rows.length - 1; i >= 0; i--) {
    const [line, fenced] = rows[i];
    if (line.trim() === '') continue;
    if (fenced || !isLinkDefinition(line)) break;
    start = i;
  }
  return start;
}

/**
 * `## [X.Y.Z]` の見出しの版を、出てくる順に返す（`Unreleased` は入れない）。
 * コードフェンスの中と、末尾のリンク定義のまとまりは見ない。
 * @param {string} text CHANGELOG.md の中身
 * @returns {string[]}
 */
export function versionHeadings(text) {
  const rows = scan(text);
  return rows
    .slice(0, linkBlockStart(rows))
    .flatMap(([line, fenced]) => {
      const m = fenced ? null : /^## \[(\d+\.\d+\.\d+)\](?: |$)/.exec(line);
      return m ? [m[1]] : [];
    });
}

/**
 * `X.Y.Z` どうしを比べる。`a` が新しければ正、古ければ負、同じなら 0。
 * @param {string} a
 * @param {string} b
 */
export function compareVersions(a, b) {
  const [pa, pb] = [a, b].map((v) => v.split('.').map(Number));
  for (let i = 0; i < 3; i++) {
    if (pa[i] !== pb[i]) return pa[i] - pb[i];
  }
  return 0;
}

/**
 * 最新のタグより新しい版の節を、古い順に返す。`current` が `0.0.0`（タグが 1 つも無い）なら、すべての
 * 版の節。`stampRelease` と `release-pending.mjs` が同じ規則で見るためにここに置く
 * @param {string} text CHANGELOG.md の中身
 * @param {string} current 最新のタグの版（`X.Y.Z`）
 * @returns {string[]}
 */
export function untaggedVersions(text, current) {
  return versionHeadings(text)
    .filter((v) => compareVersions(v, current) > 0)
    .sort(compareVersions);
}

/**
 * `## [name]` の節の本文を、前後の空行を落として返す。節が無ければ `null`、
 * 空なら `''`。**重複だけは投げる**（どちらが正か決められないため）。
 * @param {string} text CHANGELOG.md の中身
 * @param {string} name 版（`0.6.0`）か `Unreleased`
 * @returns {string | null}
 */
export function findSection(text, name) {
  const rows = scan(text);
  const end = linkBlockStart(rows);
  let inside = false;
  let found = 0;
  /** @type {string[]} */
  const body = [];
  for (const [line, fenced] of rows.slice(0, end)) {
    if (!fenced && line.startsWith('## ')) {
      inside = isSectionHeading(line, name);
      if (inside) {
        found++;
        continue;
      }
    }
    if (inside) body.push(line);
  }
  if (found === 0) return null;
  if (found > 1) {
    throw new ReleaseError(`CHANGELOG.md has ${found} "## [${name}]" sections; expected 1`);
  }
  const blank = (line) => line.trim() === '';
  while (body.length > 0 && blank(body[0])) body.shift();
  while (body.length > 0 && blank(body[body.length - 1])) body.pop();
  return body.join('\n');
}

/** `findSection` の、無いことも空であることも許さない版。リリースノートに使う */
export function readSection(text, name) {
  const body = findSection(text, name);
  if (body === null) {
    throw new ReleaseError(`CHANGELOG.md has no "## [${name}]" section`);
  }
  if (body === '') {
    throw new ReleaseError(`The "## [${name}]" section of CHANGELOG.md is empty`);
  }
  return body;
}

// 箇条書きの項目を始める行（字下げを除いた先頭で見る）。前の行にはつながないが、
// 次の行はつないでよい
const LIST_ITEM = /^(?:[-*+]|\d+[.)])(?:\s|$)/;
// 前後どちらともつながない行（字下げを除いた先頭で見る）: 見出し、引用、表の外側の `|`、
// HTML のブロック（`<https://...>` のような autolink は除く）、区切り線、setext の下線。
// コードフェンスは `FENCE` で、外側の `|` の無い表は区切りの行から別に見る
const STANDALONE = /^(?:#{1,6}(?:\s|$)|>|\||<(?![A-Za-z][\w+.-]*:)[A-Za-z/!?]|(?:[-*_]\s*){3,}$|=+\s*$)/;
// 表の区切りの行（`--- | ---`、`|:--|--:|`）
const TABLE_DELIMITER = /^\|?\s*:?-+:?\s*(?:\|\s*:?-+:?\s*)+\|?$/;
// 日本語の文字（漢字、かな、全角の記号と英数字）。この文字どうしの間の改行は空白にしない。
// Script_Extensions で見るのは、「ー」「・」が Script では Common になるため。
// 範囲はエスケープで書く（全角スペースをそのまま書くと、取り込み先の eslint の
// no-irregular-whitespace に当たる）。U+3000-U+303F は CJK の記号と句読点、
// U+FF00-U+FFEF は全角と半角の形
const CJK = /[\p{scx=Han}\p{scx=Hiragana}\p{scx=Katakana}\u{3000}-\u{303F}\u{FF00}-\u{FFEF}]/u;
// 全角の句読点と括弧（、。，．・「」（）【】など）。前後の相手が英数字でも空白を入れない。
// U+30FB は「・」、U+FF01-U+FF65 のうち英数字（０-９ Ａ-Ｚ ａ-ｚ）を除いたもの
const CJK_PUNCT = /[\u{3000}-\u{303F}\u{30FB}\u{FF01}-\u{FF0F}\u{FF1A}-\u{FF20}\u{FF3B}-\u{FF40}\u{FF5B}-\u{FF65}]/u;
// 強制改行: 行末の空白 2 つ以上か `\`
const HARD_BREAK = /(?: {2}|\\)$/;

/**
 * **段落と箇条書きの中の折り返しを 1 行につなぐ。** GitHub の Release は本文の改行を
 * そのまま改行として表示するので、80 桁ほどで折り返した CHANGELOG をそのまま渡すと、
 * 項目の途中で改行が入る。CHANGELOG のファイルは折り返したままでよい。
 *
 * - つなぐのは、前の行が段落か項目の本文で、次の行が新しいブロックを始めない行のとき。
 *   コードフェンスの中、見出し、表、引用、HTML のブロック、区切り線、強制改行（行末の
 *   空白 2 つか `\`）はつながない
 * - 数字とピリオドで始まる行（`2026. ...`）は、番号付きの次の項目と区別できないので
 *   つながない。字下げのコードブロックは、項目の続きの行と区別できないので扱わない
 * - 前の行の末尾と次の行の先頭がどちらも日本語の文字なら、間に何も入れない。どちらかが
 *   全角の句読点か括弧（「、」「（」など）でも何も入れない（「、govulncheck」）。
 *   それ以外は空白 1 つ（英文のほか、「の `x`」のような日本語と英数字の間も空白になる）
 * @param {string} body 節の本文（`readSection` の結果）
 * @returns {string}
 */
export function unwrapLines(body) {
  const rows = scan(body);
  // 表の行: 区切りの行と、その直前の見出しの行と、その後の行。表は空行か、別のブロックを
  // 始める行（引用、項目、フェンスなど）で終わる（GFM）
  const table = new Set();
  const endsTable = (line) => {
    const text = line.trim();
    return text === '' || FENCE.test(line) || LIST_ITEM.test(text) || (!text.startsWith('|') && STANDALONE.test(text));
  };
  rows.forEach(([line, fenced], i) => {
    if (fenced || i === 0 || !TABLE_DELIMITER.test(line.trim()) || !rows[i - 1][0].includes('|')) return;
    table.add(i - 1);
    for (let j = i; j < rows.length && !endsTable(rows[j][0]); j++) table.add(j);
  });

  /** @type {{ line: string, joinable: boolean }[]} */
  const out = [];
  rows.forEach(([line, fenced], i) => {
    const text = line.trim();
    // 段落か項目の本文の行か（コードフェンス、表、見出しなどではない）
    const prose = !fenced && !FENCE.test(line) && !table.has(i) && text !== '' && !STANDALONE.test(text);
    const prev = out[out.length - 1];
    if (prose && !LIST_ITEM.test(text) && prev?.joinable) {
      const head = prev.line.trimEnd();
      // 前の行の最後の文字と次の行の最初の文字（サロゲートペアも 1 文字に数える）
      const [last, first] = [[...head].at(-1), String.fromCodePoint(text.codePointAt(0))];
      const sep = (CJK.test(last) && CJK.test(first)) || CJK_PUNCT.test(last) || CJK_PUNCT.test(first) ? '' : ' ';
      // 前の行の末尾の空白は落とす（強制改行の行はつながないので、普通の空白しか無い）。
      // 次の行の末尾の空白は残す（強制改行の空白 2 つを消さない）
      prev.line = head + sep + line.trimStart();
      prev.joinable = !HARD_BREAK.test(line);
      return;
    }
    out.push({ line, joinable: prose && !HARD_BREAK.test(line) });
  });
  return out.map((r) => r.line).join('\n');
}

/**
 * **リリースの節を作る**（`release-prepare.mjs` の CHANGELOG の側）。書き換えた中身を返し、
 * ファイルには書かない。要求を満たさなければ `ReleaseError` を投げる。
 *
 * `## [Unreleased]` を `## [version] - <date>` にし、その上に空の `## [Unreleased]` を
 * 置き直し、末尾のリンク定義の先頭に `[version]: https://github.com/<repo>/releases/tag/v<version>`
 * を足す。
 * @param {string} text CHANGELOG.md の中身
 * @param {{ version: string, current: string, repo: string, date: string }} release
 *   `version` は提案する版、`current` は最新のタグの版（どちらも `X.Y.Z`）、`repo` は `owner/repo`
 * @returns {string}
 */
export function stampRelease(text, { version, current, repo, date }) {
  // **最新のタグより新しい版の節があれば落とす。** tagpr はリリース PR のブランチを毎回
  // リリースのブランチ（main など）から作り直すので、その節があるのは、そこにリリース PR が
  // 入ったのにタグが打たれていないとき（タグを打ち直すために消している間も同じ）。
  //
  // 提案する版の節だけを見ると、間に `enhancement` の PR が入ったときに通ってしまう。
  // tagpr は最新のタグから数えるので、0.17.1 のタグが無いまま minor の 0.18.0 を提案し、
  // 「タグの無い 0.17.1 の上に 0.18.0 を積んだ」リリース PR が緑のまま作られる。
  //
  // タグが 1 つも無いと tagpr は `v0.0.0` を渡す。そのときは比べる相手が無いので見ない
  // （タグを打たずにリリースしてきた repo が tagpr へ移ると、古い節がすべて引っかかる）。
  const untagged = current === '0.0.0' ? [] : untaggedVersions(text, current);
  if (untagged.length > 0) {
    // 古い順にすべて出す。新しい方だけ直すと、古い方はそのタグより古くなって見えなくなる
    const sections = untagged.map((v) => `"## [${v}]"`).join(', ');
    throw new ReleaseError(
      `CHANGELOG.md already has ${sections}, newer than the latest tag v${current}: ` +
        'a release pull request was merged but not tagged. ' +
        `Re-run the tagpr run of the merge commit for ${untagged[0]} first (or push the tag again) ` +
        'instead of merging a new release pull request',
    );
  }
  // 無いか空なら、ここで理由を出して落ちる
  readSection(text, 'Unreleased');

  const rows = scan(text);
  const linkAt = linkBlockStart(rows);
  const link = `[${version}]: https://github.com/${repo}/releases/tag/v${version}`;
  const out = [];
  rows.forEach(([line, fenced], i) => {
    if (i === linkAt) out.push(link);
    out.push(line);
    if (!fenced && isSectionHeading(line, 'Unreleased')) out.push('', `## [${version}] - ${date}`);
  });
  if (linkAt === rows.length) {
    // 末尾の改行の手前に置く
    while (out.length > 0 && out[out.length - 1] === '') out.pop();
    out.push('', link, '');
  }
  return out.join('\n');
}

/**
 * 見出しに書く日付。日本時間の `YYYY-MM-DD`。JST に夏時間は無いので +9 時間で足りる
 * （`Intl` の既定の書式は ICU の版で変わりうるので使わない）
 */
export const releaseDate = (now = new Date()) =>
  new Date(now.getTime() + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);

const OWNER_REPO = String.raw`[A-Za-z0-9-]+\/[\w.-]+`;
// 末尾の `+?` で repo 名を最短にし、`.git` と末尾の `/` を名前に含めない
// （`OWNER_REPO` が `+` で終わることに頼っている）
const NAME = String.raw`(${OWNER_REPO}?)(?:\.git)?\/?`;

/**
 * git の remote の URL から GitHub の `owner/repo` を取り出す。GitHub でなければ `null`。
 * 受けるのは scp 形式（`git@github.com:o/r.git`）と、host が github.com の URL
 * （`https:` / `http:` / `ssh:` / `git:`）。ユーザー名は問わない。SSH の host の別名
 * （`github-work:o/r`）は GitHub か判定できないので受けない
 * @param {string} remote
 * @returns {string | null}
 */
export function githubRepo(remote) {
  const scp = new RegExp(`^(?:[^@/:]+@)?github\\.com:${NAME}$`).exec(remote);
  if (scp) return scp[1];
  let url;
  try {
    url = new URL(remote);
  } catch {
    return null;
  }
  if (!/^(www\.)?github\.com$/.test(url.hostname)) return null;
  return new RegExp(`^/${NAME}$`).exec(url.pathname)?.[1] ?? null;
}

/** エラーに出す remote。URL に埋め込んだ認証情報（`https://user:token@...`）を伏せる */
function redactRemote(remote) {
  try {
    const url = new URL(remote);
    if (url.username || url.password) {
      url.username = '***';
      url.password = '';
    }
    return url.href;
  } catch {
    // scp 形式（`user@host:path`）。パスワードは書けない
    return remote;
  }
}

/**
 * リンク先の repo（`owner/repo`）を決める。Actions では `GITHUB_REPOSITORY`、それ以外では
 * 作業ディレクトリの `origin` の URL から。**`package.json` には頼らない**（npm 以外の
 * repo でも使うため）。決められなければ `ReleaseError`。
 *
 * `GITHUB_REPOSITORY` は `GITHUB_ACTIONS=true` のときだけ読む。手元のシェルに別の repo の
 * 値が残っていると、黙ってその repo へのリンクを書いてしまうため。
 * @param {NodeJS.ProcessEnv} env
 * @returns {string}
 */
export function currentGithubRepo(env = process.env) {
  const fromEnv = env.GITHUB_ACTIONS === 'true' ? env.GITHUB_REPOSITORY : undefined;
  if (fromEnv) {
    if (!new RegExp(`^${OWNER_REPO}$`).test(fromEnv)) {
      throw new ReleaseError(`GITHUB_REPOSITORY must be owner/repo, got "${fromEnv}"`);
    }
    return fromEnv;
  }
  let remote = '';
  try {
    remote = execFileSync('git', ['remote', 'get-url', 'origin'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    // git が無い、repo の外、origin が無い。どれも下で同じように落とす
  }
  const repo = githubRepo(remote);
  if (!repo) {
    const got = remote ? `, but origin is ${redactRemote(remote)}` : '';
    throw new ReleaseError(
      'Cannot tell the GitHub repository for the CHANGELOG links: ' +
        `run this in GitHub Actions (GITHUB_REPOSITORY) or in a clone whose origin is on GitHub${got}`,
    );
  }
  return repo;
}
