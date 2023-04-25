# リリース手順

## リポジトリをcloneし、.pauseを作成

```
git clone git@github.com:kan/coveralls-perl.git
vim .pause # PAUSEアカウント情報は1passwordを参照
```

## モジュールのVERSIONを変更し、Changesを更新

リリース内容の最終確認

## docker-compose で環境を作成・起動してperlコンテナに入る

```
docker-compose up -d
docker-compose exec perl bash
```

以下、perlコンテナ内で作業

## .pauseを ~/ 直下にコピーしてMinillaによるリリースを実行

```
cp .pause ~/
cpm install --with-develop
local/bin/minil release
```
