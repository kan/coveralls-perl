# リリース手順

リリースは tagpr で行う。手元で `minil release` は実行しない。仕組みの詳細と、落ちたときの
扱いは `scripts/tagpr/README.md` の「The tagpr workflow」にある。

## 普段の流れ

1. 変更は PR で入れる。利用者に見える変更の PR は、`CHANGELOG.md` の `## [Unreleased]` の下に
   1 行を足す
2. `master` へマージされるたびに、`tagpr.yml` がリリース PR（ブランチ `tagpr-from-v<前の版>`）を
   作り直す。リリース PR は `Coveralls.pm` の `$VERSION` と `META.json` の版を上げ、
   `## [Unreleased]` をその版の節に変える
3. 出したくなったら、リリース PR の中身（版と CHANGELOG の節）を確かめてマージする
   - **tagpr の run が赤いリリース PR はマージしない**（落ちた run はリリース PR を draft にする）
   - リリース PR では CI（`master.yml` など）が走らない。tagpr が `GITHUB_TOKEN` で作る PR は、
     workflow を起動しないため。版と CHANGELOG の検査は、tagpr の run の中の
     `release-prepare.mjs` が行う
   - 版の上がり方はラベルで決まる。`enhancement` の PR が入っていれば minor、それ以外は patch。
     変えたいときはリリース PR に `tagpr:minor` / `tagpr:major` を付ける。`tagpr-label.yml` が
     リリース PR を draft にして作り直し、ready に戻す。ready に戻るのを待ってからマージする
   - マージの run が取り消されてタグが打たれなかったときは、次の tagpr の run がマージの run を
     再実行してタグを打たせる。それでも打たれなかったときだけ、マージコミットの run を手で再実行する
4. マージすると、tagpr がタグ（`vX.Y.Z`）を打ち、`publish.yml` が起動する。`publish.yml` は
   テストして tarball を作り、PAUSE へアップロードしてから GitHub Release を作る
5. PAUSE から届く索引のメールを確かめる

**PAUSE へのアップロードは取り消せない。** 同じファイル名は二度と受け付けられないので、壊れた版を
出したら版を上げて出し直す。

## 最初に一度だけ要る設定

- tagpr が数え始めるタグとして、`v0.32.1` を e3ac4b4（「release 0.32.1」）に annotated で打って push する
  （`git tag -a -m "Release v0.32.1" v0.32.1 e3ac4b4`）。`.tagpr` が `master` に入る前に済ませる。
  無いと tagpr は前の版を 0.0.0 と見て、版のファイルを書き換えられない
- Settings → Actions → General の「Allow GitHub Actions to create and approve pull requests」を
  有効にする（無いと最初の tagpr の run が 403 で落ちる）
- Settings → Environments に `cpan` を作り、secret `PAUSE_USER`（PAUSE の ID、`KAN`）と
  `PAUSE_PASSWORD` を置く。値は 1Password にある

## 1.0.0 について

tagpr での最初のリリースは 1.0.0 にする（#50）。0.x の 3 つ組の版は、数値にすると 0.32 より小さく
なり、PAUSE の索引に載らない（0.32.1 は 0.032001）。最初のリリース PR に `tagpr:major` を付ける。
