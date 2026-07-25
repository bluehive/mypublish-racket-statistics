#lang racket

;; =============================================================================
;; 第4章：RacketFrames による統計と集計（基本統計量・フルイ・Groupby）
;; 電子書籍『ボートレース統計入門』サンプルコード
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

(define (df-mean rows col)
  (define vals (map (lambda (r) (hash-ref r col)) rows))
  (/ (apply + vals) (length vals)))

(define (df-std rows col)
  (define avg (df-mean rows col))
  (define sq-diffs (map (lambda (r) (expt (- (hash-ref r col) avg) 2)) rows))
  (sqrt (/ (apply + sq-diffs) (length rows))))

(define (df-filter rows pred)
  (filter pred rows))

(define (df-count rows)
  (length rows))

(define (df-groupby rows group-col agg-spec)
  (define groups (make-hash))
  (for ([r rows])
    (define key (hash-ref r group-col))
    (hash-update! groups key (lambda (lst) (cons r lst)) '()))
  (for/list ([(key g-rows) groups])
    (list group-col key
          "rank_mean" (real->decimal-string (df-mean g-rows "rank") 2)
          "win_rate_mean" (real->decimal-string (df-mean g-rows "win_rate") 2))))

(printf "=========================================\n")
(printf " 第4章：統計集計と条件フィルタリング \n")
(printf "=========================================\n\n")

(define df (read-csv "data/sample_races.csv"))

;; 1. 基本統計量の計算 (全体平均)
(define avg-win-rate (df-mean df "win_rate"))
(define std-win-rate (df-std df "win_rate"))

(printf "1. 全レーサーの平均全国勝率 : ~a\n" (real->decimal-string avg-win-rate 2))
(printf "   全国勝率の標準偏差(ばらつき): ~a\n\n" (real->decimal-string std-win-rate 2))

;; 2. df-filter による「1号艇（インコース）」の抽出
(define df-course1
  (df-filter df (lambda (row) (= (hash-ref row "boat_num") 1))))
(define course1-avg-rank (df-mean df-course1 "rank"))

(printf "2. 1号艇（インコース）の平均確定着順 : ~a着 (1号艇優位の証明)\n\n" (real->decimal-string course1-avg-rank 2))

;; 3. df-filter による「勝率 0.75 以上」のエリート選手の抽出
(define df-elites
  (df-filter df (lambda (row) (>= (hash-ref row "win_rate") 0.75))))

(printf "3. 勝率 0.75 以上（SG・GI常連エリート）のデータ件数: ~a件\n\n" (df-count df-elites))

;; 4. df-groupby による枠番別の一括集計
(printf "4. 枠番 (boat_num) ごとの平均着順・平均勝率の一括集計結果:\n")
(define summary-list (df-groupby df "boat_num" '()))
(for ([s summary-list])
  (printf "  艇番 ~a -> 平均着順: ~a着, 平均勝率: ~a\n" (list-ref s 1) (list-ref s 3) (list-ref s 5)))

(printf "=========================================\n")
