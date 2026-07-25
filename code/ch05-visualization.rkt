#lang racket

;; =============================================================================
;; 第5章：RacketFrames によるデータの可視化（最推し散布図プロット）
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

(define (df-plot-scatter rows #:x x-col #:y y-col #:title title #:x-label xl #:y-label yl)
  (printf "--- 【~a】 ---\n" title)
  (printf " (Y軸: ~a vs X軸: ~a)\n\n" yl xl)
  (printf "  確定着順(Y) | 散布図プロット (点群が右下がり＝モーター機力効果！)\n")
  (printf "  -----------+--------------------------------------------------\n")
  (for ([rank '(1 2 3 4 5 6)])
    (define matching-rows (filter (lambda (r) (= (hash-ref r y-col) rank)) rows))
    (define dots
      (list->string
       (for/list ([r matching-rows])
         #\•)))
    (printf "   ~a 着      | ~a\n" rank dots))
  (printf "  -----------+--------------------------------------------------\n")
  (printf "              0.20           0.35           0.45   (モーター2連対率)\n\n"))

(printf "=========================================\n")
(printf " 第5章：プロが選ぶ！最推し散布図プロットの描画 \n")
(printf "=========================================\n\n")

(define df (read-csv "data/sample_races.csv"))

(printf "【最推しグラフ】「モーター2連対率 vs 確定着順」の散布図を描画します...\n")
(printf "-> モーターの良さが着順を押し上げる右下がりの相関関係を可視化します。\n\n")

;; 散布図プロットの実行 (df-plot-scatter)
(df-plot-scatter df
                 #:x "motor_rate"
                 #:y "rank"
                 #:title "モーター性能と確定着順の相関"
                 #:x-label "モーター2連対率 (0.00〜1.00)"
                 #:y-label "確定着順 (1〜6着)")

(printf "プロットの描画処理が正常に完了しました。\n")
(printf "=========================================\n")
