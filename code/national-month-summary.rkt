#lang racket

;; =============================================================================
;; 全国月次集計 JSON のサマリ表示
;; 期待パス:
;;   data/national/by_month/YYYY-MM.json
;;   data/national/by_racer_monthly/YYYY-MM.json （任意）
;; 実行: racket code/national-month-summary.rkt
;;       racket code/national-month-summary.rkt 2026-08
;;       mise run show:national-month
;; =============================================================================

(require json
         racket/string
         racket/list
         racket/file
         racket/path
         racket/format
         racket/cmdline)

(define data-root (or (getenv "BOATRACE_DATA_ROOT") "."))
(define by-month-dir (path->string (build-path data-root "data/national/by_month")))
(define by-racer-dir (path->string (build-path data-root "data/national/by_racer_monthly")))

(define month-arg
  (command-line
   #:program "national-month-summary"
   #:args ([ym ""]) ym))

(define (month-files)
  (cond
    [(not (directory-exists? by-month-dir)) '()]
    [else
     (sort
      (filter
       (λ (p)
         (define name (path->string (file-name-from-path p)))
         (and (string-suffix? name ".json") (not (string-prefix? name "_"))))
       (directory-list by-month-dir #:build? #t))
      string<?
      #:key path->string)]))

(define files (month-files))
(printf "=========================================\n")
(printf " 全国月次集計サマリ\n")
(printf "=========================================\n")
(printf "dir: ~a\n" by-month-dir)

(when (null? files)
  (printf "月次 JSON がありません。\n")
  (printf "想定レイアウト: data/national/by_month/YYYY-MM.json\n")
  (printf "（3年分データは外部配置可。BOATRACE_DATA_ROOT でルート変更）\n")
  (exit 0))

(define chosen
  (cond
    [(non-empty-string? month-arg)
     (define p (build-path by-month-dir (string-append month-arg ".json")))
     (unless (file-exists? p)
       (error 'national-month-summary "指定月のファイルがありません: ~a" p))
     p]
    [else (last files)]))

(define data (call-with-input-file chosen read-json))
(define ym (hash-ref data 'year_month (path->string (path-replace-extension (file-name-from-path chosen) #""))))
(printf "対象月: ~a\n" ym)
(printf "開催日数(days_with_results): ~a\n" (hash-ref data 'days_with_results 'null))
(printf "総レース数(total_races): ~a\n" (hash-ref data 'total_races 'null))
(printf "ユニーク選手数(unique_racers): ~a\n" (hash-ref data 'unique_racers 'null))
(printf "source_note: ~a\n" (hash-ref data 'source_note ""))

(define rbs (hash-ref data 'races_by_stadium #f))
(when (hash? rbs)
  (printf "\n--- 場別レース数 (stadium_number) ---\n")
  (for ([k (sort (hash-keys rbs)
                 (λ (a b)
                   (< (string->number (~a a)) (string->number (~a b)))))])
    (printf "  stadium ~a: ~a\n" k (hash-ref rbs k))))

(define racer-path (build-path by-racer-dir (string-append (~a ym) ".json")))
(when (file-exists? racer-path)
  (define racers (call-with-input-file racer-path read-json))
  (when (hash? racers)
    (define rows
      (for/list ([(k v) (in-hash racers)])
        v))
    (define filtered
      (filter (λ (r) (and (hash? r) (>= (hash-ref r 'starts 0) 10))) rows))
    (define ranked
      (take
       (sort filtered
             (λ (a b)
               (> (hash-ref a 'win_rate 0.0) (hash-ref b 'win_rate 0.0))))
       (min 10 (length filtered))))
    ;; 端末幅を意識した固定桁（ASCII=1・それ以外=2 としてパディング）
    (define (disp-width s)
      (for/sum ([c (in-string (~a s))])
        (if (<= (char->integer c) #x7f) 1 2)))
    (define (pad s width #:right? [right? #f])
      (define str (~a s))
      (define padn (max 0 (- width (disp-width str))))
      (define spaces (make-string padn #\space))
      (if right? (string-append spaces str) (string-append str spaces)))
    (define (fmt-rate x)
      (real->decimal-string (exact->inexact (if (real? x) x 0)) 4))
    (printf "\n--- 勝率 Top10（出走10以上） ---\n")
    (printf "~a ~a ~a ~a ~a ~a\n"
            (pad "選手番号" 8)
            (pad "氏名" 16)
            (pad "出走" 6 #:right? #t)
            (pad "1着" 6 #:right? #t)
            (pad "勝率" 8 #:right? #t)
            (pad "連対率" 8 #:right? #t))
    (for ([r ranked])
      (printf "~a ~a ~a ~a ~a ~a\n"
              (pad (hash-ref r 'racer_number "") 8)
              (pad (hash-ref r 'racer_name "") 16)
              (pad (hash-ref r 'starts 0) 6 #:right? #t)
              (pad (hash-ref r 'wins 0) 6 #:right? #t)
              (pad (fmt-rate (hash-ref r 'win_rate 0)) 8 #:right? #t)
              (pad (fmt-rate (hash-ref r 'top2_rate 0)) 8 #:right? #t)))))

(printf "\n利用可能月ファイル数: ~a\n" (length files))
(printf "=========================================\n")
