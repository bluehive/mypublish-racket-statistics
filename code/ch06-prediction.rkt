#lang racket

;; =============================================================================
;; 第6章：簡易予測モデルの構築と答え合わせテスト
;; 電子書籍『ボートレース統計入門』サンプルコード（クライマックス）
;; =============================================================================

(define (read-csv path)
  (define lines (file->lines path))
  (define headers (string-split (first lines) ","))
  (define rows
    (for/list ([line (rest lines)])
      (define vals (string-split line ","))
      (make-hash
       (for/list ([h headers] [v vals])
         (cons h (or (string->number v) v))))))
  rows)

(define (df-join races racers #:on key #:how mode)
  (for/list ([r races])
    (define racer-id (hash-ref r key))
    (define match (findf (lambda (rc) (= (hash-ref rc key) racer-id)) racers))
    (if match
        (begin
          (hash-set! r "year_win_rate" (hash-ref match "year_win_rate"))
          r)
        r)))

(printf "=========================================\n")
(printf " 第6章：予想スコアモデルの計算と的中率検証 \n")
(printf "=========================================\n\n")

;; 1. データファイルの読み込みと Left Join 結合 (df-join)
(define df-races (read-csv "data/sample_races.csv"))
(define df-racers (read-csv "data/racer_info.csv"))

(define df-merged (df-join df-races df-racers #:on "racer_id" #:how 'left))

(printf "1. 出走表データと選手過去データのテーブル結合 (df-join) 完了\n\n")

;; 2. 枠番の物理的アドバンテージ（コース基礎点）
(define (course-score boat-num)
  (cond
    [(= boat-num 1) 40.0]
    [(= boat-num 2) 20.0]
    [(= boat-num 3) 15.0]
    [(= boat-num 4) 12.0]
    [(= boat-num 5) 8.0]
    [(= boat-num 6) 5.0]
    [else 0.0]))

;; 3. 予想スコアリングアルゴリズム関数
(define (predict-score boat-num win-rate motor-rate)
  (+ (course-score boat-num)
     (* win-rate 50.0)
     (* motor-rate 20.0)))

;; 4. 全行に予想スコア列 "score" を追加
(for ([r df-merged])
  (define sc (predict-score (hash-ref r "boat_num")
                             (hash-ref r "win_rate")
                             (hash-ref r "motor_rate")))
  (hash-set! r "score" sc))

(printf "2. 各艇の予想スコア (score) の一括計算完了\n\n")

;; 5. 予測モデルの的中率答え合わせテスト (evaluate-model)
(define (evaluate-model rows)
  (define races-hash (make-hash))
  (for ([r rows])
    (define rid (hash-ref r "race_id"))
    (hash-update! races-hash rid (lambda (lst) (cons r lst)) '()))
  
  (define correct-count 0)
  (define total-races (hash-count races-hash))
  
  (for ([(rid r-list) races-hash])
    (define sorted (sort r-list (lambda (a b) (> (hash-ref a "score") (hash-ref b "score")))))
    (define top-boat (first sorted))
    (when (= (hash-ref top-boat "rank") 1)
      (set! correct-count (+ correct-count 1))))
  
  (printf "--- 【答え合わせテスト結果】 ---\n")
  (printf " 検証レース数 : ~a レース\n" total-races)
  (printf " 1着的中レース数: ~a レース\n" correct-count)
  (printf " 予想モデル1着的中率: ~a%\n" (real->decimal-string (* (/ correct-count total-races) 100.0) 1)))

(evaluate-model df-merged)
(printf "=========================================\n")
