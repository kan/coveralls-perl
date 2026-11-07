# tagpr-scripts の作業メモ

**取り込み先の `scripts/tagpr/` でこのファイルを読んでいるなら、そこでは何も編集しない。**
この repo は git subtree で各 repo の `scripts/tagpr/` に丸ごと取り込まれ、このファイルも
一緒に入る。直すのは [kan/tagpr-scripts](https://github.com/kan/tagpr-scripts) の側で、
取り込み先へは `git subtree pull` で入れる（下の「取り込み先へ届ける」）。

## これは何か

[tagpr](https://github.com/Songmu/tagpr) で、手書きの `CHANGELOG.md` を持つ npm パッケージを
リリースするためのスクリプト。lily / wema / wema-kake が共有している（各 repo の
`scripts/release-*.mjs` を 1 つにまとめたもの）。npm でない repo も
`release-prepare.mjs --changelog-only` で CHANGELOG の処理だけを使える（Go の roji / notify-slack /
hokora が使っている）。Tauri の pike / musql は `--cargo src-tauri` で Cargo.lock も揃える。

| ファイル | 呼ぶもの | 役割 |
|---|---|---|
| `release-prepare.mjs` | tagpr（`.tagpr` の `postVersionCommand`） | `## [Unreleased]` を `## [X.Y.Z] - <JST の日付>` にし、空の `## [Unreleased]` を置き直し、末尾のリンク定義の先頭にその版のリンクを足す。`package-lock.json` の版を `package.json` に揃える（`--changelog-only` では揃えない） |
| `release-notes.mjs` | 取り込み先の publish のワークフロー | CHANGELOG の 1 つの節の本文を出す。publish 前の存在確認と、GitHub Release の本文に使う。プレリリースのタグ（`vX.Y.Z-*`）では `Unreleased` の節を出す。段落と項目の折り返しは 1 行につなぐ（`unwrapLines`） |
| `release-pending.mjs` | 共通の workflow（tagpr の前） | 出すものがあるかを判定する。`## [Unreleased]` が空で、最新のタグ（標準入力の ref の一覧から決める）より新しい版の節も無ければ `false`、ほかは `true`。`false` なら workflow は tagpr を走らせない（#13） |
| `changelog.mjs` | ほかのスクリプトがすべて import する | CHANGELOG の読み方（節の見出し、コードフェンス、末尾のリンク定義）と書き換え方（`stampRelease`）、日付・repo 名の決め方。import しても何も実行しない。npm に依存しない |
| `npm-lock.mjs` | `release-prepare.mjs` が import する | `package.json` の版の確認と、`package-lock.json` の版を揃えた中身を作る。書くのは呼んだ側 |
| `cargo-lock.mjs` | `release-prepare.mjs` が import する（`--cargo <dir>`） | `<dir>/Cargo.toml` の `[package]` の版の確認と、`<dir>/Cargo.lock` の自分の `[[package]]` の版を揃えた中身を作る。`cargo` は呼ばない。書くのは呼んだ側 |
| `version-files.mjs` | `release-prepare.mjs` が import する | `.tagpr` の `versionFile` を `git config` で読み、並んだ全部のファイルの本来の版（`*.json` は最上位の `"version"`、`Cargo.toml` は `[package]`、`VERSION` は中身の全体、`*.pm` は `our $VERSION = "X.Y.Z";` のちょうど 1 行）が提案の版かを確かめる。tagpr は各ファイルで今の版の最初の 1 か所しか書き換えず、別の行に当たっても何も落ちないため |
| `verify-subtree.mjs` | 取り込み先の PR の CI | 取り込み先の `HEAD:scripts/tagpr` の tree と、`.github/workflows/` で呼ぶ `kan/tagpr-scripts/.github/workflows/tagpr.yml@<SHA>` の commit の tree が同じかを確かめる |
| `test/release.node-test.mjs` | `node --test` | `verify-subtree.mjs` を除く上の 7 つのテスト |
| `test/verify-subtree.node-test.mjs` | `node --test` | `verify-subtree.mjs` のテスト。一時ディレクトリに upstream と取り込み先の repo を作る |
| `.github/workflows/tagpr.yml` | 取り込み先の tagpr.yml が `uses:` で呼ぶ（reusable workflow。この repo では動かない） | 出すものが無ければ（`release-pending.mjs`）tagpr を走らせず成功で終える。tagpr を走らせ、タグを打ったら annotated に打ち直し、取り込み先の publish / release をそのタグで `workflow_dispatch` する。tagpr が落ちた run ではリリース PR を draft にし、成功した run ではその run のリリース PR だけを ready に戻して、前のリリース PR を閉じる。入力は README の「The tagpr workflow」 |

package.json は無い。依存も無い。

## ドキュメントの分担

| 置き場 | 言語 | 誰向け |
|---|---|---|
| `README.md` | 英語 | 使う人（取り込む repo の作業者）。CHANGELOG の形の規則、`.tagpr` の設定例、publish のワークフローへの組み込み方、変更の流し方 |
| コード中のコメント | 日本語 | 中を直す人。「なぜそうしたか」はここに書く |
| エラーメッセージ、テスト名 | 英語 | CI のログを読む人 |
| `AGENTS.md`（これ） | 日本語 | 作業時の前提。README に載せるほどではない文脈 |

- **README に書いた CHANGELOG の規則と `.tagpr` の設定例は、取り込み先との約束。**
  挙動を変えたら README も同じコミットで直す
- コミットメッセージは日本語（既存の履歴に合わせる）

## 守る前提

- **Node の組み込みモジュールしか使わない。** tagpr のジョブはリポジトリへ push できる
  トークンを持つので、依存のコードを走らせない。`npm ci` も、実行時の取得もしない。
  **package.json を足して依存を入れようとしない。** npm パッケージではなく subtree に
  しているのも同じ理由（コードが各 repo にコミットされ、その差分でレビューされる）
- **CHANGELOG の読み方は `changelog.mjs` の 1 か所にだけ書く。** `release-prepare.mjs` と
  `release-notes.mjs` に別々に書くと、リリース PR は通るのに publish の検査で落ちる。
  コードフェンスの追い方も `scan` の 1 か所だけ
- **`release-prepare.mjs` は検査をすべて済ませてから書く。落ちるときは何も書き換えない。**
  tagpr は postVersionCommand が落ちてもリリース PR を作り直すので、書きかけの CHANGELOG や
  lock を PR へ入れないため。検査は「書き換え」の区切りより前に足す。版のファイルは tagpr が先に書き換えるので、落ちた run の PR は版だけ
  上がったものになる。それは共通の workflow（`.github/workflows/tagpr.yml`）が draft にする
- **スクリプトは repo のルートを作業ディレクトリにして実行される。** `CHANGELOG.md` / `.tagpr`
  とその `versionFile` /
  `package.json` / `package-lock.json` と、`--cargo <dir>` の `<dir>/Cargo.toml` /
  `<dir>/Cargo.lock` はカレントディレクトリから読む。スクリプト自身の
  場所（`scripts/tagpr/`）からの相対パスで読まない
- **日付は日本時間。** `releaseDate` は +9 時間して `toISOString` で作る。`Intl` の既定の
  書式は ICU の版で変わりうるので使わない
- **CHANGELOG の処理（`changelog.mjs`）に npm の前提を持ち込まない。** `package.json` /
  `package-lock.json` を読むのは `npm-lock.mjs` だけ。Go や Tauri の repo が
  `--changelog-only` で使うため（issue #1）
- **リンク先の repo は、Actions（`GITHUB_ACTIONS=true`）では `GITHUB_REPOSITORY`、それ以外では
  `origin` の URL から決める**（`currentGithubRepo`）。`package.json` の `repository` は読まない。
  GitHub 以外は落とす。エラーに remote の URL を出すときは認証情報を伏せる
- 改行は LF だけを受ける。CR があれば落とす
- 取り込み先の Node は 24（CI も 24 で回している）。それより新しい機能を使わない。
  **版を上げるときは、`test.yml` と `.github/workflows/tagpr.yml` の `setup-node` を同じコミットで
  上げる。** Dependabot も lockfile も Node の版は追わないので、片方だけ上げてもどこも落ちない

## テスト

```bash
node --test 'test/*.node-test.mjs'
```

- **テストのファイル名を `*.test.mjs` にしない。** 取り込み先の vitest が既定の include で
  拾い、node:test のファイルなので "No test suite found" で落ちる。`*.node-test.mjs` にする
- `changelog.mjs` の関数は直接呼ぶ。2 つのスクリプトは、一時ディレクトリに repo のルートを
  作り、そこを作業ディレクトリにして子プロセスで実行する（tagpr と publish のワークフローと
  同じ呼ばれ方）。新しいテストもこの形に揃える
- **失敗するケースでは「何も書き換えていない」ことまで確かめる。** 既存のテストは
  `CHANGELOG.md` と `package-lock.json` が元のままかを見ている
- コミットの前にこのコマンドを通す。lint とフォーマッタは入れていない

## CI と GitHub の設定

- `.github/workflows/test.yml`: main への push と PR でテストを回す。依存が無いので
  `npm ci` は無い。権限は `contents: read`
- `.github/dependabot.yml`: 見るのは GitHub Actions だけ（月 1 回）
- `.github/workflows/tagpr.yml`: 取り込み先から呼ぶ reusable workflow。`workflow_call` しか
  持たないので、この repo では動かない。**この中の action（tagpr など）は、この repo の
  `actions.lock` が固定する。** tagpr の版を上げるのは、ここと lockfile の 1 か所で済む。
  中身を変えるときは、別の repo から呼んで確かめる。使う repo は kan/tagpr-scripts-sandbox
  （tagpr は main の上でしか動かないので、PR のブランチでは試せない）
- `.github/workflows/verify-lockfile.yml`: `actions.lock` が `uses:` と食い違っていないか、
  固定した commit を上流で検証できるかを、PR と main への push で確かめる
- **action の固定は `.github/workflows/actions.lock`（`gh actions-lock` が作る）に任せる。**
  `uses:` は完全な版のタグ（`@v7.0.1`）で書き、SHA は書かない。`uses:` を足したり変えたりしたら
  `gh actions-lock` を再実行し、lockfile も同じコミットに入れる。lockfile は手で編集しない
  - Dependabot は Actions の更新 PR で lockfile の該当行も作り直す
  - 検査が入れる拡張の版（`verify-lockfile.yml` の `--pin`）は、Dependabot と lockfile のどちらも追わない。lockfile の
    形式が上がって `--verify` が落ちたら、手元の `gh actions-lock` と同じ版に手で上げる
  - 取り込み先もすべて同じ形にしてある（issue #7）
- **`.github/` も取り込み先の `scripts/tagpr/.github/` に入る。** GitHub はルートの
  `.github/` しか読まないので、取り込み先では動かない。取り込み先と中身を揃えるために残している

## 変更の入れ方

- この repo には `.tagpr` が無い。リリースとタグを作らず、取り込み先は `main` を pull する。
  **ブランチの運用が決まるまでは、`main` へ直接 push する前提で進める**
- **`main` に入れた時点で、取り込み先の次の `git subtree pull` に乗る。** 取り込み先の
  リリースの手順を壊す変更（`.tagpr` の設定例やワークフローの書き方が変わる、CHANGELOG の
  規則が厳しくなる）は、README に書き、取り込み先をどう直すかまで決めてから入れる

### 取り込み先へ届ける

取り込み先の repo で、PR を作って取り込む。

```bash
git subtree pull -S --prefix=scripts/tagpr https://github.com/kan/tagpr-scripts.git main --squash
```

- **`-S` を付ける。** subtree は `commit-tree` でコミットを作るので、`commit.gpgsign` が
  効かず未署名になる
- **同じ PR で、tagpr.yml が共通の workflow を呼ぶ行の SHA を、取り込んだこの repo の commit に
  上げる。** squash のコミットのメッセージにある `git-subtree-split` の SHA。取り込み先の squash や
  マージのコミットの SHA は、この repo に無いので使えない。
  呼ぶ行は `uses: kan/tagpr-scripts/.github/workflows/tagpr.yml@<SHA>`。手順は README の「Changing it」。
  subtree と揃えておけば、`scripts/tagpr/.github/workflows/tagpr.yml` の写しが、動いているものと同じになる。
  取り込み先の PR の CI は `node scripts/tagpr/verify-subtree.mjs` で揃っているかを確かめる。新しい取り込み先にも入れる
- **取り込み先の手順書に、共通の workflow の動きや復旧の手順を書き写さない。** `scripts/tagpr/README.md` の
  「The tagpr workflow」へリンクさせる。写しは subtree pull で更新されず、tagpr の版が変わるたびに食い違う。
  取り込み先に残すのは、その repo に固有のことだけ。
  起動する workflow の名前、それが `push: tags` を持つか、再実行してはいけない理由などがそれにあたる
- **取り込み先の dependabot.yml の `github-actions` には、`kan/tagpr-scripts*` の ignore を入れる**
  （README の「The tagpr workflow」）。SHA だけを上げる PR が来ると、subtree が置いていかれ、どこも
  落ちない。Dependabot は SHA で固定した参照を、参照先の最新タグの commit へ上げる。この repo には
  タグが無いので今は来ないが、タグを打てば来るようになる（dependabot-core の `latest_commit_sha` を
  2026-11 に読んだ）
- **その PR はマージコミットで入れる。** squash で入れる repo でも同じ。subtree は前回の
  取り込みを自分が作ったコミットから探すので、squash すると次の pull が壊れる
- 取り込む PR は取り込み先の CHANGELOG に書かない（利用者に届かない）
- 取り込み先: lily / wema / wema-kake（npm）、roji / notify-slack / hokora（Go）、
  pike / musql（Tauri）。npm 以外は `--changelog-only` で呼ぶ
  - roji は自分のラッパー（`scripts/release-prepare.sh`。CREDITS を置き換える）から呼ぶ
  - notify-slack と hokora は `.tagpr` の `postVersionCommand` から直接呼ぶ。hokora は tagpr の後の
    ジョブで `sdk/vX.Y.Z` のタグも同じコミットに打つ
  - pike と musql は `scripts/release-prepare.mjs` のラッパーから `--cargo src-tauri` で呼ぶ
    （musql は `--changelog-only` も付ける）。版のファイルは tagpr の `versionFile` が書き、
    ラッパーに残るのはクレジットだけ。`release-notes.mjs` もラッパーから呼ぶ
  - 完成形の例は lily の `.github/workflows/`。`tagpr.yml` が `publish.yml` を、タグを ref にした
    `workflow_dispatch` で起動する

## 合流で決めたこと（issue #1、完了）

roji / pike / musql / notify-slack / hokora の CHANGELOG の処理は、ここへ合流させた（経緯は
issue #1）。`--changelog-only` が npm でない repo の入り口。

- **CHANGELOG の形は lily の形に揃えると、ユーザーが決めた。** 空の `## [Unreleased]` を戻す、
  リンク定義は `releases/tag`、節はリンク定義のまとまりでも切る。repo ごとの違いをオプションで
  吸収しない。この形を変えるときは、先にユーザーの判断を仰ぐ
- **今の挙動（取り込み先が使っている形）は保つ。** npm の lock を揃える処理は
  `npm-lock.mjs` に残してあり、lily 系は `--changelog-only` を付けずに呼ぶ（`.tagpr` は変えない）

## 残っている issue

issue を読まずに着手しない。進める順はユーザーと決める。

- #13: `## [Unreleased]` が空で出すものが無いときは、tagpr を走らせず成功で終える。この repo の側は
  入った（`release-pending.mjs`）。残りは取り込み先の 8 repo への subtree pull と、取り込み中の
  coveralls-perl（#12）が最初からこの版で入ること。全部に入ったら dotfiles の
  セッションに知らせる（`gh-upkeep-status` が、空での赤を fail に出していた）
- #4: 打たれなかったタグを、次の run で打ち直す
- #3: リリース PR のラベルを付け外ししたら、自動で作り直す
- #8: booch と booch-win のリリースを tagpr に移す（版の正本が `VERSION`、タグは annotated）。
  `versionFile` で `VERSION` を確かめる処理は入った。残りは booch / booch-win の側の移行
- #12: `versionFile` で Perl モジュール（`*.pm`）の `$VERSION` を確かめる処理は入った。
  残りは coveralls-perl（CPAN、ブランチは `master`）の側の取り込み（kan/coveralls-perl#50）。
  済んだら「取り込み先」の一覧と README の冒頭に coveralls-perl を足す
