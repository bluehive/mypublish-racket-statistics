#lang racket

;; =============================================================================
;; 第1章：Racket の基本操作と環境動作確認
;; 電子書籍『ボートレース統計入門』サンプルコード
;; =============================================================================

(printf "=========================================\n")
(printf " Welcome to Racket & Boat Race Statistics \n")
(printf "=========================================\n\n")

;; 1. 基本的な数値の計算
(define boat-1-win-rate 0.85)
(define boat-2-win-rate 0.65)
(define avg-rate (/ (+ boat-1-win-rate boat-2-win-rate) 2))

(printf "1号艇の勝率: ~a\n" boat-1-win-rate)
(printf "2号艇の勝率: ~a\n" boat-2-win-rate)
(printf "2艇の平均勝率: ~a\n\n" avg-rate)

;; 2. 条件分岐のテスト
(define (evaluate-boat-1 win-rate)
  (if (>= win-rate 0.75)
      "1号艇は圧倒的本命（A1エリート）です！"
      "1号艇ですが警戒が必要です。"))

(printf "1号艇の判定結果: ~a\n" (evaluate-boat-1 boat-1-win-rate))
(printf "=========================================\n")
