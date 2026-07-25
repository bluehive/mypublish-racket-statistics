---
title: "付録A　付属ソースコード一覧（ガイド）"
---

> **この付録のゴール**  
> 本書籍で作成・使用する付属プログラム（`code/` 配下）のファイル構成と役割を一覧で確認できるようにする。  

#### A.1 はじめに

- 本書の付属コードは、リポジトリの `code/` ディレクトリに配置されています。
- 正本の場所: [code/（main ブランチ）](https://github.com/bluehive/mypublish-racket-statistics/tree/main/code)
- 実行言語はすべて **Racket (`#lang racket`)** です。
- 実行はリポジトリの root ディレクトリから、次のように行います。

```bash
racket code/ch01-basics.rkt
```

#### A.2 ファイル一覧と役割

* **[ch01-basics.rkt](https://github.com/bluehive/mypublish-racket-statistics/blob/main/code/ch01-basics.rkt)**
  * **章**: 第1章
  * **役割**: Racket 基本文法、`define`、`cond`、リスト・ハッシュ構造の動作サンプル
* **[ch02-fetch-data.rkt](https://github.com/bluehive/mypublish-racket-statistics/blob/main/code/ch02-fetch-data.rkt)**
  * **章**: 第2章
  * **役割**: `net/url` を用いた Web データのダウンロード処理
* **[ch03-racketframes-basics.rkt](https://github.com/bluehive/mypublish-racket-statistics/blob/main/code/ch03-racketframes-basics.rkt)**
  * **章**: 第3章
  * **役割**: RacketFrames による CSV 読み込み（`read-csv`）、列操作（`df-project`）、欠損値除去（`df-drop-na`）
* **[ch04-analysis.rkt](https://github.com/bluehive/mypublish-racket-statistics/blob/main/code/ch04-analysis.rkt)**
  * **章**: 第4章
  * **役割**: 平均・標準偏差の算出（`df-mean`/`df-std`）、フィルタリング（`df-filter`）、`Groupby` による枠番別集計
* **[ch05-visualization.rkt](https://github.com/bluehive/mypublish-racket-statistics/blob/main/code/ch05-visualization.rkt)**
  * **章**: 第5章
  * **役割**: `df-plot-scatter` や `df-plot-histogram` によるグラフ可視化、JSON/CSV 出力
* **[ch06-prediction.rkt](https://github.com/bluehive/mypublish-racket-statistics/blob/main/code/ch06-prediction.rkt)**
  * **章**: 第6章
  * **役割**: データフレームの結合（`df-join`）、スコアリングモデルの構築、予測的中率の検証ロジック

#### A.3 迷ったときの使い分け

1. 各章の本文を読みながら、対応する `code/ch0N-....rkt` を DrRacket で開き **Run** ボタンを押して実行してください。
2. 動作確認や実験は、相互作用ウィンドウ（下段 REPL）で関数を個別に呼び出して行えます。

---

* ※付属コード構成の整理：三角ロジックで整理予定
