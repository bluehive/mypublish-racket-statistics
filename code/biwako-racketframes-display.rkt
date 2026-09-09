#lang racket

;; =============================================================================
;; 後方互換ラッパー: びわこ会場の日次 JSON を公式 RacketFrames で表示
;; 実装本体は code/venue-racketframes-display.rkt（最大約3年対応）
;; 実行: racket code/biwako-racketframes-display.rkt
;;       または mise run show:biwako
;; =============================================================================

(require racket/system
         racket/path)

(define here (path-only (path->complete-path (find-system-path 'run-file))))
(define target (build-path here "venue-racketframes-display.rkt"))
(define ok (system* (find-executable-path "racket") (path->string target) "biwako"))
(unless ok
  (error 'biwako-racketframes-display "venue-racketframes-display.rkt の実行に失敗しました"))
