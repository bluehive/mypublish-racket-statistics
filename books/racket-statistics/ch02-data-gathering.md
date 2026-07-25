---
title: "第2章　ボートレースのデータを集める（データ収集）"
---

> **この章のゴール**  
> Webや外部ツール（`curl`）を活用してボートレースのデータ（CSV/HTML）を手元に取得し、プログラムで扱える状態にする。付属のサンプルデータ（`code/sample_races.csv` / `data/sample_races.csv`）および公式Webデータ取得の仕組みを理解する。  
> **使用技術**: Racket `net/url`, `curl`, `mise` タスクランナー, `pyjpboatrace` のURL設計  

本章では、統計分析の土台となる「データ収集（スクレイピングとダウンロード）」の手法を学びます。Racket のネットワーク機能を使う方法と、より簡単で確実な外部ツール（`curl`）を `mise` タスクランナーで実行する方法の 2 通りを解説します。

#### 2.1 Webからデータをダウンロードする（RacketのHTTP機能）

Racket には、標準でネットワーク通信を行うためのライブラリ `net/url` が用意されています。これを使うと、指定した Web ページのテキストや HTML をプログラム内へ直接読み込むことができます。

```racket
#lang racket
(require net/url)

;; 指定したURLからデータを文字列として取得する関数
(define (fetch-page url-string)
  (define my-url (string->url url-string))
  (define in-port (get-pure-port my-url))
  (define content (port->string in-port))
  (close-input-port in-port)
  content)

;; 例: テスト用データページの取得
;; (fetch-page "https://example.com/boatrace-sample.html")
```

この方法を使うことで、プログラムの中から直接最新のデータを取得できます。

#### 2.2 データのダウンロードが難しい場合の代替策（`curl` と `mise` タスクランナー）

Web サイトによっては、高度なアクセス制御（JavaScriptの実行要求など）が施されている場合があります。また、通信処理のコードを毎回書くのが大変な場合もあります。

そこで、より簡単かつ確実にデータを一括ダウンロードするための代替策として、強力なコマンドラインツール **`curl`** と、タスクランナー **`mise`** を組み合わせた手法を活用します。

##### 1. コマンドラインでの `curl` の実行
ターミナルから以下のコマンドを実行すると、リポジトリに配置されている公式サンプルデータ（`sample_races.csv`）を手元のフォルダに保存できます。

```bash
# サンプルデータのダウンロード例
curl -s -o data/sample_races.csv "https://raw.githubusercontent.com/bluehive/mypublish-racket-statistics/main/data/sample_races.csv"
```

##### 2. `mise.toml` による公式データ取得タスクの自動化
後述の `pyjpboatrace` のURL構造を参考に、ボートレース公式Webサイトから本日の出走表データ（HTML）を `curl` で一瞬で自動取得するタスクが `mise.toml` に用意されています。

```bash
# ボートレース公式Webサイトから出走表HTMLを自動取得する
mise run data:download:official
```

実行すると、`data/raw/racelist_sample.html` に最新の出走表データが保存されます。付属のソースコードフォルダ（`code/`）内にも予備のデータが保管されています。

#### 2.3 CSVファイル形式とボートレースデータの構造

ダウンロードしたデータは、扱いやすい **CSV（Comma-Separated Values）** 形式で保存されます。CSV は、データをカンマ `,` で区切った単純なテキストファイルです。

本書で扱うボートレースデータ（`data/sample_races.csv`）の標準的な構造は以下のとおりです。

```csv
race_id,stadium,boat_num,racer_id,racer_name,win_rate,motor_rate,rank
20260725-01-01,桐生,1,4320,峰竜太,0.85,0.42,1
20260725-01-01,桐生,2,4444,毒島誠,0.81,0.38,2
20260725-01-01,桐生,3,3783,瓜生正義,0.72,0.35,3
...
```

* **`race_id`**: レースを識別する固有ID（日付-場コード-レース番号）
* **`stadium`**: レース場名（桐生、平和島、住之江など）
* **`boat_num`**: 艇番（1〜6枠）
* **`racer_id`**: レーサーの登録番号
* **`racer_name`**: 選手名
* **`win_rate`**: レーサーの全国勝率（0.00〜1.00）
* **`motor_rate`**: モーターの2連対率（0.00〜1.00）
* **`rank`**: 実際の確定着順（1〜6）

次章では、この CSV データを **RacketFrames** を使って読み込み、データフレームとして自在に扱う方法を学びます。

---

> ### 📖 【コラム】他言語の知見を活かす：Pythonライブラリ `pyjpboatrace` に学ぶデータ構造と公式取得
> 
> **大学図書館の司書より：知的なリサーチのヒント**
> 
> 先人の知恵が集積された「目録」や「ライブラリ」を調べることは、学術研究において最も基本的かつ有意義なステップです。
> 私たちがこれから Racket で構築するプログラムの設計図を描くにあたり、Python の世界で広く利用されているオープンソースソフトウェア **`pyjpboatrace`**（[hmasdev/pyjpboatrace](https://github.com/hmasdev/pyjpboatrace)）のデータ構造は大いなる参考資料となります。
> 
> **1. URL構成（情報のありか）の分析と curl タスク**
> ボートレースのオフィシャルサイト（`boatrace.jp`）からデータを取得するためには、情報がどのような「住所（URL）」に整理されているかを特定する必要があります。`pyjpboatrace` の内部実装を紐解くと、以下のようなパラメータ構成で各ページが配置されていることがわかります。
> * **番組表（出走表）**: `https://www.boatrace.jp/owpc/pc/race/racelist?rno=[レース番号]&jcd=[場コード]&hd=[日付]`
> * **レース結果**: `https://www.boatrace.jp/owpc/pc/race/raceresult?rno=[レース番号]&jcd=[場コード]&hd=[日付]`
> 
> ここで、`rno` はレース番号（1〜12）、`jcd` は全国24箇所のボートレース場を識別する「場コード」（例: 桐生は `01`、平和島は `04` など）、`hd` は `YYYYMMDD` 形式の日付です。
> 本書では、このURLパラメータ構造を応用し、`mise run data:download:official` というタスクで公式Webサイトの最新HTMLを一発取得できる環境を整えています。
> 
> **2. データの項目（スキーマ）の設計手本**
> `pyjpboatrace` が HTML から抽出して JSON 形式に構造化している項目群は、私たちが RacketFrames の `DataFrame` に取り込むべき「列（Series）」の設計基準になります。
> * レーサーの基本情報（登録番号、氏名、級別、年齢、体重）
> * 成績情報（全国勝率、現地勝率、モーターの複勝率、ボートの複勝率）
> 
> ⚖️ **データ収集におけるマナーと倫理（司書からの重要なお願い）**
> 図書館の資料を乱暴に扱うと他の利用者の迷惑になるのと同様に、ウェブサイトへの自動アクセスを行う際もルールを守る必要があります。アクセス頻度の制限（待ち時間）を守り、サーバーに負荷をかけない倫理的なデータ収集を行いましょう。

---

* ※データ収集手法とマナーの整理：三角ロジックで整理予定
