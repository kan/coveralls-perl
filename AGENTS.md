# AGENTS.md

このリポジトリは CPAN モジュール `Devel::Cover::Report::Coveralls` の開発用。`Devel::Cover` が集めた
カバレッジを Coveralls（https://coveralls.io/ ）の API へ送る。利用者は `cover -report coveralls` で
呼び出す（`-report` に渡した名前から `Devel::Cover::Report::<名前>` が読み込まれる）。

## ファイル構成

| パス | 内容 |
|---|---|
| `lib/Devel/Cover/Report/Coveralls.pm` | 本体。コードと POD（利用者向けドキュメント）がこの 1 ファイルにある |
| `t/00_compile.t` | モジュールが読み込めるかの確認 |
| `t/01_basic.t` | `get_config` / `get_git_info` / `get_source` の単体テスト |
| `t/example.pl` | `get_source` のテストが読む入力ファイル。中身を変えるとテストの期待値も変わる |
| `cpanfile` | 依存モジュールの宣言（runtime / test / configure / develop） |
| `minil.toml` | Minilla の設定 |
| `Changes` | リリース履歴。先頭の `{{$NEXT}}` の下に未リリースの変更を書く |
| `RELEASE.md` | リリース手順（PAUSE へのアップロード） |
| `docker-compose.yml` | 開発用の Perl コンテナ（perl 5.30.1 + cpm） |
| `.github/workflows/` | CI。ubuntu（`master.yml`）/ windows / mac と、`actions.lock` の検証 |
| `.travis.yml` | 旧 CI の名残。ブランチ名に `travis` を含むときしか動かない |

## 生成物は直接編集しない

次のファイルは Minilla（`minil build` / `minil release`）で生成される。

- **`Build.PL` と `META.json` は手で編集しない。** 依存の変更は `cpanfile` に、メタ情報の変更は
  `minil.toml` に書く
- **`README.md` は手で編集しない。** `Coveralls.pm` の POD から `Pod::Markdown::Github` で生成される。
  利用方法や環境変数の説明を直すときは POD を直す
- `Devel-Cover-Report-Coveralls-*/`、`.build/`、`local/`、`blib/` はビルドや依存インストールの産物で、
  `.gitignore` 済み。読んだり編集したりしない

## 本体の構造（`Coveralls.pm`）

`report($pkg, $db, $options)` が、`Devel::Cover` から最初に呼ばれる関数。処理の流れは次のとおり。

1. `$options->{file}` の各ファイルについて `get_source` がソースを読み、行ごとのカバレッジを配列にする。
   `_parse_line` は「その行に文がない → `undef`」「uncoverable → `undef`」「それ以外 → 実行回数」を返す。
   ファイル名の先頭の `blib/` は外す
2. `get_config` が環境変数と `.coveralls.yml` から、送信する JSON の CI 関連の項目とエンドポイントを決める
3. `get_git_info` が `git log -1` / `git remote -v` / `git branch` を外部コマンドで呼んで git 情報を作る
   （失敗しても `eval` で空ハッシュになり、送信は続く）
4. `HTTP::Tiny` で `<endpoint>/api/v1/jobs` へ `json=<JSON>` を form で POST し、結果を標準出力に出す

### `get_config` の CI 判定

`if / elsif` の連鎖で、**上にある条件が先に当たる。** 順序は次のとおり。

1. `TRAVIS` → `travis-ci`（`repo_token` が無くても通る唯一の分岐）
2. `CIRCLECI` → `circleci`
3. `DRONE` → `drone`
4. `SEMAPHORE` → `semaphore`（1.x と 2.x の両方の変数を見る）
5. `JENKINS_URL` → `jenkins`
6. `GITHUB_TOKEN` → `github`（`GITHUB_TOKEN` を `repo_token` に使う。PR 番号は `GITHUB_EVENT_PATH` の JSON から取る）
7. `GITHUB_ACTIONS` かつ `GITHUB_SHA` → `github-actions`（`COVERALLS_REPO_TOKEN` を使う旧来の設定）
8. `SYSTEM_TEAMFOUNDATIONSERVERURI` → `azure-pipelines`
9. どれでもない → `.coveralls.yml` の `service_name` か `coveralls-perl`、`service_event_type` は `manual`

- 分岐の後で `COVERALLS_PERL_SERVICE_NAME` が `service_name` を上書きする
- `repo_token` は `.coveralls.yml` の値を `COVERALLS_REPO_TOKEN` が上書きし、6 の分岐ではさらに
  `GITHUB_TOKEN` が上書きする。Travis 以外で `repo_token` が無いと `die` する
- ブランチ名は `git branch` の結果を、`GITHUB_REF` か `BUILD_SOURCEBRANCHNAME` があればそちらで上書きする
- **新しい CI を足すときは、分岐の位置で既存の CI の判定を奪わないか確認する。** 利用者向けの環境変数を
  足したら POD の `=head1 ENVIRONMENT` にも書く

## 書き方の制約

- **最低対応バージョンは Perl 5.8.5**（`use 5.008005`）。5.10 以降の構文は使わない。
  `//`、`say`、`given/when`、`state` などが該当する。CI で動かしているのは 5.26 以降だが、
  宣言を変えずに新しい構文を入れない
- 依存はコアモジュールか `cpanfile` に宣言済みのものに限る。増やすときは `cpanfile` に足す
- CI は Linux / Windows（Strawberry Perl）/ macOS で動く。パス区切りやシェルのクォートなど、
  POSIX のシェルだけを前提にした書き方は Windows で動かないことがある
- インデントは 4 スペース。ファイルを開くときはレキシカルなファイルハンドルと 3 引数の `open` を使う

## テスト

ホストの Perl には依存モジュール（`Devel::Cover` など）が入っていないことが多い。その場合は
`docker-compose.yml` のコンテナで実行する。

```sh
docker compose up -d
docker compose exec perl bash
# 以下コンテナ内（/app がリポジトリ）
cpm install --with-develop     # local/ へ入る。PERL5LIB は compose 側で設定済み
prove -l t
```

`perl Build.PL && ./Build build && ./Build test` でも同じテストが走る（CI はこちら）。

- **`t/01_basic.t` で `get_config` を試すときは、判定の順序で上にある CI の環境変数を消す。**
  消し方は `local $ENV{...} = undef` で、既存の subtest の書き方に合わせる。テスト自体が
  GitHub Actions 上で走るため、`GITHUB_TOKEN` や `GITHUB_ACTIONS` が入っていると別の分岐に入る
- `get_git_info` を呼ぶテストは、git の作業ツリーの中で実行する必要がある
- テストから `report` を呼ばない（Coveralls へ実際に POST する）
- CI の `master.yml` は perl latest のときだけ、このモジュール自身で自分のカバレッジを Coveralls へ送る
  （`DEVEL_COVER_SELF=1`）

## CI（GitHub Actions）

- action のバージョンは `.github/workflows/actions.lock` で固定している。**`uses:` の行を変えたら、
  repo のルートで `gh actions-lock` を実行し、書き換わったワークフローと lockfile を一緒にコミットする。**
  lockfile を手で編集しない
- Dependabot が action の更新 PR を週 1 回出す（lockfile も書き換わる）

## バージョンとリリース

- バージョンは `Coveralls.pm` の `our $VERSION` にある。**バージョンの変更（bump）とリリースは
  メンテナが `RELEASE.md` の手順で行う。** 頼まれていないのに `$VERSION` を変えたり `minil release` を
  実行したりしない
- 利用者に見える変更をしたら、`Changes` の `{{$NEXT}}` の下に 1 行で書く。外部の貢献者の変更には
  既存の行にならって `(thanks <GitHub のユーザー名>)` を付ける
- `.pause`（PAUSE の認証情報）はコミットしない（`.gitignore` 済み）

## 運用

- repo のルートに `.tagpr` は無い。メンテナは `master` へ直接 push し、外部からの変更は PR で受ける
- コミットメッセージの言語は日本語と英語のどちらでもよい（履歴には両方ある）
