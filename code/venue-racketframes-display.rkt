#lang racket

;; =============================================================================
;; 会場別レース結果 JSON → 公式 RacketFrames で整形・表示
;; 対応: data/raw/<venue>/YYYY-MM-DD.json（津・蒲郡など、最大約3年分）
;; 依存: raco pkg install --user --auto RacketFrames
;;   require はコレクション名 racketframes（カタログ名 RacketFrames）
;; 実行例:
;;   racket code/venue-racketframes-display.rkt tsu
;;   racket code/venue-racketframes-display.rkt gamagori
;;   BOATRACE_DATA_ROOT=/path/to/root racket code/venue-racketframes-display.rkt tsu
;;   mise run show:tsu / mise run show:gamagori
;; =============================================================================

(require racketframes
         json
         racket/string
         racket/list
         racket/file
         racket/path
         racket/format
         racket/cmdline)

(define venue-presets
  (hash "tsu" (hash 'label "津" 'dir "data/raw/tsu" 'stadium 9 'default-venue "tsu")
        "gamagori" (hash 'label "蒲郡" 'dir "data/raw/gamagori" 'stadium 7 'default-venue "gamagori")))

(define data-root
  (or (getenv "BOATRACE_DATA_ROOT") "."))

(define venue-key
  (command-line
   #:program "venue-racketframes-display"
   #:args ([venue "tsu"]) venue))

(unless (hash-has-key? venue-presets venue-key)
  (error 'venue-racketframes-display
         "未知の会場です: ~a（対応: ~a）"
         venue-key
         (string-join (hash-keys venue-presets) ", ")))

(define preset (hash-ref venue-presets venue-key))
(define venue-label (hash-ref preset 'label))
(define default-stadium (hash-ref preset 'stadium))
(define default-venue-name (hash-ref preset 'default-venue))
(define venue-dir
  (path->string (build-path data-root (hash-ref preset 'dir))))

(printf "=========================================\n")
(printf " ~aレース過去結果 × 公式 RacketFrames 表示\n" venue-label)
(printf " （日次 JSON・最大約3年対応）\n")
(printf "=========================================\n\n")

(define (venue-json-files)
  (cond
    [(not (directory-exists? venue-dir)) '()]
    [else
     (define files
       (filter
        (lambda (p)
          (define name (path->string (file-name-from-path p)))
          (and (string-suffix? name ".json")
               (not (string-prefix? name "_"))))
        (directory-list venue-dir #:build? #t)))
     (sort files string<? #:key path->string)]))

(define (clean v default)
  (if (or (eq? v 'null) (eq? v #f)) default v))

(define (as-string v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [(number? v) (number->string v)]
    [else (~a v)]))

(define (as-int v default)
  (cond
    [(exact-integer? v) v]
    [(and (number? v) (exact? (inexact->exact (round v))))
     (inexact->exact (round v))]
    [(string? v)
     (define n (string->number v))
     (if (and n (exact-integer? n)) n default)]
    [else default]))

(define (parse-venue-file path)
  (define data (call-with-input-file path read-json))
  (define venue (as-string (clean (hash-ref data 'venue #f) default-venue-name)))
  (define stadium (as-int (clean (hash-ref data 'stadium_number #f) default-stadium) default-stadium))
  (define day (as-string (clean (hash-ref data 'date #f) "")))
  (define races (clean (hash-ref data 'races #f) '()))
  (define rows '())
  (when (list? races)
    (for ([race races])
      (when (hash? race)
        (define race-num (as-int (clean (hash-ref race 'number #f) 0) 0))
        (define wind (as-string (clean (hash-ref race 'wind_speed #f) "")))
        (define wave (as-string (clean (hash-ref race 'wave_height #f) "")))
        (define tech (as-string (clean (hash-ref race 'technique_number #f) "")))
        (define boats (clean (hash-ref race 'boats #f) '()))
        (when (list? boats)
          (for ([b boats])
            (when (hash? b)
              (set! rows
                    (cons
                     (hash
                      'race_date (as-string (clean (hash-ref race 'date #f) day))
                      'stadium_num (as-int (clean (hash-ref race 'stadium_number #f) stadium) stadium)
                      'venue venue
                      'race_num race-num
                      'boat_num (as-int (clean (hash-ref b 'racer_boat_number #f) 0) 0)
                      'course_num (as-int (clean (hash-ref b 'racer_course_number #f) 0) 0)
                      'racer_id (as-int (clean (hash-ref b 'racer_number #f) 0) 0)
                      'racer_name (as-string (clean (hash-ref b 'racer_name #f) ""))
                      'place (as-int (clean (hash-ref b 'racer_place_number #f) 0) 0)
                      'start_timing (as-string (clean (hash-ref b 'racer_start_timing #f) ""))
                      'wind_speed wind
                      'wave_height wave
                      'technique_number tech)
                     rows))))))))
  (reverse rows))

(define files (venue-json-files))
(printf "1. 読込ディレクトリ: ~a\n" venue-dir)
(printf "2. 対象ファイル数: ~a\n\n" (length files))

(when (null? files)
  (error 'venue-racketframes-display
         "~a に日付 JSON がありません（BOATRACE_DATA_ROOT=~a）"
         venue-dir data-root))

(define all-rows
  (apply append
         (for/list ([f files])
           (parse-venue-file f))))

(define sorted-rows
  (sort all-rows
        (lambda (a b)
          (define ka (format "~a-~a-~a"
                             (hash-ref a 'race_date)
                             (~a (hash-ref a 'race_num) #:width 2 #:align 'right #:pad-string "0")
                             (hash-ref a 'boat_num)))
          (define kb (format "~a-~a-~a"
                             (hash-ref b 'race_date)
                             (~a (hash-ref b 'race_num) #:width 2 #:align 'right #:pad-string "0")
                             (hash-ref b 'boat_num)))
          (string<? ka kb))))

(define n (length sorted-rows))

(define col-race_date
  (new-GenSeries (list->vector (map (λ (r) (hash-ref r 'race_date)) sorted-rows))))
(define col-venue
  (new-GenSeries (list->vector (map (λ (r) (hash-ref r 'venue)) sorted-rows))))
(define col-racer_name
  (new-GenSeries (list->vector (map (λ (r) (hash-ref r 'racer_name)) sorted-rows))))
(define col-start_timing
  (new-GenSeries (list->vector (map (λ (r) (hash-ref r 'start_timing)) sorted-rows))))
(define col-wind_speed
  (new-GenSeries (list->vector (map (λ (r) (hash-ref r 'wind_speed)) sorted-rows))))
(define col-wave_height
  (new-GenSeries (list->vector (map (λ (r) (hash-ref r 'wave_height)) sorted-rows))))
(define col-technique_number
  (new-GenSeries (list->vector (map (λ (r) (hash-ref r 'technique_number)) sorted-rows))))

(define col-stadium_num
  (new-ISeries (map (λ (r) (hash-ref r 'stadium_num)) sorted-rows)))
(define col-race_num
  (new-ISeries (map (λ (r) (hash-ref r 'race_num)) sorted-rows)))
(define col-boat_num
  (new-ISeries (map (λ (r) (hash-ref r 'boat_num)) sorted-rows)))
(define col-course_num
  (new-ISeries (map (λ (r) (hash-ref r 'course_num)) sorted-rows)))
(define col-racer_id
  (new-ISeries (map (λ (r) (hash-ref r 'racer_id)) sorted-rows)))
(define col-place
  (new-ISeries (map (λ (r) (hash-ref r 'place)) sorted-rows)))

(define df
  (new-data-frame
   (list (cons 'race_date col-race_date)
         (cons 'stadium_num col-stadium_num)
         (cons 'venue col-venue)
         (cons 'race_num col-race_num)
         (cons 'boat_num col-boat_num)
         (cons 'course_num col-course_num)
         (cons 'racer_id col-racer_id)
         (cons 'racer_name col-racer_name)
         (cons 'place col-place)
         (cons 'start_timing col-start_timing)
         (cons 'wind_speed col-wind_speed)
         (cons 'wave_height col-wave_height)
         (cons 'technique_number col-technique_number))))

(printf "3. 公式 RacketFrames DataFrame 構築完了（行数 ~a）\n" n)
(printf "--- 概要 (show-data-frame-description) ---\n")
(show-data-frame-description (data-frame-description df))
(printf "行数(data-frame-row-count): ~a\n" (data-frame-row-count df))
(printf "列数(data-frame-column-count): ~a\n" (data-frame-column-count df))

(printf "\n--- 先頭行 (data-frame-head) ---\n")
(data-frame-head df)

(define race-keys
  (remove-duplicates
   (for/list ([r sorted-rows])
     (format "~a-R~a" (hash-ref r 'race_date) (hash-ref r 'race_num)))))
(define day-keys
  (remove-duplicates
   (map (λ (r) (hash-ref r 'race_date)) sorted-rows)))
(printf "\n4. ユニークレース数: ~a\n" (length race-keys))
(printf "   開催日数: ~a\n" (length day-keys))
(when (pair? day-keys)
  (define days-sorted (sort day-keys string<?))
  (printf "   期間: ~a 〜 ~a\n" (first days-sorted) (last days-sorted)))

(define (win-rate-by-boat rows)
  (define totals (make-hash))
  (define wins (make-hash))
  (for ([r rows])
    (define k (hash-ref r 'boat_num))
    (hash-update! totals k add1 0)
    (when (= (hash-ref r 'place) 1)
      (hash-update! wins k add1 0)))
  (for/list ([k (sort (hash-keys totals) <)])
    (define t (hash-ref totals k))
    (define w (hash-ref wins k 0))
    (list k t w (if (zero? t) 0.0 (exact->inexact (/ w t))))))

(printf "\n--- 枠番別 出走数 / 1着数 / 勝率 ---\n")
(printf "枠\t出走\t1着\t勝率\n")
(define boat-stats (win-rate-by-boat sorted-rows))
(for ([row boat-stats])
  (printf "~a\t~a\t~a\t~a%\n"
          (first row) (second row) (third row)
          (real->decimal-string (* 100.0 (fourth row)) 1)))

(define race-group-keys
  (remove-duplicates
   (map (λ (r) (format "~a-~a" (hash-ref r 'race_date) (hash-ref r 'race_num)))
        sorted-rows)))
(define recent-keys
  (take (sort race-group-keys string>?) (min 3 (length race-group-keys))))
(define recent-rows
  (filter (λ (r)
            (member (format "~a-~a" (hash-ref r 'race_date) (hash-ref r 'race_num))
                    recent-keys))
          sorted-rows))

(define recent-df
  (new-data-frame
   (list
    (cons 'race_date
          (new-GenSeries (list->vector (map (λ (r) (hash-ref r 'race_date)) recent-rows))))
    (cons 'race_num
          (new-ISeries (map (λ (r) (hash-ref r 'race_num)) recent-rows)))
    (cons 'boat_num
          (new-ISeries (map (λ (r) (hash-ref r 'boat_num)) recent-rows)))
    (cons 'racer_name
          (new-GenSeries (list->vector (map (λ (r) (hash-ref r 'racer_name)) recent-rows))))
    (cons 'place
          (new-ISeries (map (λ (r) (hash-ref r 'place)) recent-rows))))))

(printf "\n--- 直近 3 レース (別 DataFrame) ---\n")
(show-data-frame-description (data-frame-description recent-df))
(data-frame-head recent-df)

(define out-csv (path->string (build-path data-root (format "data/parsed_~a_races.csv" venue-key))))
(make-directory* (path-only out-csv))
(data-frame-write-csv df out-csv)
(printf "\n5. 整形 CSV を書き出しました: ~a\n" out-csv)

(define report-path (path->string (build-path data-root (format "output/~a-racketframes-report.txt" venue-key))))
(make-directory* (path-only report-path))
(call-with-output-file report-path
  #:exists 'replace
  (lambda (out)
    (fprintf out "~aレース過去結果 公式 RacketFrames レポート\n" venue-label)
    (fprintf out "生成: venue-racketframes-display.rkt (~a)\n" venue-key)
    (fprintf out "require: racketframes (package RacketFrames)\n")
    (fprintf out "data_root: ~a\n\n" data-root)
    (fprintf out "行数: ~a\n列数: ~a\n" (data-frame-row-count df) (data-frame-column-count df))
    (fprintf out "ユニークレース数: ~a\n開催日数: ~a\n" (length race-keys) (length day-keys))
    (when (pair? day-keys)
      (define days-sorted (sort day-keys string<?))
      (fprintf out "期間: ~a 〜 ~a\n\n" (first days-sorted) (last days-sorted)))
    (fprintf out "枠番別勝率:\n")
    (for ([row boat-stats])
      (fprintf out "  ~a号艇: 出走~a / 1着~a / ~a%\n"
               (first row) (second row) (third row)
               (real->decimal-string (* 100.0 (fourth row)) 1)))))
(printf "6. レポート保存: ~a\n" report-path)
(printf "=========================================\n")
