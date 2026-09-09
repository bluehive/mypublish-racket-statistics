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
    (printf "\n--- 勝率 Top10（出走10以上） ---\n")
    (printf "選手番号\t氏名\t出走\t1着\t勝率\t連対率\n")
    (for ([r ranked])
      (printf "~a\t~a\t~a\t~a\t~a\t~a\n"
              (hash-ref r 'racer_number "")
              (hash-ref r 'racer_name "")
              (hash-ref r 'starts 0)
              (hash-ref r 'wins 0)
              (hash-ref r 'win_rate 0)
              (hash-ref r 'top2_rate 0)))))

(printf "\n利用可能月ファイル数: ~a\n" (length files))
(printf "=========================================\n")
