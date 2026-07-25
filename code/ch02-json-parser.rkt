#lang racket

;; =============================================================================
;; 第2章【本線パイプライン】：boatraceopenapi (JSON) データのパース ＆ CSV 変換
;; 電子書籍『ボートレース統計入門』サンプルコード
;; =============================================================================

(require json)

(printf "=========================================\n")
(printf " 第2章【本線】：boatraceopenapi JSON パース  \n")
(printf "=========================================\n\n")

;; 1. JSON ファイルのパス指定（ローカルファイルまたはサンプル fallback）
(define json-path "data/raw/today.json")

(define (clean-value v default-val)
  (if (or (eq? v 'null) (eq? v #f) (void? v))
      default-val
      v))

(define (get-json-data)
  (if (file-exists? json-path)
      (begin
        (printf "1. ローカルの JSON データ [~a] を読み込みます...\n" json-path)
        (call-with-input-file json-path read-json))
      (begin
        (printf "1. [~a] が見つからないため、サンプル JSON を生成してパースします...\n" json-path)
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
          "}")))))

(define raw-data (get-json-data))

(printf "2. Racket 標準ライブラリ (require json) による JSON 構造解析一括完了！\n\n")

;; 3. JSON 構造から必要なデータ項目（艇番・選手名・勝率・モーター率など）を抽出
(define parsed-rows '())

;; programs.stadiums を取り出し
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
                  (set! parsed-rows
                        (cons (list stadium-num race-num boat-num racer-id name rank win-rate motor-rate)
                              parsed-rows)))))))))))

(printf "3. 抽出データ件数: ~a 件\n\n" (length parsed-rows))

;; 4. CSV ファイルへ書き出し
(define output-csv-path "data/parsed_races.csv")
(define out-port (open-output-file output-csv-path #:exists 'replace))

(displayln "stadium_num,race_num,boat_num,racer_id,racer_name,rank,win_rate,motor_rate" out-port)

(for ([row (reverse parsed-rows)])
  (displayln (string-join (map (lambda (v) (format "~a" v)) row) ",") out-port))

(close-output-port out-port)

(printf "4. 本線パイプライン: 構造化 CSV データ [~a] の生成完了！\n" output-csv-path)
(printf "\n--- 生成された CSV データサンプル（先頭 10 行）---\n")
(define lines (file->lines output-csv-path))
(for ([line (take lines (min 10 (length lines)))])
  (displayln line))
(printf "=========================================\n")
