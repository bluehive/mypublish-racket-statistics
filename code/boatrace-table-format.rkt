#lang racket

;; =============================================================================
;; 端末向け固定桁テーブル表示（ASCII=1・それ以外=2）
;; 会場表示・全国月次サマリなどから共通利用
;; =============================================================================

(provide disp-width
         pad
         fmt-rate
         fmt-rate-pct
         print-recent-races-table
         print-race-rows-preview
         print-winrate-top-table
         print-equipment-top-table)

(require racket/format
         racket/list)

(define (disp-width s)
  (for/sum ([c (in-string (~a s))])
    (if (<= (char->integer c) #x7f) 1 2)))

(define (pad s width #:right? [right? #f])
  (define str (~a s))
  (define padn (max 0 (- width (disp-width str))))
  (define spaces (make-string padn #\space))
  (if right? (string-append spaces str) (string-append str spaces)))

;; 勝率・連対率: 小数第2位まで（切り捨て）。例 0.8182 -> 0.81
(define (fmt-rate x)
  (define v (exact->inexact (if (real? x) x 0)))
  (define truncated (/ (truncate (* (max 0.0 v) 100.0)) 100.0))
  (real->decimal-string truncated 2))

;; 枠番別など百分率表示用（切り捨て第2位）。例 0.52812 -> 52.81%
(define (fmt-rate-pct x)
  (define v (* (exact->inexact (if (real? x) x 0)) 100.0))
  (define truncated (/ (truncate (* (max 0.0 v) 100.0)) 100.0))
  (string-append (real->decimal-string truncated 2) "%"))

;; 直近レース（日付 / R / 枠 / 選手名 / 着）
(define (print-recent-races-table rows)
  (printf "~a ~a ~a ~a ~a\n"
          (pad "日付" 12)
          (pad "R" 4 #:right? #t)
          (pad "枠" 4 #:right? #t)
          (pad "選手名" 16)
          (pad "着" 4 #:right? #t))
  (for ([r rows])
    (printf "~a ~a ~a ~a ~a\n"
            (pad (hash-ref r 'race_date "") 12)
            (pad (hash-ref r 'race_num "") 4 #:right? #t)
            (pad (hash-ref r 'boat_num "") 4 #:right? #t)
            (pad (hash-ref r 'racer_name "") 16)
            (pad (hash-ref r 'place "") 4 #:right? #t))))

;; 先頭プレビュー（主要列のみ・data-frame-head の代替）
(define (print-race-rows-preview rows #:limit [limit 12])
  (define show (take rows (min limit (length rows))))
  (printf "~a ~a ~a ~a ~a ~a\n"
          (pad "日付" 12)
          (pad "R" 4 #:right? #t)
          (pad "枠" 4 #:right? #t)
          (pad "選手名" 16)
          (pad "着" 4 #:right? #t)
          (pad "ST" 6 #:right? #t))
  (for ([r show])
    (printf "~a ~a ~a ~a ~a ~a\n"
            (pad (hash-ref r 'race_date "") 12)
            (pad (hash-ref r 'race_num "") 4 #:right? #t)
            (pad (hash-ref r 'boat_num "") 4 #:right? #t)
            (pad (hash-ref r 'racer_name "") 16)
            (pad (hash-ref r 'place "") 4 #:right? #t)
            (pad (hash-ref r 'start_timing "") 6 #:right? #t)))
  (when (> (length rows) limit)
    (printf "… 他 ~a 行\n" (- (length rows) limit))))

;; 勝率 Top N（会場・全国月次共通）
(define (print-winrate-top-table ranked-all n #:caption [caption #f])
  (define show-n (min n (length ranked-all)))
  (define ranked (take ranked-all show-n))
  (printf "\n--- ~a ---\n"
          (or caption
              (format "勝率 Top~a（出走10以上 / 候補~a人）"
                      show-n (length ranked-all))))
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
            (pad (fmt-rate (hash-ref r 'top2_rate 0)) 8 #:right? #t)))
  show-n)

;; ボート本体 / モーター番号の勝率 Top N
;; ranked の各行: hash with number, starts, wins, win_rate, top2_rate
(define (print-equipment-top-table ranked-all n
                                   #:caption [caption #f]
                                   #:id-label [id-label "番号"])
  (define show-n (min n (length ranked-all)))
  (define ranked (take ranked-all show-n))
  (printf "\n--- ~a ---\n"
          (or caption
              (format "~a 勝率 Top~a（候補~a）"
                      id-label show-n (length ranked-all))))
  (cond
    [(null? ranked)
     (printf "（該当なし）\n")
     show-n]
    [else
     (printf "~a ~a ~a ~a ~a\n"
             (pad id-label 8 #:right? #t)
             (pad "出走" 6 #:right? #t)
             (pad "1着" 6 #:right? #t)
             (pad "勝率" 8 #:right? #t)
             (pad "連対率" 8 #:right? #t))
     (for ([r ranked])
       (printf "~a ~a ~a ~a ~a\n"
               (pad (hash-ref r 'number "") 8 #:right? #t)
               (pad (hash-ref r 'starts 0) 6 #:right? #t)
               (pad (hash-ref r 'wins 0) 6 #:right? #t)
               (pad (fmt-rate (hash-ref r 'win_rate 0)) 8 #:right? #t)
               (pad (fmt-rate (hash-ref r 'top2_rate 0)) 8 #:right? #t)))
     show-n]))

