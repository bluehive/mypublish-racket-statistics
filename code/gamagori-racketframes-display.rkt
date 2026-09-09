#lang racket

;; =============================================================================
;; 後方互換ラッパー: 蒲郡会場の日次 JSON を公式 RacketFrames で表示
;; 実装本体は code/venue-racketframes-display.rkt（最大約3年対応）
;; 実行: racket code/gamagori-racketframes-display.rkt
;;       または mise run show:gamagori
;; =============================================================================

(require racket/system
         racket/path)

(define here (path-only (path->complete-path (find-system-path 'run-file))))
(define target (build-path here "venue-racketframes-display.rkt"))
(define ok (system* (find-executable-path "racket") (path->string target) "gamagori"))
(unless ok
  (error 'gamagori-racketframes-display "venue-racketframes-display.rkt の実行に失敗しました"))
