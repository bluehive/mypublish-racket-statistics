#lang racket

;; =============================================================================
;; 第4章：RacketFrames による統計と集計（基本統計量・フルイ・Groupby）
;; 期間蓄積データから直近 N レースをスライス抽出し、休催日偏りを排除したサンプル集計
;; 電子書籍『ボートレース統計入門』サンプルコード
;; =============================================================================

(define (read-csv path)
  (if (file-exists? path)
      (let* ([lines (file->lines path)]
             [headers (string-split (first lines) ",")]
             [rows (for/list ([line (rest lines)])
                     (define vals (string-split line ","))
                     (make-hash
                      (for/list ([h headers] [v vals])
                        (cons h (or (string->number v) v)))))])
        rows)
      '()))

(define (df-mean rows col)
  (if (null? rows)
      0.0
      (let ([vals (map (lambda (r) (hash-ref r col 0.0)) rows)])
        (/ (apply + vals) (length vals)))))

(define (df-std rows col)
  (if (null? rows)
      0.0
      (let* ([avg (df-mean rows col)]
             [sq-diffs (map (lambda (r) (expt (- (hash-ref r col 0.0) avg) 2)) rows)])
        (sqrt (/ (apply + sq-diffs) (length rows))))))

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

;; 【本線機能】期間累積データから「直近 N レース」のみを件数基準で切り出す関数
(define (df-take-recent-races rows n-races)
  (if (null? rows)
      rows
      (let ()
        (define race-groups (make-hash))
        (for ([r rows])
          (define key (format "~a-~a-~a" (hash-ref r "date" "") (hash-ref r "stadium_num" 0) (hash-ref r "race_num" 0)))
          (hash-update! race-groups key (lambda (lst) (cons r lst)) '()))
        (define sorted-keys (sort (hash-keys race-groups) string>?))
        (define target-keys (take sorted-keys (min n-races (length sorted-keys))))
        (apply append (map (lambda (k) (hash-ref race-groups k)) target-keys)))))

(printf "=========================================\n")
(printf " 第4章：統計集計と条件フィルタリング \n")
(printf "=========================================\n\n")

(define raw-rows
  (if (file-exists? "data/parsed_races.csv")
      (read-csv "data/parsed_races.csv")
      (read-csv "data/sample_races.csv")))

;; 1. 【本線ステップ】期間データの集積から「直近 N レース」をスライス抽出（休催日・非開催日の偏りを解消）
(define df (df-take-recent-races raw-rows 100))
(printf "1. 過去データから直近 N レース (N=100 レース) をサンプルとして切り出しました。\n")
(printf "   有効データ件数: ~a 件 (全艇分)\n\n" (length df))

;; 2. 基本統計量の計算 (全体平均)
(define avg-win-rate (df-mean df "win_rate"))
(define std-win-rate (df-std df "win_rate"))

(printf "2. 全レーサーの平均全国勝率 : ~a\n" (real->decimal-string avg-win-rate 2))
(printf "   全国勝率の標準偏差(ばらつき): ~a\n\n" (real->decimal-string std-win-rate 2))

;; 3. df-filter による「1号艇（インコース）」の抽出
(define df-course1
  (df-filter df (lambda (row) (= (hash-ref row "boat_num") 1))))
(define course1-avg-rank (df-mean df-course1 "rank"))

(printf "3. 1号艇（インコース）の平均確定着順 : ~a着 (1号艇優位の証明)\n\n" (real->decimal-string course1-avg-rank 2))

;; 4. df-groupby による枠番別の一括集計
(printf "4. 枠番 (boat_num) ごとの平均着順・平均勝率の一括集計結果:\n")
(define summary-list (df-groupby df "boat_num" '()))
(for ([s summary-list])
  (printf "  艇番 ~a -> 平均着順: ~a着, 平均勝率: ~a\n" (list-ref s 1) (list-ref s 3) (list-ref s 5)))

(printf "=========================================\n")
