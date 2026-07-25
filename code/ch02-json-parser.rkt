#lang racket

;; =============================================================================
;; 第2章【本線パイプライン】：boatraceopenapi (JSON) データのパース ＆ CSV 変換
;; 日付別 JSON ファイル (data/raw/*.json) の全自動スキャン & 蓄積処理対応
;; 電子書籍『ボートレース統計入門』サンプルコード
;; =============================================================================

(require json)

(printf "=========================================\n")
(printf " 第2章【本線】：boatraceopenapi JSON パース  \n")
(printf " (日付別 JSON ファイルの自動スキャン ＆ 蓄積パイプライン) \n")
(printf "=========================================\n\n")

(define (clean-value v default-val)
  (if (or (eq? v 'null) (eq? v #f) (void? v))
      default-val
      v))

(define raw-dir "data/raw")

;; data/raw 配下の全 *.json ファイルを取得
(define (get-target-json-files)
  (if (directory-exists? raw-dir)
      (let ([files (directory-list raw-dir #:build? #t)])
        (filter (lambda (p)
                  (string-suffix? (path->string p) ".json"))
                files))
      '()))

(define target-files (get-target-json-files))

;; 単一の JSON ハッシュ構造からレーサー行リストを抽出する関数
(define (parse-single-json raw-data source-name)
  (define rows '())
  (define stadiums
    (if (hash? raw-data)
        (let ([progs (hash-ref raw-data 'programs #f)])
          (if (hash? progs)
              (hash-ref progs 'stadiums raw-data)
              (hash-ref raw-data 'stadiums raw-data)))
        #f))

  (when (hash? stadiums)
    (for ([(stadium-key stadium-info) (in-hash stadiums)])
      (when (hash? stadium-info)
        (define races (hash-ref stadium-info 'races #f))
        (when (hash? races)
          (for ([(race-key race-info) (in-hash races)])
            (when (hash? race-info)
              (define race-date (clean-value (hash-ref race-info 'date "") ""))
              (define stadium-num (clean-value (hash-ref race-info 'stadium_number #f) stadium-key))
              (define race-num (clean-value (hash-ref race-info 'race_number #f) race-key))
              (define racers (clean-value (hash-ref race-info 'racers #f) #f))
              (when (hash? racers)
                (for ([(boat-key racer-info) (in-hash racers)])
                  (when (hash? racer-info)
                    (define boat-num (clean-value (hash-ref racer-info 'entry_number #f) boat-key))
                    (define name (clean-value (hash-ref racer-info 'name "") ""))
                    (define racer-id (clean-value (hash-ref racer-info 'number "") ""))
                    (define rank (clean-value (hash-ref racer-info 'rank_number_source "") ""))
                    (define win-rate (clean-value (hash-ref racer-info 'national_win_rate 0.0) 0.0))
                    (define motor-rate (clean-value (hash-ref racer-info 'motor_top_2_percent 0.0) 0.0))
                    (set! rows
                          (cons (list race-date stadium-num race-num boat-num racer-id name rank win-rate motor-rate)
                                rows)))))))))))
  rows)

;; 処理メインロジック
(define all-parsed-rows
  (if (null? target-files)
      (begin
        (printf "1. [~a] に JSON ファイルが見つからないため、サンプル JSON を生成してパースします...\n" raw-dir)
        (let ([sample-data
               (string->jsexpr
                (string-append
                 "{\n"
                 "  \"programs\": {\n"
                 "    \"stadiums\": {\n"
                 "      \"23\": {\n"
                 "        \"races\": {\n"
                 "          \"11\": {\n"
                 "            \"date\": \"2026-07-26\",\n"
                 "            \"stadium_number\": 23,\n"
                 "            \"race_number\": 11,\n"
                 "            \"racers\": {\n"
                 "              \"1\": {\"entry_number\": 1, \"name\": \"土屋 智則\", \"number\": 4362, \"rank_number_source\": \"A1\", \"national_win_rate\": 6.70, \"motor_top_2_percent\": 33.67},\n"
                 "              \"2\": {\"entry_number\": 2, \"name\": \"落合 直子\", \"number\": 4289, \"rank_number_source\": \"A2\", \"national_win_rate\": 5.59, \"motor_top_2_percent\": 33.51},\n"
                 "              \"3\": {\"entry_number\": 3, \"name\": \"星 栄爾\",   \"number\": 4216, \"rank_number_source\": \"B1\", \"national_win_rate\": 4.53, \"motor_top_2_percent\": 37.44},\n"
                 "              \"4\": {\"entry_number\": 4, \"name\": \"沢田 昭宏\", \"number\": 4411, \"rank_number_source\": \"A2\", \"national_win_rate\": 5.65, \"motor_top_2_percent\": 23.08},\n"
                 "              \"5\": {\"entry_number\": 5, \"name\": \"吉田 彩乃\", \"number\": 5140, \"rank_number_source\": \"B1\", \"national_win_rate\": 4.77, \"motor_top_2_percent\": 29.71},\n"
                 "              \"6\": {\"entry_number\": 6, \"name\": \"後藤 正宗\", \"number\": 3987, \"rank_number_source\": \"A1\", \"national_win_rate\": 6.18, \"motor_top_2_percent\": 21.51}\n"
                 "            }\n"
                 "          }\n"
                 "        }\n"
                 "      }\n"
                 "    }\n"
                 "  }\n"
                 "}"))])
          (parse-single-json sample-data "sample")))
      (begin
        (printf "1. [~a] 内の JSON ファイル (~a 件) をスキャンして読み込みます:\n" raw-dir (length target-files))
        (let ([acc '()])
          (for ([file target-files])
            (printf "   - パース中: ~a\n" (path->string file))
            (define file-data (call-with-input-file file read-json))
            (define rows (parse-single-json file-data (path->string file)))
            (set! acc (append acc rows)))
          acc))))

(printf "\n2. JSON 構造解析一括完了！\n")
(printf "3. 累積抽出データ件数: ~a 件\n\n" (length all-parsed-rows))

;; CSV ファイルへ書き出し
(define output-csv-path "data/parsed_races.csv")
(define out-port (open-output-file output-csv-path #:exists 'replace))

(displayln "date,stadium_num,race_num,boat_num,racer_id,racer_name,rank,win_rate,motor_rate" out-port)

(for ([row (reverse all-parsed-rows)])
  (displayln (string-join (map (lambda (v) (format "~a" v)) row) ",") out-port))

(close-output-port out-port)

(printf "4. 本線パイプライン: 構造化 CSV データ [~a] の生成完了！\n" output-csv-path)
(printf "\n--- 生成された CSV データサンプル（先頭 10 行）---\n")
(define lines (file->lines output-csv-path))
(for ([line (take lines (min 10 (length lines)))])
  (displayln line))
(printf "=========================================\n")
