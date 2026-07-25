---
title: "第2章　ボートレースのデータを集める（データ収集）"
---

> **この章のゴール**  
> Webや外部ツール（`curl`）およびオープンAPI（`boatraceopenapi`）を活用してボートレースのデータ（JSON/HTML）を手元に取得し、プログラムで扱える構造化CSVへと変換する。  
> **【本線】**: `boatraceopenapi` から構造化 JSON (`today.json`) を取得し、Racket 標準の `(require json)` で一発パース（`code/ch02-json-parser.rkt`）。  
> **【参考・応用】**: 公式Webサイト（HTML生データ）の `curl` 取得と正規表現パース（`code/ch02-html-parser.rkt`）。  
> **使用技術**: Racket `net/url`, `json`, `curl`, `mise` タスクランナー (`mise run parse:json`, `mise run parse:html`)

本章では、統計分析の土台となる「データ収集」の手法を学びます。現在ではボートレースのデータをオープンデータとして JSON 形式で配信する **`boatraceopenapi/api`** が存在するため、本章では **「構造化 JSON データを Racket で読み込む手法」を本線** として解説します。

また、従来手法や他言語ライブラリ（`pyjpboatrace` 等）でよく行われている **「公式Webサイトから HTML 生データをダウンロードしてパースする手法」** も発展学習として併せて解説します。

---

#### 2.1 【本線】オープンデータ API から構造化 JSON を取得してパースする

最もしっくりかつ確実なデータ収集法は、すでに構造化されて提供されている **JSON データ API** を活用することです。

##### 1. `boatraceopenapi/api` とは？
[boatraceopenapi/api](https://github.com/boatraceopenapi/api) は、GitHub Actions と GitHub Pages を利用して全国 24 場のボートレースデータ（出走表・直前情報・確定着順）を JSON 形式で配信しているオープンプロジェクトです。

- **本日の全場データ**: `https://boatraceopenapi.github.io/api/v1/today.json`
- **過去データ（年月日指定）**: `https://boatraceopenapi.github.io/api/v1/YYYY/YYYYMMDD.json`

##### 2. `mise` による JSON データの自動取得
ターミナルから以下のタスクコマンドを実行するだけで、本日の最新全場データが `data/raw/today.json` へ安全かつ高速にダウンロードされます。

```bash
# boatraceopenapi から本日の全場レースデータ (JSON) を自動取得
mise run data:download:json
```

##### 3. Racket 標準 `(require json)` による JSON パース（`code/ch02-json-parser.rkt`）
Racket には標準で JSON を扱う強力なライブラリ `(require json)` が備わっています。これを使うと、正規表現や複雑な HTML タグ解析を書くことなく、ハッシュテーブル (`hash`) として一発でデータを抽出し、CSV ファイルへ自動変換できます。

付属ソースコード [code/ch02-json-parser.rkt](file:///home/mevius/my-project/mypublish-racket-statistics/code/ch02-json-parser.rkt) の主要ロジックは以下の通りです。

```racket
#lang racket
(require json)

;; 1. JSON ファイルを読み込み、Racket ハッシュに変換
(define data (call-with-input-file "data/raw/today.json" read-json))

;; 2. programs -> stadiums -> races -> racers を安全に走査して抽出
;; (RacketFrames の入力形式である CSV data/parsed_races.csv へ書き出し)
```

実行は以下のコマンド一発です：

```bash
# 【本線】Racket による JSON パース & CSV 変換パイプラインの実行
mise run parse:json
```

---

#### 2.2 【応用・参考】公式Webサイト（HTML生データ）の `curl` 取得とパース

一方、Web サイトによっては公式 API が存在せず、ブラウザ表示用の **HTML ファイル** を取得してパースしなければならない場面もあります。

##### 1. `curl` による公式 Web データ取得
ボートレース公式 Web サイト（`boatrace.jp`）から出走表 HTML を取得するタスクも `mise.toml` に併記されています。サーバー負荷を下げるため **`--limit-rate 100k` オプションと `sleep`** を組み込んで安全に取得します。

```bash
# ボートレース公式Webサイトから出走表HTMLを安全に自動取得する
mise run data:download:official
```

##### 2. Racket 単体での HTML パース（`code/ch02-html-parser.rkt`）
取得した HTML 生データから、正規表現（`regexp-match*`）を用いて艇番・選手名・勝率などをすくい取るパース処理も Racket 1本で実現可能です。

付属ソースコード [code/ch02-html-parser.rkt](file:///home/mevius/my-project/mypublish-racket-statistics/code/ch02-html-parser.rkt) でその仕組みを体験できます。

```bash
# 【参考】Racket による HTML パース処理の実行
mise run parse:html
```

---

#### 2.3 💡 生データ (HTML) と構造化データ (JSON/CSV) のパイプライン比較

データ分析における 2 つのアプローチの違いを整理しましょう。

```text
  【本線パイプライン (JSON API)】
   [boatraceopenapi API] ─── curl ───> 生JSON (today.json)
                                              │
                                              ▼ (require json) でパース
   RacketFrames で分析! <─── CSV保存 <─── 構造化データ (data/parsed_races.csv)

  【従来/応用パイプライン (HTML スクレイピング)】
   [ボートレース公式Web] ─── curl ───> 生HTML (racelist.html)
                                              │
                                              ▼ 正規表現 / HTMLパース
   RacketFrames で分析! <─── CSV保存 <─── 構造化データ (data/parsed_races.csv)
```

1. **構造化 JSON (本線)**: API から提供される最初から整理されたデータ。キー名（`racer_name`, `national_win_rate` 等）で直接アクセスでき、破綻しにくく最も安定しています。
2. **生データ HTML (参考/応用)**: Web ページの装飾が含まれた人間用データ。タグ構造が変わるとパースが壊れやすいため、API が存在しない場合の最終手段として役立ちます。

---

#### 2.4 CSVファイル形式とボートレースデータの構造

パース生成された **CSV（Comma-Separated Values）** 形式のデータ構造は以下の通りです。

```csv
stadium_num,race_num,boat_num,racer_id,racer_name,rank,win_rate,motor_rate
23,11,1,4362,土屋 智則,A1,6.7,33.67
23,11,2,4289,落合 直子,A2,5.59,33.51
23,11,3,4216,星 栄爾,B1,4.53,37.44
...
```

次章では、この CSV データを **RacketFrames** を使って読み込み、データフレームとして自在に扱う方法を学びます。

---

> ### 📖 【コラム】他言語の知見を活かす：Pythonライブラリ `pyjpboatrace` に学ぶデータ構造と公式取得
> 
> **1. URL構成（情報のありか）の分析と curl タスク**
> ボートレースのオフィシャルサイト（`boatrace.jp`）からデータを取得するためには、情報がどのような「住所（URL）」に整理されているかを特定する必要があります。
> * **番組表（出走表）**: `https://www.boatrace.jp/owpc/pc/race/racelist?rno=[レース番号]&jcd=[場コード]&hd=[日付]`
> * **レース結果**: `https://www.boatrace.jp/owpc/pc/race/raceresult?rno=[レース番号]&jcd=[場コード]&hd=[日付]`
> 
> **2. データの項目（スキーマ）の設計手本**
> `pyjpboatrace` が HTML から抽出して構造化している項目群は、私たちが RacketFrames の `DataFrame` に取り込むべき「列（Series）」の設計基準になります。
