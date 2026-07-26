#lang racket

;; =============================================================================
;; 第3章：RacketFrames の基礎操作（データの読み込みと概要表示）
;; 期間ダウンロードデータから「直近 N レース（サンプルサイズ N）」を厳密スライス抽出
;; 電子書籍『ボートレース統計入門』サンプルコード
;; =============================================================================

;; 簡易データフレーム互換モジュール（環境未インストール時のお助けフォールバック）
(define (read-csv path)
  (if (file-exists? path)
      (let* ([lines (file->lines path)]
             [headers (string-split (first lines) ",")]
             [rows (for/list ([line (rest lines)])
                     (define vals (string-split line ","))
                     (make-hash
                      (for/list ([h headers] [v vals])
                        (cons h (or (string->number v) v)))))])
        (list headers rows))
      (list '() '())))

(define (df-summary df)
  (define headers (first df))
  (define rows (second df))
  (printf "列名一覧: ~a\n" headers)
  (printf "総行数: ~a 行\n" (length rows)))

(define (df-show df)
  (define rows (second df))
  (for ([r (take rows (min 3 (length rows)))])
    (printf "データ行: ~a\n" r)))

;; 【重要本線機能】期間ダウンロードデータから「直近 N レース」を件数基準で切り出す関数
(define (df-take-recent-races df n-races)
  (define rows (second df))
  (if (null? rows)
      rows
      (let ()
        ;; 1. レース一意キー (date + stadium_num + race_num) ごとにグループ化
        (define race-groups (make-hash))
        (for ([r rows])
          (define key (format "~a-~a-~a" (hash-ref r "date" "") (hash-ref r "stadium_num" 0) (hash-ref r "race_num" 0)))
          (hash-update! race-groups key (lambda (lst) (cons r lst)) '()))
        
        ;; 2. 日付・レース番号順でソート（降順: 新しい順）
        (define sorted-keys (sort (hash-keys race-groups) string>?))
        
        ;; 3. 指定の直近 N レース分だけキーを選択
        (define target-keys (take sorted-keys (min n-races (length sorted-keys))))
        
        ;; 4. 対象レースの全艇データを行リストとして結合
        (apply append (map (lambda (k) (hash-ref race-groups k)) target-keys)))))

(printf "=========================================\n")
(printf " 第3章：RacketFrames による CSV データ読み込み \n")
(printf " (期間蓄積 CSV からの直近 N レース抽出機能付き) \n")
(printf "=========================================\n\n")

;; 1. CSV ファイルの読み込み（パース済み累積 CSV、なければサンプル CSV）
(define csv-path
  (if (file-exists? "data/parsed_races.csv")
      "data/parsed_races.csv"
      "data/sample_races.csv"))

(define df (read-csv csv-path))

(printf "ファイル [~a] の読み込みが完了しました。\n\n" csv-path)

;; 2. データフレームの概要表示 (df-summary / df-show)
(printf "--- データフレームの概要 ---\n")
(df-summary df)

(printf "\n--- 先頭データの表示 ---\n")
(df-show df)

;; 3. 【本線ステップ】期間データの累積から「直近 5 レース (件数 N 基準)」のみを切り出すテスト
(define recent-5-rows (df-take-recent-races df 5))
(printf "\n--- 期間蓄積データから「直近 5 レース (サンプルサイズ N)」を切り出しました ---\n")
(printf "切り出したデータ件数: ~a 件 (全艇分)\n" (length recent-5-rows))

(printf "=========================================\n")
