---
title: "第2章　ボートレースのデータを集める（データ収集）"
---

> **この章のゴール**  
> Webや外部ツール（`curl`）およびオープンAPI（`boatraceopenapi`）を活用してボートレースのデータ（JSON/HTML）を手元に取得し、プログラムで扱える構造化CSVへと変換する。  
> **【本線】**: `boatraceopenapi` から対話的日付確認（過去日指定可）により日付別 JSON (`data/raw/YYYYMMDD.json`) をダウンロード保存し、Racket 標準の `(require json)` で日付別ファイルを全自動スキャン＆蓄積パース（`code/ch02-json-parser.rkt`）。  
> **【参考・応用】**: 公式Webサイト（HTML生データ）の `curl` 取得と正規表現パース（`code/ch02-html-parser.rkt`）。  
> **使用技術**: Racket `net/url`, `json`, `curl`, `mise` タスクランナー (`mise run parse:json`, `mise run parse:html`)

本章では、統計分析の土台となる「データ収集」の手法を学びます。現在ではボートレースのデータをオープンデータとして JSON 形式で配信する **`boatraceopenapi/api`** が存在するため、本章では **「対話的な日付指定で JSON データを蓄積保存し、Racket で一括パースする手法」を本線** として解説します。

また、従来手法や他言語ライブラリ（`pyjpboatrace` 等）でよく行われている **「公式Webサイトから HTML 生データをダウンロードしてパースする手法」** も発展学習として併せて解説します。

---

#### 2.1 【本線】オープンデータ API から日付指定 JSON を取得・蓄積してパースする

最もしっくりかつ確実なデータ収集法は、すでに構造化されて提供されている **JSON データ API** を活用することです。

##### 1. `boatraceopenapi/api` と日付選択・保存の仕組み
[boatraceopenapi/api](https://github.com/boatraceopenapi/api) では、日付ごとのレースデータ（出走表・直前情報・確定着順）が以下の URL で配信されています。

- **本日のデータ**: `https://boatraceopenapi.github.io/api/v1/today.json`
- **日付指定データ（2026年01月01日以降）**: `https://boatraceopenapi.github.io/api/v1/YYYY/YYYYMMDD.json`

固定の `today.json` というファイル名だけで保存してしまうと、**翌日ダウンロードした際に前日までの過去データが上書き消失** してしまいます。
そこで本タスクでは、ダウンロード前にユーザーへ日付の確認・入力（デフォルトは本日 `YYYYMMDD`、過去日付の直接入力も可）を促し、**`data/raw/YYYYMMDD.json` として日付別に保存** する安全な設計を採用しています。

##### 2. `mise` による対話的日付確認とダウンロード
ターミナルから以下のタスクコマンドを実行すると、対話プロンプトが表示され、そのまま Enter を押すと本日のデータ、過去の日付（例: `20260501`）を入力するとその日の過去データが自動取得されます。

```bash
# boatraceopenapi からレースデータを対話的日付確認（過去日指定可）でダウンロード保存
mise run data:download:json
```

```text
取得対象の日付を入力してください (YYYYMMDD) [デフォルト: 20260726]: 20260501
ボートレースデータ (対象日: 20260501) をダウンロードしています...
ダウンロード完了: data/raw/20260501.json
```

※ 環境変数 `TARGET_DATE=20260501 mise run data:download:json` を指定すると、非対話環境（CI/自動化スクリプトなど）でも直接特定の過去データを取得できます。

##### 3. Racket による全 JSON ファイルの自動スキャン & 蓄積パース（`code/ch02-json-parser.rkt`）
Racket の標準ライブラリ `(require json)` を使い、`data/raw/` ディレクトリ配下に蓄積されたすべての `*.json` ファイルを自動検出して順次パースし、単一の構造化 CSV (`data/parsed_races.csv`) へと集約結合します。

付属ソースコード [code/ch02-json-parser.rkt](file:///home/mevius/my-project/mypublish-racket-statistics/code/ch02-json-parser.rkt) の主要ロジックは以下の通りです。

```racket
#lang racket
(require json)

;; 1. data/raw 配下の全 *.json ファイル（過去の日付分含む）を全自動検出
(define target-files
  (filter (lambda (p) (string-suffix? (path->string p) ".json"))
          (directory-list "data/raw" #:build? #t)))

;; 2. 各 JSON ファイルの programs -> stadiums -> races -> racers を走査し結合
;; (累積データとして CSV data/parsed_races.csv へ書き出し)
```

実行は以下のコマンド一発です：

```bash
# 【本線】Racket による全 JSON スキャン & CSV 蓄積パースの実行
mise run parse:json
```

日々 `mise run data:download:json` と `mise run parse:json` を動かすことで、分析用の過去レースデータが CSV にどんどん蓄積されていきます！

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
  【本線パイプライン (対話的日付指定 ＆ 日付別 JSON 蓄積)】
   [対話的日付確認] ───> [boatraceopenapi API] ─── curl ───> 日付別JSON (data/raw/YYYYMMDD.json)
                                                                       │
                                                                       ▼ (require json) で全自動スキャン
   RacketFrames で分析! <─── 累積CSV <─── 構造化データ (data/parsed_races.csv)

  【従来/応用パイプライン (HTML スクレイピング)】
   [ボートレース公式Web] ─── curl ───> 生HTML (racelist.html)
                                              │
                                              ▼ 正規表現 / HTMLパース
   RacketFrames で分析! <─── CSV保存 <─── 構造化データ (data/parsed_races.csv)
```

1. **構造化 JSON 日付別保存 (本線)**: 対話的に過去日付を指定して取得でき、日々のデータが別名ファイルで蓄積されるため、上書きリスクゼロで安定して時系列分析用データセットを拡張できます。
2. **生データ HTML (参考/応用)**: Web ページの装飾が含まれた人間用データ。タグ構造が変わるとパースが壊れやすいため、API が存在しない場合の最終手段として役立ちます。

---

#### 2.4 CSVファイル形式とボートレースデータの構造

パース生成された **CSV（Comma-Separated Values）** 形式のデータ構造は以下の通りです。日付列 (`date`) が追加され、過去複数日分のデータを識別・比較できます。

```csv
date,stadium_num,race_num,boat_num,racer_id,racer_name,rank,win_rate,motor_rate
2026-07-26,23,11,1,4362,土屋 智則,A1,6.7,33.67
2026-07-26,23,11,2,4289,落合 直子,A2,5.59,33.51
2026-07-26,23,11,3,4216,星 栄爾,B1,4.53,37.44
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
