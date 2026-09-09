#lang racket

;; =============================================================================
;; 会場別レース結果 JSON → 公式 RacketFrames で整形・表示
;; 対応: data/raw/<venue>/YYYY-MM-DD.json（津・蒲郡・常滑・びわこ、最大約3年分）
;; 依存: raco pkg install --user --auto RacketFrames
;;   require はコレクション名 racketframes（カタログ名 RacketFrames）
;; 実行例:
;;   racket code/venue-racketframes-display.rkt tsu
;;   racket code/venue-racketframes-display.rkt gamagori
;;   racket code/venue-racketframes-display.rkt tokoname
;;   racket code/venue-racketframes-display.rkt biwako
;;   BOATRACE_DATA_ROOT=/path/to/root racket code/venue-racketframes-display.rkt tsu
;;   mise run show:tsu / show:gamagori / show:tokoname / show:biwako
;; =============================================================================

(require racketframes
         json
         racket/string
         racket/list
         racket/file
         racket/path
         racket/format
         racket/cmdline
         "boatrace-table-format.rkt")

(define venue-presets
  (hash "tsu" (hash 'label "津" 'dir "data/raw/tsu" 'stadium 9 'default-venue "tsu")
        "gamagori" (hash 'label "蒲郡" 'dir "data/raw/gamagori" 'stadium 7 'default-venue "gamagori")
        "tokoname" (hash 'label "常滑" 'dir "data/raw/tokoname" 'stadium 8 'default-venue "tokoname")
        "biwako" (hash 'label "びわこ" 'dir "data/raw/biwako" 'stadium 11 'default-venue "biwako")))

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

;; 会場データ期間の選手別勝率 Top20（出走10以上・結果確定行のみ）
(define (racer-winrate-rows rows #:min-starts [min-starts 10])
  (define by-id (make-hash))
  (for ([r rows])
    (define place (hash-ref r 'place 0))
    (when (and (exact-integer? place) (>= place 1))
      (define id (hash-ref r 'racer_id 0))
      (define name (hash-ref r 'racer_name ""))
      (define cur (hash-ref by-id id #f))
      (cond
        [(not cur)
         (hash-set! by-id id
                    (hash 'racer_number id
                          'racer_name name
                          'starts 1
                          'wins (if (= place 1) 1 0)
                          'top2 (if (<= place 2) 1 0)))]
        [else
         (hash-set! by-id id
                    (hash-set*
                     cur
                     'racer_name (if (non-empty-string? name) name (hash-ref cur 'racer_name ""))
                     'starts (add1 (hash-ref cur 'starts))
                     'wins (+ (hash-ref cur 'wins) (if (= place 1) 1 0))
                     'top2 (+ (hash-ref cur 'top2) (if (<= place 2) 1 0))))])))
  (define ranked
    (for/list ([(id h) (in-hash by-id)]
               #:when (>= (hash-ref h 'starts) min-starts))
      (define starts (hash-ref h 'starts))
      (define wins (hash-ref h 'wins))
      (define top2 (hash-ref h 'top2))
      (hash-set* h
                 'win_rate (exact->inexact (/ wins starts))
                 'top2_rate (exact->inexact (/ top2 starts)))))
  (sort ranked (λ (a b) (> (hash-ref a 'win_rate) (hash-ref b 'win_rate)))))

(define venue-top-n 20)
(define venue-ranked (racer-winrate-rows sorted-rows #:min-starts 10))
(define period-label
  (let ([days (remove-duplicates (map (λ (r) (hash-ref r 'race_date)) sorted-rows))])
    (if (null? days)
        "期間なし"
        (let ([ds (sort days string<?)])
          (format "~a〜~a" (first ds) (last ds))))))
(void
 (print-winrate-top-table
  venue-ranked venue-top-n
  #:caption (format "~a 勝率 Top~a（~a / 出走10以上 / 候補~a人）"
                    venue-label venue-top-n period-label (length venue-ranked))))

;; ---------------------------------------------------------------------------
;; ボート本体・モーター勝率 Top10
;; 結果JSONには番号が無いため、出走表 programs/v3 を date+stadium+R+枠 で結合
;; 期待パス: data/programs/YYYY-MM-DD.json（全国1日分）
;; ---------------------------------------------------------------------------
(define programs-dir
  (path->string (build-path data-root "data/programs")))

(define (program-assign-key date stadium race-num boat-num)
  (format "~a|~a|~a|~a" date stadium race-num boat-num))

(define (load-program-assignments dates stadium)
  (define assign (make-hash))
  (define loaded 0)
  (define missing 0)
  (for ([d dates])
    (define path (build-path programs-dir (string-append d ".json")))
    (cond
      [(not (file-exists? path))
       (set! missing (add1 missing))]
      [else
       (define data (call-with-input-file path read-json))
       (define programs (clean (hash-ref data 'programs #f) '()))
       (when (list? programs)
         (set! loaded (add1 loaded))
         (for ([p programs]
               #:when (and (hash? p)
                           (= (as-int (clean (hash-ref p 'stadium_number #f) -1) -1)
                              stadium)))
           (define race-num (as-int (clean (hash-ref p 'number #f) 0) 0))
           (define day (as-string (clean (hash-ref p 'date #f) d)))
           (define boats (clean (hash-ref p 'boats #f) '()))
           (when (list? boats)
             (for ([b boats] #:when (hash? b))
               (define boat-num (as-int (clean (hash-ref b 'racer_boat_number #f) 0) 0))
               (define hull (as-int (clean (hash-ref b 'racer_assigned_boat_number #f) 0) 0))
               (define motor (as-int (clean (hash-ref b 'racer_assigned_motor_number #f) 0) 0))
               (when (and (> boat-num 0) (or (> hull 0) (> motor 0)))
                 (hash-set! assign
                            (program-assign-key day stadium race-num boat-num)
                            (hash 'hull hull 'motor motor)))))))]))
  (values assign loaded missing))

(define (equipment-winrate-rows rows assign field #:min-starts [min-starts 10])
  (define by-num (make-hash))
  (for ([r rows])
    (define place (hash-ref r 'place 0))
    (when (and (exact-integer? place) (>= place 1))
      (define key (program-assign-key (hash-ref r 'race_date)
                                      (hash-ref r 'stadium_num)
                                      (hash-ref r 'race_num)
                                      (hash-ref r 'boat_num)))
      (define a (hash-ref assign key #f))
      (when a
        (define num (hash-ref a field 0))
        (when (and (exact-integer? num) (> num 0))
          (define cur (hash-ref by-num num #f))
          (cond
            [(not cur)
             (hash-set! by-num num
                        (hash 'number num
                              'starts 1
                              'wins (if (= place 1) 1 0)
                              'top2 (if (<= place 2) 1 0)))]
            [else
             (hash-set! by-num num
                        (hash-set* cur
                                   'starts (add1 (hash-ref cur 'starts))
                                   'wins (+ (hash-ref cur 'wins) (if (= place 1) 1 0))
                                   'top2 (+ (hash-ref cur 'top2) (if (<= place 2) 1 0))))])))))
  (define ranked
    (for/list ([(num h) (in-hash by-num)]
               #:when (>= (hash-ref h 'starts) min-starts))
      (define starts (hash-ref h 'starts))
      (hash-set* h
                 'win_rate (exact->inexact (/ (hash-ref h 'wins) starts))
                 'top2_rate (exact->inexact (/ (hash-ref h 'top2) starts)))))
  (sort ranked (λ (a b) (> (hash-ref a 'win_rate) (hash-ref b 'win_rate)))))

(define venue-day-keys
  (remove-duplicates (map (λ (r) (hash-ref r 'race_date)) sorted-rows)))

(define-values (program-assign programs-loaded programs-missing)
  (load-program-assignments venue-day-keys default-stadium))

(printf "\n出走表(programs)結合: 読込~a日 / 未取得~a日 / 割当キー~a\n"
        programs-loaded programs-missing (hash-count program-assign))

(define equip-top-n 10)
(define hull-ranked (equipment-winrate-rows sorted-rows program-assign 'hull #:min-starts 10))
(define motor-ranked (equipment-winrate-rows sorted-rows program-assign 'motor #:min-starts 10))

(void
 (print-equipment-top-table
  hull-ranked equip-top-n
  #:id-label "ボート"
  #:caption (format "~a ボート本体 勝率 Top~a（~a / 出走10以上 / 候補~a / programs結合）"
                    venue-label equip-top-n period-label (length hull-ranked))))

(void
 (print-equipment-top-table
  motor-ranked equip-top-n
  #:id-label "モーター"
  #:caption (format "~a モーター 勝率 Top~a（~a / 出走10以上 / 候補~a / programs結合）"
                    venue-label equip-top-n period-label (length motor-ranked))))

(when (> programs-missing 0)
  (printf "※ data/programs/YYYY-MM-DD.json が揃うほど集計が正確になります（Boatrace OpenAPI programs/v3）\n"))

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
  (printf "~a\t~a\t~a\t~a\n"
          (first row) (second row) (third row)
          (fmt-rate-pct (fourth row))))

;; 結果確定レース: そのレースの全艇に氏名があり、着順が1以上
(define (race-key r)
  (format "~a-~a" (hash-ref r 'race_date) (hash-ref r 'race_num)))

(define (race-results-finalized? race-rows)
  (and (pair? race-rows)
       (andmap (λ (r)
                 (define name (hash-ref r 'racer_name ""))
                 (define place (hash-ref r 'place 0))
                 (and (string? name)
                      (non-empty-string? name)
                      (exact-integer? place)
                      (>= place 1)))
               race-rows)))

(define rows-by-race (make-hash))
(for ([r sorted-rows])
  (hash-update! rows-by-race (race-key r) (λ (lst) (cons r lst)) '()))

(define finalized-race-keys
  (filter (λ (k) (race-results-finalized? (reverse (hash-ref rows-by-race k))))
          (hash-keys rows-by-race)))

(define recent-keys
  (take (sort finalized-race-keys string>?)
        (min 3 (length finalized-race-keys))))

(define recent-rows
  (apply append
         (for/list ([k recent-keys])
           (define top3
             (filter (λ (r)
                       (define pl (hash-ref r 'place 0))
                       (and (exact-integer? pl) (<= 1 pl 3)))
                     (reverse (hash-ref rows-by-race k))))
           (sort top3 (λ (a b) (< (hash-ref a 'place) (hash-ref b 'place)))))))

(printf "\n--- 直近 3 レース（結果確定・各レース1〜3着） ---\n")
(printf "結果未確定レースは除外。各レースは1着・2着・3着の3名のみ表示\n")
(printf "候補キー数: 全~a / 確定~a / 表示~a\n"
        (length (hash-keys rows-by-race))
        (length finalized-race-keys)
        (length recent-keys))

(cond
  [(null? recent-rows)
   (printf "（結果確定レースがありません）\n")]
  [else
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
   (printf "DataFrame 行数: ~a\n" (data-frame-row-count recent-df))
   (print-recent-races-table recent-rows)])

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
      (fprintf out "  ~a号艇: 出走~a / 1着~a / ~a\n"
               (first row) (second row) (third row)
               (fmt-rate-pct (fourth row))))))
(printf "6. レポート保存: ~a\n" report-path)
(printf "=========================================\n")
