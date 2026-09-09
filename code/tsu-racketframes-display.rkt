#lang racket

;; =============================================================================
;; 津ボートレース半年分 JSON → RacketFrames 風データフレーム整形・表示
;; data/raw/tsu/*.json を読み、行指向テーブルに整形して端末へ表示する
;; （本書サンプルと同様、RacketFrames 互換の簡易実装を同梱）
;; =============================================================================

(require json
         racket/string
         racket/list
         racket/file
         racket/path)

(printf "=========================================\n")
(printf " 津レース半年分 × RacketFrames 風 整形表示\n")
(printf "=========================================\n\n")

;; ---------- RacketFrames 互換の簡易データフレーム ----------
;; df = (list headers rows)  / rows = list of hash (string keys)

(define (df-from-rows headers rows)
  (list headers rows))

(define (df-headers df) (first df))
(define (df-rows df) (second df))

(define (df-summary df)
  (define headers (df-headers df))
  (define rows (df-rows df))
  (printf "列名一覧: ~a\n" headers)
  (printf "総行数: ~a 行\n" (length rows)))

(define (df-show df [n 10])
  (define headers (df-headers df))
  (define rows (df-rows df))
  (printf "~a\n" (string-join headers "\t"))
  (printf "~a\n" (make-string 72 #\-))
  (for ([r (take rows (min n (length rows)))])
    (printf "~a\n"
            (string-join
             (for/list ([h headers])
               (format "~a" (hash-ref r h "")))
             "\t"))))

(define (df-filter df pred)
  (df-from-rows (df-headers df) (filter pred (df-rows df))))

(define (df-count df)
  (length (df-rows df)))

(define (df-groupby-count df group-col)
  (define groups (make-hash))
  (for ([r (df-rows df)])
    (define k (hash-ref r group-col))
    (hash-update! groups k add1 0))
  (sort (hash->list groups)
        (lambda (a b)
          (define ka (car a))
          (define kb (car b))
          (cond
            [(and (number? ka) (number? kb)) (< ka kb)]
            [else (string<? (format "~a" ka) (format "~a" kb))]))))

(define (df-win-rate-by df group-col)
  ;; place == 1 の割合
  (define totals (make-hash))
  (define wins (make-hash))
  (for ([r (df-rows df)])
    (define k (hash-ref r group-col))
    (hash-update! totals k add1 0)
    (when (equal? (hash-ref r "place" #f) 1)
      (hash-update! wins k add1 0)))
  (for/list ([k (sort (hash-keys totals)
                      (lambda (a b)
                        (if (and (number? a) (number? b)) (< a b)
                            (string<? (format "~a" a) (format "~a" b)))))])
    (define t (hash-ref totals k))
    (define w (hash-ref wins k 0))
    (list k t w (if (zero? t) 0.0 (/ w t)))))

(define (df-take-recent-races df n-races)
  (define rows (df-rows df))
  (define race-groups (make-hash))
  (for ([r rows])
    (define key (format "~a-~a-~a"
                        (hash-ref r "date" "")
                        (hash-ref r "stadium_num" 0)
                        (hash-ref r "race_num" 0)))
    (hash-update! race-groups key (lambda (lst) (cons r lst)) '()))
  (define sorted-keys (sort (hash-keys race-groups) string>?))
  (define target-keys (take sorted-keys (min n-races (length sorted-keys))))
  (df-from-rows
   (df-headers df)
   (apply append (map (lambda (k) (reverse (hash-ref race-groups k))) target-keys))))

(define (df-write-csv df path)
  (define headers (df-headers df))
  (define rows (df-rows df))
  (call-with-output-file path
    #:exists 'replace
    (lambda (out)
      (displayln (string-join headers ",") out)
      (for ([r rows])
        (displayln
         (string-join
          (for/list ([h headers])
            (define v (hash-ref r h ""))
            (cond
              [(string? v)
               (if (regexp-match? #rx"[,\"\n]" v)
                   (string-append "\"" (string-replace v "\"" "\"\"") "\"")
                   v)]
              [else (format "~a" v)]))
          ",")
         out))))
  path)

;; ---------- 津 JSON 読み込み ----------

(define tsu-dir "data/raw/tsu")

(define (tsu-json-files)
  (cond
    [(not (directory-exists? tsu-dir))
     '()]
    [else
     (define files
       (filter
        (lambda (p)
          (define name (path->string (file-name-from-path p)))
          (and (string-suffix? name ".json")
               (not (string-prefix? name "_"))))
        (directory-list tsu-dir #:build? #t)))
     (sort files string<? #:key path->string)]))

(define headers
  '("date" "stadium_num" "venue" "race_num" "boat_num" "course_num"
    "racer_id" "racer_name" "place" "start_timing"
    "wind_speed" "wave_height" "technique_number"))

(define (clean v default)
  (if (or (eq? v 'null) (eq? v #f)) default v))

(define (parse-tsu-file path)
  (define data (call-with-input-file path read-json))
  (define venue (clean (hash-ref data 'venue #f) "tsu"))
  (define stadium (clean (hash-ref data 'stadium_number #f) 9))
  (define day (clean (hash-ref data 'date #f) ""))
  (define races (clean (hash-ref data 'races #f) '()))
  (define rows '())
  (when (list? races)
    (for ([race races])
      (when (hash? race)
        (define race-num (clean (hash-ref race 'number #f) 0))
        (define wind (clean (hash-ref race 'wind_speed #f) ""))
        (define wave (clean (hash-ref race 'wave_height #f) ""))
        (define tech (clean (hash-ref race 'technique_number #f) ""))
        (define boats (clean (hash-ref race 'boats #f) '()))
        (when (list? boats)
          (for ([b boats])
            (when (hash? b)
              (set! rows
                    (cons
                     (make-hash
                      (list
                       (cons "date" (clean (hash-ref race 'date #f) day))
                       (cons "stadium_num" (clean (hash-ref race 'stadium_number #f) stadium))
                       (cons "venue" venue)
                       (cons "race_num" race-num)
                       (cons "boat_num" (clean (hash-ref b 'racer_boat_number #f) 0))
                       (cons "course_num" (clean (hash-ref b 'racer_course_number #f) 0))
                       (cons "racer_id" (clean (hash-ref b 'racer_number #f) 0))
                       (cons "racer_name" (clean (hash-ref b 'racer_name #f) ""))
                       (cons "place" (clean (hash-ref b 'racer_place_number #f) 0))
                       (cons "start_timing" (clean (hash-ref b 'racer_start_timing #f) ""))
                       (cons "wind_speed" wind)
                       (cons "wave_height" wave)
                       (cons "technique_number" tech)))
                     rows))))))))
  (reverse rows))

(define files (tsu-json-files))
(printf "1. 読込ディレクトリ: ~a\n" tsu-dir)
(printf "2. 対象ファイル数: ~a\n\n" (length files))

(when (null? files)
  (error 'tsu-racketframes-display "data/raw/tsu に日付 JSON がありません"))

(define all-rows
  (apply append
         (for/list ([f files])
           (parse-tsu-file f))))

;; 日付・レース・枠の順で安定ソート
(define sorted-rows
  (sort all-rows
        (lambda (a b)
          (define ka (format "~a-~a-~a"
                             (hash-ref a "date")
                             (~a (hash-ref a "race_num") #:width 2 #:align 'right #:pad-string "0")
                             (hash-ref a "boat_num")))
          (define kb (format "~a-~a-~a"
                             (hash-ref b "date")
                             (~a (hash-ref b "race_num") #:width 2 #:align 'right #:pad-string "0")
                             (hash-ref b "boat_num")))
          (string<? ka kb))))

(define df (df-from-rows headers sorted-rows))

(printf "3. RacketFrames 風データフレーム構築完了\n")
(printf "--- 概要 (df-summary) ---\n")
(df-summary df)

(printf "\n--- 先頭 12 行 (df-show) ---\n")
(df-show df 12)

(define race-keys
  (remove-duplicates
   (for/list ([r (df-rows df)])
     (format "~a-R~a" (hash-ref r "date") (hash-ref r "race_num")))))
(printf "\n4. ユニークレース数: ~a\n" (length race-keys))
(printf "   開催日数: ~a\n"
        (length (remove-duplicates (map (lambda (r) (hash-ref r "date")) (df-rows df)))))

(printf "\n--- 枠番別 出走数 / 1着数 / 勝率 (df-groupby 風) ---\n")
(printf "枠\t出走\t1着\t勝率\n")
(for ([row (df-win-rate-by df "boat_num")])
  (printf "~a\t~a\t~a\t~a%\n"
          (first row) (second row) (third row)
          (real->decimal-string (* 100.0 (fourth row)) 1)))

(printf "\n--- 直近 3 レースだけ切り出し (df-take-recent-races) ---\n")
(define recent (df-take-recent-races df 3))
(df-show recent 18)

(define out-csv "data/parsed_tsu_races.csv")
(df-write-csv df out-csv)
(printf "\n5. 整形 CSV を書き出しました: ~a\n" out-csv)

(define report-path "output/tsu-racketframes-report.txt")
(make-directory* "output")
(call-with-output-file report-path
  #:exists 'replace
  (lambda (out)
    (parameterize ([current-output-port out])
      (printf "津レース半年分 RacketFrames 風レポート\n")
      (printf "生成: tsu-racketframes-display.rkt\n\n")
      (df-summary df)
      (printf "\nユニークレース数: ~a\n" (length race-keys))
      (printf "\n枠番別勝率:\n")
      (for ([row (df-win-rate-by df "boat_num")])
        (printf "  ~a号艇: 出走~a / 1着~a / ~a%\n"
                (first row) (second row) (third row)
                (real->decimal-string (* 100.0 (fourth row)) 1))))))
(printf "6. レポート保存: ~a\n" report-path)
(printf "=========================================\n")
