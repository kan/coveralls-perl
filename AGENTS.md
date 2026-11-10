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
| `CHANGELOG.md` | リリース履歴（Keep a Changelog）。`## [Unreleased]` の下に未リリースの変更を書く |
| `RELEASE.md` | メンテナ向けのリリース手順（tagpr のリリース PR のマージ） |
| `.tagpr` | tagpr の設定 |
| `scripts/tagpr/` | kan/tagpr-scripts を `git subtree` で取り込んだもの。**手で編集しない**（下の「バージョンとリリース」） |
| `Dockerfile` / `docker-compose.yml` | 開発用の Perl コンテナ（公式の `perl:5.44` + cpm）。配布物には入らない（`minil.toml`） |
| `.github/workflows/` | CI。ubuntu（`master.yml`）/ windows / mac、`actions.lock` の検証、リリース（`tagpr.yml` / `publish.yml`） |
| `.travis.yml` | 旧 CI の名残。ブランチ名に `travis` を含むときしか動かない |

## 生成物は直接編集しない

次のファイルは Minilla（`minil build`）で生成される。

- **`Build.PL` と `META.json` は手で編集しない。** 依存の変更は `cpanfile` に、メタ情報の変更は
  `minil.toml` に書く
- **`README.md` は手で編集しない。** `Coveralls.pm` の POD から `Pod::Markdown::Github` で生成される。
  利用方法や環境変数の説明を直すときは POD を直す
- **POD、`cpanfile`、`minil.toml` を変えたら、同じ PR で `minil build` を実行し、作り直された
  `README.md` / `META.json` も一緒にコミットする。** リリース PR は `META.json` の版しか変えないので、
  ここで作り直さないと古いまま配布される。コンテナでは `docker compose run --rm perl minil build`
- `Devel-Cover-Report-Coveralls-*/`、`.build/`、`local/`、`blib/` はビルドや依存インストールの産物で、
  `.gitignore` 済み。読んだり編集したりしない

## 本体の構造（`Coveralls.pm`）

`report($pkg, $db, $options)` が、`Devel::Cover` から最初に呼ばれる関数。処理の流れは次のとおり。

1. `$options->{file}` の各ファイルについて `get_source` がソースを読み、行ごとのカバレッジを配列にする。
   `_parse_line` は「その行に文がない → `undef`」「uncoverable → `undef`」「それ以外 → 実行回数」を返す。
   ファイル名の先頭の `blib/` は外す。開けないファイルは送らない。
   `get_branches` がブランチカバレッジを、API の `branches` の形（ブランチごとに行、block、branch、
   実行回数の 4 つを並べた配列）にする。block はその行の判定の順番、branch は判定の真が 0 で偽が 1。
   uncoverable のブランチは送らない。ブランチカバレッジを集めていないとき（`-coverage statement`）は
   `branches` を送らない
2. `get_config` が環境変数と `.coveralls.yml` から、送信する JSON の CI 関連の項目とエンドポイントを決める
3. `get_git_info` が `git log -1` / `git remote -v` / `git branch` を外部コマンドで呼んで git 情報を作る
   （失敗しても `eval` で空ハッシュになり、送信は続く）。git の作業ツリーの外（`in_git_work_tree` が偽）
   では git を呼ばず、`GIT_ID` / `GIT_BRANCH` / `GIT_AUTHOR_NAME` などの環境変数だけを使う。作業ツリーの
   中では git の値が先で、環境変数は git が返さなかった項目だけを埋める。分からない値は空文字列にせず、
   項目ごと送らない
4. `HTTP::Tiny` で `<endpoint>/api/v1/jobs` へ、JSON を multipart の `json_file` に入れて POST し、
   結果を標準出力に出す（`json_file_request`）。これは API のドキュメントに書かれた形。1.0.0 まで使って
   いた form の `json=` も送れてはいたが、ドキュメントには無い。各ファイルには、ファイルのバイト列の
   MD5 を `source_digest` として付ける（`blib/` の下のファイルはコピー元のもの）。`source` も残す
   （手動のリポジトリの Coveralls Enterprise が要求するため）。
   **送信に失敗したら `die` する**（`parse_response` が判定する）。`cover` は捕まえないので、終了コードが
   0 以外になり CI のジョブが落ちる。`COVERALLS_NO_FAIL` が有効なら `die` せずに戻る。
   `get_config` の `repo_token` が無いときの `die` も、`report` が捕まえて同じように扱う

### `get_config` の CI 判定

`if / elsif` の連鎖で、**上にある条件が先に当たる。** 順序は次のとおり。

1. `TRAVIS` → `travis-ci`
2. `CIRCLECI` → `circleci`
3. `DRONE` → `drone`
4. `SEMAPHORE` → `semaphore`（1.x と 2.x の両方の変数を見る）
5. `JENKINS_URL` → `jenkins`
6. `GITLAB_CI` → `gitlab-ci`
7. `TF_BUILD` か `SYSTEM_TEAMFOUNDATIONSERVERURI` → `azure-pipelines`
8. `GITHUB_ACTIONS` → `github`。ビルド番号は `GITHUB_RUN_ID`。PR 番号は `GITHUB_REF` の `refs/pull/<番号>/` から取る。
   `pull_request_target` では取れないので、`GITHUB_EVENT_PATH` の JSON の `pull_request.number` を使う
9. どれでもない → `.coveralls.yml` の `service_name` か `coveralls-perl`、`service_event_type` は `manual`

- **GitHub Actions は `GITHUB_TOKEN` ではなく `GITHUB_ACTIONS` で判定する。** ほかの CI のジョブにも、
  別の用途で `GITHUB_TOKEN` が入っていることがあるため
- 分岐の後で、公式と同じ名前の環境変数が CI から取った値を上書きする。対象は `COVERALLS_SERVICE_NAME`、
  `COVERALLS_SERVICE_NUMBER`、`COVERALLS_SERVICE_JOB_ID`、`COVERALLS_SERVICE_JOB_NUMBER`、
  `COVERALLS_PULL_REQUEST`、`COVERALLS_GIT_BRANCH`、`COVERALLS_GIT_COMMIT`。最後に
  `COVERALLS_PERL_SERVICE_NAME`（`COVERALLS_SERVICE_NAME` の別名）が `service_name` を上書きする。
  空の値は上書きしない
- `repo_token` は `.coveralls.yml` の値を `COVERALLS_REPO_TOKEN` が上書きする。8 の分岐では、どちらも
  無いときだけ `GITHUB_TOKEN` を使う。**どの CI でも（Travis でも）`repo_token` が無いと `die` する**
- 8 の `service_job_id` は `GITHUB_JOB` で、`COVERALLS_FLAG_NAME` があれば `<GITHUB_JOB>-<FLAG_NAME>` にする。
  マトリクスの各ジョブは `GITHUB_JOB` が同じなので、並列のビルドでジョブを区別するため（公式は `GITHUB_JOB` のまま）
- 各 CI の環境変数と送る項目を足すときは、公式の coverage-reporter（`src/coverage_reporter/ci/*.cr`）を参考にする。
  ただし次は意図して公式と違えているので、公式に合わせて戻さない
  - Jenkins のブランチは `CHANGE_BRANCH` を `BRANCH_NAME` より先に見る（PR のビルドで `BRANCH_NAME` は `PR-<番号>` になるため）
  - `get_git_info` は、作業ツリーの中では `GIT_AUTHOR_NAME` / `GIT_BRANCH` などより git の値を先に使う
    （公式は環境変数が先）。`GIT_AUTHOR_*` / `GIT_COMMITTER_*` は git 自身の変数で、CI のジョブが自分の
    コミット用にボットの名前を入れていることがあり、Jenkins は `GIT_BRANCH` に `origin/<ブランチ>` を入れるため
  - 既存の `service_name`（`azure-pipelines` など）と、Azure の `service_number` は、送ってきた値を変えない（Coveralls 上の既存のビルドと揃えるため）
- `COVERALLS_PARALLEL` と `COVERALLS_NO_FAIL` は、空、`false`、`0` なら無効（`is_enabled`）
- ブランチ名は `git branch` の結果を、`BUILD_SOURCEBRANCHNAME` があればそちらで上書きする。
  さらに `report` で、CI から取れた `service_branch` / `commit_sha` を `git.branch` / `git.head.id` に
  上書きする（`apply_ci_git_info`）
- **新しい CI を足すときは、分岐の位置で既存の CI の判定を奪わないか確認する。** 利用者向けの環境変数を
  足したら POD の `=head1 ENVIRONMENT` にも書く

## 書き方の制約

- **最低対応バージョンは Perl 5.20**（`use 5.020`）。今の Devel::Cover（1.52）が 5.20 を要求するため。
  5.22 以降の構文や機能は使わない。`<<>>`、`<<~` のヒアドキュメント、`isa` 演算子などが該当する。
  5.20 で experimental の postfix deref（`$ref->@*`）とサブルーチンのシグネチャも使わない。
  `//`、`say`、`s///r` は使ってよい。`given/when`（smartmatch）は experimental で廃止が
  決まっているので使わない。CI の `master.yml` は `oldest-perl` ジョブで 5.20 を、`perl` ジョブで
  5.26 以降を確かめている。宣言と `oldest-perl` の版は一緒に変える
- 依存はコアモジュールか `cpanfile` に宣言済みのものに限る。増やすときは `cpanfile` に足す
- CI は Linux / Windows（Strawberry Perl）/ macOS で動く。パス区切りやシェルのクォートなど、
  POSIX のシェルだけを前提にした書き方は Windows で動かないことがある
- インデントは 4 スペース。ファイルを開くときはレキシカルなファイルハンドルと 3 引数の `open` を使う

## テスト

ホストの Perl には依存モジュール（`Devel::Cover` など）が入っていないことが多い。その場合は
`docker-compose.yml` のコンテナで実行する。イメージは repo の `Dockerfile`（公式の `perl:5.44` に
cpm を足したもの）からビルドされる。

```sh
docker compose run --rm perl cpm install --with-develop   # cpanfile から依存を入れる（下のボリューム）
docker compose run --rm perl prove -l t                   # 全テスト
docker compose run --rm perl minil build                  # 生成物の作り直し（上の「生成物は直接編集しない」）
```

`perl Build.PL && ./Build build && ./Build test` でも同じテストが走る（CI はこちら）。

- コンテナはホストのユーザー（既定は uid / gid 1000）で動くので、書き出したファイルは root 所有に
  ならない。ホストの uid / gid が 1000 でなければ、repo 直下の `.env`（`.gitignore` 済み、compose が
  自動で読む）に `HOST_UID=<uid>` と `HOST_GID=<gid>` を書き、`docker compose build` からやり直す。
  ボリュームの所有者は作ったときの uid のまま変わらないので、作った後なら `docker compose down -v` で
  消してから入れ直す
- 依存は名前付きボリューム `perl-local-5.44` に入る（repo の `local/` ではない）。Perl の版を上げるときは、
  `Dockerfile` と一緒にボリューム名も変える（別の版でビルドした XS モジュールは読み込めない）。前の
  ボリュームは `docker volume rm coveralls-perl_<前の名前>` で消す（perl-cpm のころのものは
  `coveralls-perl_perl-local`）
- コンテナの `HOME` は同じボリュームの中の `/app/local/.home` にしてある。cpm のダウンロードの
  キャッシュとビルドのログ（`~/.perl-cpm`）を、`--rm` で消さないため。**`cpm install` が失敗したら、
  `docker compose run --rm perl cat /app/local/.home/.perl-cpm/build.log` でログを読む**
- `PATH` は `Dockerfile` の `ENV` で、イメージの既定の `PATH` の前に `/app/local/bin` を足している。
  `docker-compose.yml` で `PATH` を丸ごと置き換えない（イメージの既定のディレクトリが消える）
- **Perl の版は次の 4 つで揃える。** `Dockerfile` の `FROM`、`docker-compose.yml` のボリューム名、
  `master.yml` の `perl:<版>`、`publish.yml` の `perl-version`。`master.yml` では、`perl` のマトリクスの
  最新版と `include:`、`dist` のコンテナが該当する。版を上げるときは `git grep -n '5\.44'` のように
  前の版で repo を探し、この節や各ファイルのコメントに書いた版も一緒に直す。Dependabot（`dependabot.yml` の `docker`）が PR で
  上げるのは `Dockerfile` だけだ。その PR を取り込むときは、残りも同じ PR で手で上げる。
  食い違いは `master.yml` の `perl-version-sync` ジョブ（`scripts/check-perl-version.pl`）が落とす。
  手元では `perl scripts/check-perl-version.pl` で確かめられる。このスクリプトは版を書いた行の形を
  正規表現で探すので、該当する行の書き方を変えたら、スクリプトも合わせて直す

- **`t/01_basic.t` で `get_config` を試す subtest は、最初に `local @ENV{@CI_VARS};` で CI の環境変数を
  すべて消す。** テスト自体が CI の上で走る。`GITHUB_TOKEN` や `GITHUB_ACTIONS` が入っていると、
  別の分岐に入る。`get_config` / `get_git_info` が読む環境変数を足したら、`@CI_VARS` にも足す
- `get_git_info` を呼ぶテストは、git の作業ツリーの中で実行する必要がある
- **テストから `report` を呼ぶときは、`HTTP::Tiny::request` を `local` で差し替える。** 差し替えないと
  Coveralls へ実際に POST する。例は `t/01_basic.t` の「report exits non-zero when the upload fails」
- CI の `master.yml` は perl 5.44（マトリクスの最新版）のときだけ、このモジュール自身で自分のカバレッジを Coveralls へ送る
  （`DEVEL_COVER_SELF=1`）

## CI（GitHub Actions）

- action のバージョンは `.github/workflows/actions.lock` で固定している。**`uses:` の行を変えたら、
  repo のルートで `gh actions-lock` を実行し、書き換わったワークフローと lockfile を一緒にコミットする。**
  lockfile を手で編集しない
- **Linux のジョブは、できるだけ Docker Hub の `perl:<版>` のコンテナで動かす。** actions-setup-perl は
  Perl を GitHub Releases から認証なしでダウンロードするので、GitHub が匿名のアクセスを絞ると 504 で
  落ちる。`oldest-perl` と `publish.yml` だけは actions-setup-perl のまま。今の runner で使える `perl` の
  イメージは 5.26 以降だけで（`master.yml` のマトリクスのコメント）、`publish.yml` はコンテナにすると
  Node も用意し直すことになるため。504 で落ちたら `gh run rerun <run-id> --failed` で再実行する
- `actions/checkout` には `persist-credentials: false` を付ける（checkout の認証情報を `.git/config` に
  残さない）。外してよいのは、そのジョブが checkout の認証情報で push するときだけ
- Dependabot が action の更新 PR を週 1 回出す（lockfile も書き換わる）。開発用コンテナの `Dockerfile` の
  ベースイメージの更新 PR も出す。その PR で揃えるものは上の「テスト」

## バージョンとリリース

リリースは tagpr で行う。`master` への push ごとに `tagpr.yml` がリリース PR を作り直し、
メンテナがそれをマージするとタグが打たれ、`publish.yml` が CPAN（PAUSE）へアップロードして
GitHub Release を作る。仕組みと落ちたときの扱いは `scripts/tagpr/README.md` の「The tagpr workflow」、
メンテナの手順は `RELEASE.md`。

- **版を手で変えない。** 版は `Coveralls.pm` の `our $VERSION` と `META.json` にあり、どちらも
  リリース PR で tagpr が上げる。`minil release` は使わない（版を上げてタグを打つのは tagpr の役目）
- **版は 3 つ組（`1.0.1`、`1.1.0`）にする。** 0.x の 3 つ組は数値にすると 0.32 より小さくなり、
  PAUSE の索引に載らなかった（#50）。1.0.0 以降は 3 つ組のまま上がっていく
- **利用者に見える変更をする PR は、`CHANGELOG.md` の `## [Unreleased]` の下に 1 行を足す。**
  その節がそのままリリースノートになる。外部の貢献者の変更には、既存の行にならって
  `(thanks <GitHub のユーザー名>)` を付ける。リンクは行の中に書く（参照リンクの定義は節の外にあり、
  リリースノートではリンクにならない）。見出しや末尾のリンクの形は `scripts/tagpr/README.md` の
  「What the CHANGELOG has to look like」
- **`scripts/tagpr/` を手で編集しない。** 変えるときは kan/tagpr-scripts を直し、
  `git subtree pull -S --prefix=scripts/tagpr https://github.com/kan/tagpr-scripts.git main --squash` で
  取り込む。同じ PR で `tagpr.yml` の `uses: kan/tagpr-scripts/...@<SHA>` を、squash のコミットの
  `git-subtree-split` の SHA へ上げる。食い違いは `master.yml` の `tagpr-subtree` ジョブが落とす。
  **この PR はマージコミットでマージする**（squash すると次の subtree pull が壊れる）
- PAUSE の認証情報は GitHub の `cpan` environment の secret（`PAUSE_USER` / `PAUSE_PASSWORD`）にある。
  repo のルートに `.pause`（手で PAUSE へ上げていたころの認証情報）があっても、コミットしない（`.gitignore` 済み）

## 運用

- **`master` へ直接 push しない。** ブランチを切って PR で入れる。tagpr はマージされた PR から
  リリース PR を組み立てるため、直接 push した変更はリリースの流れから漏れる
- CI（`master.yml` / `windows.yml` / `mac.yml`）は `master` への push と PR で走る。作業ブランチを
  push しただけでは走らないので、CI で確かめたいときは PR を作る。tagpr のリリース PR では CI が
  走らない（`GITHUB_TOKEN` で作られた PR は workflow を起動しない）。リリース PR の版と CHANGELOG は、
  tagpr の run の中で `release-prepare.mjs` が確かめる
- コミットメッセージの言語は日本語と英語のどちらでもよい（履歴には両方ある）
