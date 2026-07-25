---
title: "付録D　mise を使ったタスクの自動化とZennへのデプロイ方法"
---

> **この付録のゴール**  
> 開発タスクランナー `mise` を使いこなして、Zenn でのローカルプレビュー、電子書籍（EPUB）ビルド、および Zenn.dev へのワンコマンドデプロイを実行できるようになる。  

#### D.1 タスクランナー `mise` とは

`mise` は、プロジェクトごとのツール（Node.js や Python など）のバージョン管理と、コマンド実行の自動化を行う現代的なタスクランナーです。リポジトリ直下の `mise.toml` に定義されたコマンドを、シンプルなショートカットで呼び出すことができます。

#### D.2 主要タスクコマンド一覧

リポジトリのルートディレクトリで、以下のコマンドを実行できます。

##### 1. Zenn CLI でのプレビュー（ローカル閲覧）
```bash
# Zenn プレビューサーバーの起動 (localhost:8000 で確認)
mise run zenn:preview
```
ブラウザで `http://localhost:8000` を開くと、執筆中の章がどのようなデザインで表示されるかリアルタイムに確認できます。

##### 2. テストの実行
```bash
# code/ 配下の Racket プログラムを一括テスト
mise run test:racket
```

##### 3. 電子書籍（EPUB）へのコンパイル
```bash
# 横書き EPUB のビルド
mise run book:epub

# 縦書き EPUB のビルド
mise run book:epub-vertical
```
ビルド成果物は `output/racket-statistics/` ディレクトリに生成されます。

##### 4. Zenn.dev へのアップロード（デプロイ）
```bash
# GitHub origin main へ push して Zenn へデプロイ
mise run zenn:deploy
```
このタスクを実行すると、`git push origin main` が自動実行され、GitHub と連携された Zenn.dev 上に最新の書籍内容が公開されます。

---

* ※タスク自動化とデプロイの整理：三角ロジックで整理予定
