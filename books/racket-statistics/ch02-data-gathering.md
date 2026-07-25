---
title: "第2章　ボートレースのデータを集める（データ収集）"
---

> **この章のゴール**  
> Webや外部ツール（`curl`）を活用してボートレースのデータ（CSV/HTML）を手元に取得し、プログラムで扱える状態にする。生データ（HTML）と構造化データ（CSV）の違い、および `code/ch02-html-parser.rkt` による Racket 単体でのパース変換パイプラインを理解する。  
> **使用技術**: Racket `net/url`, `curl` (スリープ・通信速度制限付き), `mise` タスクランナー (`mise run parse:html`), Racket による HTML パース  

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

##### 1. コマンドラインでの `curl` の安全な実行
ターミナルから以下のコマンドを実行すると、リポジトリに配置されている公式サンプルデータ（`sample_races.csv`）を、サーバー負荷を下げる **`--limit-rate 100k`（速度制限オプション）** 付きで手元のフォルダに安全に保存できます。

```bash
# サンプルデータの安全なダウンロード例 (通信速度制限 --limit-rate 100k 付き)
curl -s --limit-rate 100k -o data/sample_races.csv "https://raw.githubusercontent.com/bluehive/mypublish-racket-statistics/main/data/sample_races.csv"
```

##### 2. `mise.toml` による公式Webデータ取得タスクの自動化
後述の `pyjpboatrace` のURL構造を参考に、ボートレース公式Webサイトから本日の出走表データ（HTML）を `curl` で安全に自動取得するタスクが `mise.toml` に用意されています。このタスクには **`--limit-rate 100k` オプションと `sleep 1` 秒のアクセス待ち時間** が組み込まれています。

```bash
# ボートレース公式Webサイトから出走表HTMLを安全に自動取得する (スリープ・速度制限付き)
mise run data:download:official
```

実行すると、`data/raw/racelist_sample.html` に最新の出走表データが保存されます。

---

#### 2.3 💡 なぜ公式データは HTML なのか？（生データと CSV のデータパイプライン）

ここで「`curl` でボートレース公式Webサイト（`boatrace.jp`）からダウンロードしたデータは、なぜ CSV ではなく **HTML**（Webページの見た目用ファイル）なのか？」という疑問が浮かぶかもしれません。

これこそがデータサイエンスにおける **「生データ（Raw Data）」** と **「構造化データ（Structured Data / CSV）」** の重要な違いです！

```text
  【ボートレースデータの変換パイプライン (pyjpboatrace などの内部構造)】

   ① [ボートレース公式Web] ─── curl ───> ② 生データ (HTML / 公式テキストTXT)
                                                 │
                                                 ▼ (前処理・HTMLパース処理)
   ④ RacketFrames で分析! <─── CSV保存 <─── ③ 構造化データ (CSV / JSON)
```

1. **公式Webサイトの生データ (Raw Data / HTML)**:
   公式Webサイト（`boatrace.jp`）が配信しているのは、人間がブラウザで見やすく装飾された **HTML ファイル** です。そのままではプログラムで直接計算できません。
2. **`pyjpboatrace` などのパース（抽出）ライブラリの役割**:
   Python ライブラリ `pyjpboatrace` などは、この生データ（HTML）を自動ダウンロードし、内部で HTML タグを解析（パース）して、必要な数値（勝率・モーター率・着順）だけを取り出した **CSV や JSON などの構造化データ** へと自動変換しています。

##### 🚀 Racket 単体での HTML パース ＆ CSV 変換（`code/ch02-html-parser.rkt`）

「誰が変換パイプラインをやるの？ Racket でできるの？」の答えは、**「Racket 1本だけで 100% 可能！」** です。

付属のソースコード [/home/mevius/my-project/mypublish-racket-statistics/code/ch02-html-parser.rkt](file:///home/mevius/my-project/mypublish-racket-statistics/code/ch02-html-parser.rkt)（タスクコマンド: `mise run parse:html`）を実行すると、Racket 標準の正規表現が HTML から選手名・勝率・モーター率をすくい取り、構造化データ `data/parsed_races.csv` へと全自動変換する様子を体験できます！

```racket
#lang racket
;; 【code/ch02-html-parser.rkt より抜粋】
;; 正規表現で HTML タグの中身（艇番・選手名・勝率・モーター率・着順）を一括抽出
(define boat-pattern #px"<span class='boat'>(.*?)</span>")
(define racer-pattern #px"<span class='racer'>(.*?)</span>")
(define win-pattern #px"<span class='win-rate'>(.*?)</span>")

(define boats (map second (regexp-match* boat-pattern sample-html #:match-select (lambda (m) m))))
(define racers (map second (regexp-match* racer-pattern sample-html #:match-select (lambda (m) m))))
(define win-rates (map second (regexp-match* win-pattern sample-html #:match-select (lambda (m) m))))

;; 構造化 CSV データ (data/parsed_races.csv) として自動書き出し！
(define out-port (open-output-file "data/parsed_races.csv" #:exists 'replace))
(displayln "boat_num,racer_name,win_rate,motor_rate,rank" out-port)

(for ([b boats] [r racers] [w win-rates])
  (displayln (format "~a,~a,~a" b r w) out-port))

(close-output-port out-port)
```

ターミナルで **`mise run parse:html`** を叩くだけで、Racket による HTML パース処理が走ります！

---

#### 2.4 CSVファイル形式とボートレースデータの構造

前処理された **CSV（Comma-Separated Values）** 形式のデータは、データをカンマ `,` で区切った単純なテキストファイルで、RacketFrames でそのまま読み込めます。

本書で扱うボートレースデータ（`data/sample_races.csv`）の標準的な構造は以下のとおりです。

```csv
race_id,stadium,boat_num,racer_id,racer_name,win_rate,motor_rate,rank
20260725-01-01,桐生,1,4320,峰竜太,0.85,0.42,1
20260725-01-01,桐生,2,4444,毒島誠,0.81,0.38,2
20260725-01-01,桐生,3,3783,瓜生正義,0.72,0.35,3
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
