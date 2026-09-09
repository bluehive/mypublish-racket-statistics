#lang racket

;; =============================================================================
;; 端末向け固定桁テーブル表示（ASCII=1・それ以外=2）
;; 会場表示・全国月次サマリなどから共通利用
;; =============================================================================

(provide disp-width
         pad
         fmt-rate
         print-recent-races-table
         print-race-rows-preview
         print-winrate-top-table)

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

(define (fmt-rate x)
  (real->decimal-string (exact->inexact (if (real? x) x 0)) 4))

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

;; 全国月次など勝率 Top N
(define (print-winrate-top-table ranked-all n)
  (define show-n (min n (length ranked-all)))
  (define ranked (take ranked-all show-n))
  (printf "\n--- 勝率 Top~a（出走10以上 / 候補~a人） ---\n"
          show-n
          (length ranked-all))
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
