// `verify-subtree.mjs` を、取り込み先と同じ形で走らせる。一時ディレクトリに tagpr-scripts の
// 代わりの repo（upstream）と、その tree を `scripts/tagpr/` に置いた取り込み先の repo を作る。
// upstream は `TAGPR_SCRIPTS_URL` で差し替える（GitHub へは取りに行かない）。
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { after, before, test } from 'node:test';

const root = join(import.meta.dirname, '..');
// スクリプトとその import 先。取り込み先の `scripts/tagpr/` にもこれだけを置く
const FILES = ['verify-subtree.mjs', 'changelog.mjs'];

const dirs = [];
after(() => {
  for (const dir of dirs) rmSync(dir, { recursive: true, force: true });
});

/** 外の repo を触らない環境（release.node-test.mjs と同じ） */
function gitEnv(extra = {}) {
  const env = { ...process.env, GIT_CEILING_DIRECTORIES: tmpdir(), ...extra };
  for (const name of ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR']) delete env[name];
  return env;
}

function git(cwd, ...args) {
  const r = spawnSync('git', ['-c', 'user.name=t', '-c', 'user.email=t@example.com', '-c', 'commit.gpgsign=false', ...args], {
    cwd,
    encoding: 'utf8',
    env: gitEnv(),
  });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
}

function tempDir() {
  const dir = mkdtempSync(join(tmpdir(), 'verify-subtree-test-'));
  dirs.push(dir);
  return dir;
}

function writeFiles(dir, files) {
  for (const [path, text] of Object.entries(files)) {
    mkdirSync(join(dir, path, '..'), { recursive: true });
    writeFileSync(join(dir, path), text);
  }
}

/** upstream の commit A の中身を dir に置く。upstream と取り込み先の `scripts/tagpr/` の両方に使う */
function placeTreeA(dir) {
  mkdirSync(dir, { recursive: true });
  for (const name of FILES) copyFileSync(join(root, name), join(dir, name));
  writeFileSync(join(dir, 'README.md'), 'A\n');
}

// upstream の 2 つの commit。A を取り込んだ状態を基本にし、B は README だけが違う
let upstream;
let shaA;
let shaB;
before(() => {
  upstream = tempDir();
  git(upstream, 'init', '-q', '-b', 'main');
  // 枝の先でない commit も SHA で取れるようにし、--filter も受け付ける（GitHub はどちらも許している）
  git(upstream, 'config', 'uploadpack.allowReachableSHA1InWant', 'true');
  git(upstream, 'config', 'uploadpack.allowFilter', 'true');
  placeTreeA(upstream);
  git(upstream, 'add', '.');
  git(upstream, 'commit', '-q', '-m', 'A');
  shaA = git(upstream, 'rev-parse', 'HEAD');
  writeFiles(upstream, { 'README.md': 'B\n' });
  git(upstream, 'commit', '-q', '-am', 'B');
  shaB = git(upstream, 'rev-parse', 'HEAD');
});

const caller = (sha) => `jobs:\n  tagpr:\n    uses: kan/tagpr-scripts/.github/workflows/tagpr.yml@${sha}\n`;

/** upstream の A を `scripts/tagpr/` に置いた取り込み先を作り、files を足して commit する */
function makeCaller(files) {
  const dir = tempDir();
  git(dir, 'init', '-q', '-b', 'main');
  placeTreeA(join(dir, 'scripts/tagpr'));
  writeFiles(dir, files);
  git(dir, 'add', '.');
  git(dir, 'commit', '-q', '-m', 'caller');
  return dir;
}

function verify(cwd) {
  return spawnSync(process.execPath, ['scripts/tagpr/verify-subtree.mjs'], {
    cwd,
    encoding: 'utf8',
    env: gitEnv({ TAGPR_SCRIPTS_URL: pathToFileURL(upstream).href }),
  });
}

test('passes when scripts/tagpr/ is the tree of the commit the workflow calls', () => {
  const r = verify(makeCaller({ '.github/workflows/tagpr.yml': caller(shaA) }));
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, new RegExp(`matches kan/tagpr-scripts@${shaA}`));
});

test('fails when the "uses:" line was not moved to the pulled commit', () => {
  const r = verify(makeCaller({ '.github/workflows/tagpr.yml': caller(shaB) }));
  assert.equal(r.status, 1);
  assert.match(r.stderr, /scripts\/tagpr\/ does not match kan\/tagpr-scripts@/);
});

test('fails when scripts/tagpr/ was edited by hand', () => {
  const r = verify(makeCaller({ '.github/workflows/tagpr.yml': caller(shaA), 'scripts/tagpr/README.md': 'edited\n' }));
  assert.equal(r.status, 1);
  assert.match(r.stderr, /does not match/);
});

test('reads the pins from HEAD, not from the work tree', () => {
  const dir = makeCaller({ '.github/workflows/tagpr.yml': caller(shaA) });
  writeFiles(dir, { '.github/workflows/tagpr.yml': caller(shaB) });
  assert.equal(verify(dir).status, 0);
});

test('fails when no workflow calls the shared workflow', () => {
  const r = verify(makeCaller({ '.github/workflows/ci.yml': 'jobs: {}\n' }));
  assert.equal(r.status, 1);
  assert.match(r.stderr, /no "uses: kan\/tagpr-scripts/);
});

test('fails when the shared workflow is called by a tag or a short SHA', () => {
  for (const ref of ['v1', shaA.slice(0, 12)]) {
    const r = verify(makeCaller({ '.github/workflows/tagpr.yml': caller(ref) }));
    assert.equal(r.status, 1);
    assert.match(r.stderr, /pin kan\/tagpr-scripts to a full commit SHA/);
  }
});

test('ignores workflows outside the top level of .github/workflows', () => {
  const r = verify(
    makeCaller({ '.github/workflows/tagpr.yml': caller(shaA), '.github/workflows/old/tagpr.yml': caller(shaB) }),
  );
  assert.equal(r.status, 0, r.stderr);
});

test('reads quoted lines, step-level lines and CRLF files, and skips commented-out lines', () => {
  const workflow = [
    'jobs:',
    '  tagpr:',
    `    uses: "kan/tagpr-scripts/.github/workflows/tagpr.yml@${shaA}" # pinned`,
    '  other:',
    '    steps:',
    `      - uses: 'kan/tagpr-scripts/.github/workflows/tagpr.yml@${shaA}'`,
    `    # uses: kan/tagpr-scripts/.github/workflows/tagpr.yml@${shaB}`,
    `      - run: echo "uses: kan/tagpr-scripts/.github/workflows/tagpr.yml@v1"`,
    '',
  ].join('\r\n');
  const r = verify(makeCaller({ '.github/workflows/tagpr.yml': workflow }));
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, new RegExp(`matches kan/tagpr-scripts@${shaA} `));
});

test('fails when two workflows call different commits', () => {
  const r = verify(
    makeCaller({ '.github/workflows/tagpr.yml': caller(shaA), '.github/workflows/other.yaml': caller(shaB) }),
  );
  assert.equal(r.status, 1);
  assert.match(r.stderr, /different commits/);
});
