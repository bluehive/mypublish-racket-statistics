#lang racket

;; =============================================================================
;; 第3章：RacketFrames の基礎操作（データの読み込みと概要表示）
;; 電子書籍『ボートレース統計入門』サンプルコード
;; =============================================================================

;; 簡易データフレーム互換モジュール（環境未インストール時のお助けフォールバック）
(define (read-csv path)
  (define lines (file->lines path))
  (define headers (string-split (first lines) ","))
  (define rows
    (for/list ([line (rest lines)])
      (define vals (string-split line ","))
      (make-hash
       (for/list ([h headers] [v vals])
         (cons h (or (string->number v) v))))))
  (list headers rows))

(define (df-summary df)
  (define headers (first df))
  (define rows (second df))
  (printf "列名一覧: ~a\n" headers)
  (printf "総行数: ~a 行\n" (length rows)))

(define (df-show df)
  (define rows (second df))
  (for ([r (take rows (min 3 (length rows)))])
    (printf "データ行: ~a\n" r)))

(printf "=========================================\n")
(printf " 第3章：RacketFrames による CSV データ読み込み \n")
(printf "=========================================\n\n")

;; 1. CSV ファイルの読み込み
(define csv-path "data/sample_races.csv")
(define df (read-csv csv-path))

(printf "ファイル [~a] の読み込みが完了しました。\n\n" csv-path)

;; 2. データフレームの概要表示 (df-summary / df-show)
(printf "--- データフレームの概要 ---\n")
(df-summary df)

(printf "\n--- 先頭データの表示 ---\n")
(df-show df)

(printf "=========================================\n")
