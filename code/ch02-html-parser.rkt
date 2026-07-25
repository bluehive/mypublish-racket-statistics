#lang racket

;; =============================================================================
;; 第2章：Racket 単体による HTML 生データのパース ＆ CSV 変換パイプライン
;; 電子書籍『ボートレース統計入門』サンプルコード
;; =============================================================================

(printf "=========================================\n")
(printf " 第2章：HTML パース ＆ CSV 変換パイプライン \n")
(printf "=========================================\n\n")

;; サンプル用 HTML 生データ (racelist) のダミー/実際のテキスト
(define sample-html
  (string-append
   "<html><body>\n"
   "  <div class='race-row'>\n"
   "    <span class='boat'>1</span><span class='racer'>峰竜太</span><span class='win-rate'>0.85</span><span class='motor-rate'>0.42</span><span class='rank'>1</span>\n"
   "  </div>\n"
   "  <div class='race-row'>\n"
   "    <span class='boat'>2</span><span class='racer'>毒島誠</span><span class='win-rate'>0.81</span><span class='motor-rate'>0.38</span><span class='rank'>2</span>\n"
   "  </div>\n"
   "  <div class='race-row'>\n"
   "    <span class='boat'>3</span><span class='racer'>瓜生正義</span><span class='win-rate'>0.72</span><span class='motor-rate'>0.35</span><span class='rank'>3</span>\n"
   "  </div>\n"
   "</body></html>\n"))

(printf "1. HTML 生データ (Raw HTML) の取得が完了しました。\n\n")

;; 2. 正規表現による HTML タグからのデータ抽出（パース処理）
(define boat-pattern #px"<span class='boat'>(.*?)</span>")
(define racer-pattern #px"<span class='racer'>(.*?)</span>")
(define win-pattern #px"<span class='win-rate'>(.*?)</span>")
(define motor-pattern #px"<span class='motor-rate'>(.*?)</span>")
(define rank-pattern #px"<span class='rank'>(.*?)</span>")

(define boats (map second (regexp-match* boat-pattern sample-html #:match-select (lambda (m) m))))
(define racers (map second (regexp-match* racer-pattern sample-html #:match-select (lambda (m) m))))
(define win-rates (map second (regexp-match* win-pattern sample-html #:match-select (lambda (m) m))))
(define motor-rates (map second (regexp-match* motor-pattern sample-html #:match-select (lambda (m) m))))
(define ranks (map second (regexp-match* rank-pattern sample-html #:match-select (lambda (m) m))))

(printf "2. 正規表現による HTML パース（選手名・勝率・着順の抽出一括完了）\n\n")

;; 3. 構造化データ (CSV) ファイルとしての出力保存
(define output-csv-path "data/parsed_races.csv")
(define out-port (open-output-file output-csv-path #:exists 'replace))

(displayln "boat_num,racer_name,win_rate,motor_rate,rank" out-port)

(for ([b boats] [r racers] [w win-rates] [m motor-rates] [rk ranks])
  (displayln (format "~a,~a,~a,~a,~a" b r w m rk) out-port))

(close-output-port out-port)

(printf "3. 構造化 CSV データ [~a] の生成・保存が完了しました！\n" output-csv-path)
(printf "\n--- 生成された CSV の中身 ---\n")
(display (file->string output-csv-path))
(printf "=========================================\n")
