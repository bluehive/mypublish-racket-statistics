#lang racket

;; =============================================================================
;; 全国月次集計 JSON のサマリ表示
;; 期待パス:
;;   data/national/by_month/YYYY-MM.json
;;   data/national/by_racer_monthly/YYYY-MM.json （任意）
;; 実行: racket code/national-month-summary.rkt
;;       racket code/national-month-summary.rkt 2026-08
;;       racket code/national-month-summary.rkt 2026-08 -n 30
;;       TOP_N=30 mise run show:national-month
;; 勝率ランキング: デフォルト20人、対話で1〜50人に変更可（TTY時）
;; =============================================================================

(require json
         racket/string
         racket/list
         racket/file
         racket/path
         racket/format
         racket/cmdline
         "boatrace-table-format.rkt")

(define data-root (or (getenv "BOATRACE_DATA_ROOT") "."))
(define by-month-dir (path->string (build-path data-root "data/national/by_month")))
(define by-racer-dir (path->string (build-path data-root "data/national/by_racer_monthly")))

(define default-top 20)
(define max-top 50)
(define min-top 1)

(define (clamp-top n)
  (cond
    [(not (and (number? n) (exact-integer? n))) default-top]
    [(< n min-top) min-top]
    [(> n max-top) max-top]
    [else n]))

(define top-n
  (clamp-top
   (or (let ([e (getenv "TOP_N")])
         (and e (string->number e)))
       default-top)))

(define month-arg "")

(command-line
 #:program "national-month-summary"
 #:once-each
 [("-n" "--top")
  n
  ("勝率ランキング表示人数 1-50（デフォルト20）")
  (set! top-n (clamp-top (string->number n)))]
 #:args ([ym ""]) (set! month-arg ym))

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
    (define ranked-all
      (sort filtered
            (λ (a b)
              (> (hash-ref a 'win_rate 0.0) (hash-ref b 'win_rate 0.0)))))
    (define current-n (print-winrate-top-table ranked-all top-n))
    ;; TTY ならキー操作で 1〜50 人まで変更
    (when (terminal-port? (current-input-port))
      (printf "\n人数変更: 1-~a の数字 / + (10増) / - (10減) / Enter=終了\n" max-top)
      (let loop ([n current-n])
        (printf "[現在 ~a人] > " n)
        (flush-output)
        (define line (read-line))
        (cond
          [(or (eof-object? line) (equal? (string-trim line) ""))
           (void)]
          [else
           (define s (string-trim line))
           (define next
             (cond
               [(equal? s "+") (min max-top (+ n 10))]
               [(equal? s "-") (max min-top (- n 10))]
               [(string->number s)
                => (λ (x)
                     (if (exact-integer? x)
                         (clamp-top x)
                         #f))]
               [else #f]))
           (cond
             [(not next)
              (printf "  1-~a の数字、+、-、Enter のいずれかを入力してください。\n" max-top)
              (loop n)]
             [else
              (print-winrate-top-table ranked-all next)
              (loop next)])])))))

(printf "\n利用可能月ファイル数: ~a\n" (length files))
(printf "=========================================\n")
