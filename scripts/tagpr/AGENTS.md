# tagpr-scripts の作業メモ

**取り込み先の `scripts/tagpr/` でこのファイルを読んでいるなら、そこでは何も編集しない。**
この repo は git subtree で各 repo の `scripts/tagpr/` に丸ごと取り込まれ、このファイルも
一緒に入る。直すのは [kan/tagpr-scripts](https://github.com/kan/tagpr-scripts) の側で、
取り込み先へは `git subtree pull` で入れる（下の「取り込み先へ届ける」）。

## これは何か

[tagpr](https://github.com/Songmu/tagpr) で、手書きの `CHANGELOG.md` を持つ npm パッケージを
リリースするためのスクリプト。lily / wema / wema-kake / codemirror-lang-raku が共有している（各 repo の
`scripts/release-*.mjs` を 1 つにまとめたもの）。npm でない repo も
`release-prepare.mjs --changelog-only` で CHANGELOG の処理だけを使える（Go の roji / notify-slack /
hokora が使っている）。Tauri の pike / musql は `--cargo src-tauri` で Cargo.lock も揃える。
CPAN の coveralls-perl / p5-smart-options / p5-web-service-mailgun は、版を Perl モジュールと
`META.json` に持ち、`master` からリリースする。
シェルのツールの booch / booch-win は、版をルートの `VERSION` に持つ（`--changelog-only`）。

| ファイル | 呼ぶもの | 役割 |
|---|---|---|
| `release-prepare.mjs` | tagpr（`.tagpr` の `postVersionCommand`） | `## [Unreleased]` を `## [X.Y.Z] - <JST の日付>` にし、空の `## [Unreleased]` を置き直し、末尾のリンク定義の先頭にその版のリンクを足す。`package-lock.json` の版を `package.json` に揃える（`--changelog-only` では揃えない） |
| `release-notes.mjs` | 共通の publish の workflow（`publish-npm.yml`、`publish-cpan.yml`）と、それを使わない取り込み先の publish のワークフロー | CHANGELOG の 1 つの節の本文を出す。publish 前の存在確認と、GitHub Release の本文に使う。プレリリースのタグ（`vX.Y.Z-*`）では `Unreleased` の節を出す。段落と項目の折り返しは 1 行につなぐ（`unwrapLines`） |
| `release-pending.mjs` | 共通の workflow（tagpr の前） | 出すものがあるかを判定する。`## [Unreleased]` が空で、最新のタグ（標準入力の ref の一覧から決める）より新しい版の節も無ければ `false`、ほかは `true`。`false` なら workflow は tagpr を走らせず（#13）、draft のリリース PR を閉じる（#14）。`false` に倒すほど閉じる PR が増える |
| `missed-tags.mjs` | 共通の workflow（tagpr の前） | 打たれなかったタグを探すための CHANGELOG の読み取り。`untagged` は最新のタグより新しい版の節（版のタグが無ければ何も出さない）、`latest` は最新のタグの版、`newest` は標準入力の CHANGELOG のいちばん新しい版を出す。API は workflow が呼び、その版のマージコミットの cancelled の run を再実行する（#4） |
| `changelog.mjs` | ほかのスクリプトがすべて import する | CHANGELOG の読み方（節の見出し、コードフェンス、末尾のリンク定義）と書き換え方（`stampRelease`）、日付・repo 名の決め方、プレリリースのタグの判定（`isPrereleaseTag`）、`.tagpr` の読み方（`tagprConfig`）。import しても何も実行しない。npm に依存しない |
| `npm-lock.mjs` | `release-prepare.mjs` が import する | `package.json` の版の確認と、`package-lock.json` の版を揃えた中身を作る。書くのは呼んだ側 |
| `cargo-lock.mjs` | `release-prepare.mjs` が import する（`--cargo <dir>`） | `<dir>/Cargo.toml` の `[package]` の版の確認と、`<dir>/Cargo.lock` の自分の `[[package]]` の版を揃えた中身を作る。`cargo` は呼ばない。書くのは呼んだ側 |
| `version-files.mjs` | `release-prepare.mjs` が import する | `.tagpr` の `versionFile` を `git config` で読み、並んだ全部のファイルの本来の版（`*.json` は最上位の `"version"`、`Cargo.toml` は `[package]`、`VERSION` は中身の全体、`*.pm` は `our $VERSION = "X.Y.Z";` のちょうど 1 行）が提案の版かを確かめる。tagpr は各ファイルで今の版の最初の 1 か所しか書き換えず、別の行に当たっても何も落ちないため |
| `verify-subtree.mjs` | 取り込み先の PR の CI | 取り込み先の `HEAD:scripts/tagpr` の tree と、`.github/workflows/` で呼ぶ `kan/tagpr-scripts/.github/workflows/<workflow>@<SHA>`（tagpr.yml、tagpr-label.yml、publish-npm.yml、publish-cpan.yml。名前を問わず拾う）の commit の tree が同じかを確かめる。呼ぶ行はすべて同じ commit であること |
| `release-tag.mjs` | 共通の publish の workflow（`publish-npm.yml`、`publish-cpan.yml`）の build のジョブ（依存を入れる前） | タグが `vX.Y.Z` の形か、`package.json`（あれば）と `.tagpr` の `versionFile` のすべて（`versionFileMismatch`）の版がタグの版か、タグの commit が `.tagpr` の `releaseBranch`（`origin/<branch>`）の上にあるかを確かめる。`prerelease=`（`isPrereleaseTag`。`release-notes.mjs` と同じ規則）と、`package.json` があれば `spec=`（`name@version`）を `$GITHUB_OUTPUT` の形で出す |
| `test/release.node-test.mjs` | `node --test` | `verify-subtree.mjs` を除く上の 9 つのテスト |
| `test/verify-subtree.node-test.mjs` | `node --test` | `verify-subtree.mjs` のテスト。一時ディレクトリに upstream と取り込み先の repo を作る |
| `.github/workflows/tagpr.yml` | 取り込み先の tagpr.yml が `uses:` で呼ぶ（reusable workflow。この repo では動かない） | 出すものが無ければ（`release-pending.mjs`）tagpr を走らせず成功で終え、残った draft のリリース PR を閉じる（`workflow_dispatch` の起動では必ず走らせる。#14）。その前に、タグが打たれなかったリリース PR のマージの run の tagpr のジョブが cancelled なら再実行し、終わるのを待って呼ぶ側の workflow を起動し直す。その run では tagpr を走らせない（#4）。tagpr を走らせ、タグを打ったら annotated に打ち直し、取り込み先の publish / release をそのタグで `workflow_dispatch` する。tagpr が落ちた run ではリリース PR を draft にし、成功した run ではその run のリリース PR だけを ready に戻して、前のリリース PR を閉じる。入力は README の「The tagpr workflow」 |
| `.github/workflows/tagpr-label.yml` | 取り込み先の tagpr-label.yml が `pull_request_target`（`labeled` / `unlabeled`）で呼ぶ（reusable workflow） | 開いているリリース PR のラベルが付け外しされたら、その PR を draft にし、取り込み先の tagpr.yml をリリースのブランチで `workflow_dispatch` して作り直させる（#3） |
| `.github/workflows/publish-npm.yml` | npm の取り込み先の publish のワークフロー（tagpr.yml の `release-workflow`）が `uses:` で呼ぶ（reusable workflow） | バージョンのタグを npm へ出し、GitHub Release を作る（#15）。ジョブを権限で `build` / `publish` / `release` に分け、依存のコードは `build` でしか走らせない。タグと `package.json` の版、`.tagpr` の `releaseBranch` の上にあるか、CHANGELOG の節を `npm ci` の前に確かめる。プレリリースは dist-tag `next`。npm にある版は出し直さず、Release が既にあれば書き直す。repo ごとの違い（検査のコマンド、添付するファイルなど）は入力で渡す。入力は README の「The npm publish workflow」 |
| `.github/workflows/publish-cpan.yml` | CPAN の取り込み先の publish のワークフロー（tagpr.yml の `release-workflow`）が `uses:` で呼ぶ（reusable workflow） | バージョンのタグを PAUSE へ送り、GitHub Release を作る（#16）。ジョブを権限で `build` / `upload` / `release` に分け、依存のコードは `build` でしか走らせない。PAUSE の認証情報は呼ぶ側の repo の `cpan` 環境にあり、`upload` だけが読む。Release が既にあるタグ、プレリリースのタグは止める（PAUSE は同じファイルを二度受け付けない）。repo ごとの違い（テストのコマンド、追加で入れるモジュール）は入力で渡す。入力は README の「The CPAN publish workflow」 |

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
  **版を上げるときは、`test.yml`、`.github/workflows/tagpr.yml`、`.github/workflows/publish-npm.yml`、
  `.github/workflows/publish-cpan.yml` の `setup-node` を同じコミットで上げる。** Dependabot も lockfile も Node の版は追わないので、片方だけ上げてもどこも落ちない

## テスト

```bash
node --test 'test/*.node-test.mjs'
```

- **テストのファイル名を `*.test.mjs` にしない。** 取り込み先の vitest が既定の include で
  拾い、node:test のファイルなので "No test suite found" で落ちる。`*.node-test.mjs` にする
- `changelog.mjs` の関数は直接呼ぶ。スクリプトは、一時ディレクトリに repo のルートを
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
- `.github/workflows/publish-npm.yml`: 同じく取り込み先から呼ぶ reusable workflow。中の action は
  この repo の `actions.lock` が固定する。**取り込み先の Trusted Publisher は、呼ぶ側の workflow の
  ファイル名で登録したままにする。** npm が照合するのは呼ぶ側の workflow の名前で、別の repo の
  この workflow から publish しても通る。2026-11-10 に kan/tagpr-scripts-sandbox の `publish.yml` から
  @kanf/sandbox 0.1.9 を出して確かめた。この workflow の名前を変えても取り込み先の登録は変わらないが、
  取り込み先の呼ぶ側のファイル名を変えると publish が落ちる。中身を変えるときは、sandbox の
  @kanf/sandbox で実際に publish して確かめる（リリース PR をマージする）
- `.github/workflows/publish-cpan.yml`: 同じく取り込み先から呼ぶ reusable workflow。中の action は
  この repo の `actions.lock` が固定する。**PAUSE には試験用のサーバーが無く、送ったものは取り消せない。**
  sandbox では試さず、CPAN の取り込み先の実際のリリースで確かめるとユーザーが決めた（#16）。
  呼ぶ側の `cpan` 環境の secret が `upload` のジョブから読めるかは、まだ実際のリリースで確かめていない
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
- **同じ PR で、共通の workflow を呼ぶ行の SHA を、どれも取り込んだこの repo の commit に上げる。**
  呼ぶ行は tagpr.yml と tagpr-label.yml にあり、npm と CPAN の repo では publish のワークフローにもある。
  上げる先は、squash のコミットのメッセージにある `git-subtree-split` の SHA。取り込み先の squash や
  マージのコミットの SHA は、この repo に無いので使えない。
  呼ぶ行は `uses: kan/tagpr-scripts/.github/workflows/<workflow>@<SHA>`。手順は README の「Changing it」。
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
- 取り込み先は次のとおり。npm 以外は `--changelog-only` で呼ぶ
  - npm: lily / wema / wema-kake / codemirror-lang-raku
  - CPAN: coveralls-perl / p5-smart-options / p5-web-service-mailgun
  - Go: roji / notify-slack / hokora。Tauri: pike / musql。シェル: booch / booch-win。
    vue-preview（バイナリを GitHub Release に添付する。版はタグだけで持つ）
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

- #15 npm パッケージの publish の workflow を共通にする。`publish-npm.yml` を置き、sandbox で
  publish まで通した。残りは、lily / wema / wema-kake / codemirror-lang-raku の publish の
  ワークフローを移し、各 repo で 1 回ずつ実際のリリースを通すこと。各 repo のリリースに合わせて
  進めるので、手順と確かめることは各 repo の issue に書いた（kan/lily#58、kan/wema#94、
  kan/wema-kake#74、kan/codemirror-lang-raku#24）。問題があれば、そこからこの repo に issue が立つ
- #16 CPAN のモジュールの publish の workflow を共通にする。`publish-cpan.yml` を置いた。残りは、
  coveralls-perl / p5-smart-options / p5-web-service-mailgun の publish のワークフローを移し、
  実際のリリースで確かめること（sandbox では試さない）。`cpan` 環境の保護（デプロイできる ref）が
  coveralls-perl にしか無いのも揃える
