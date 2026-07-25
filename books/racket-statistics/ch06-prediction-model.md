---
title: "第6章　予測モデルの作成と検証（実践）"
---

> **この章のゴール**  
> 複数のデータフレームを結合（Join）し、統計指標を組み合わせた「簡易予測スコアモデル」を構築・検証できるようになる。  
> **使用機能**: `df-join`, 統計モデリング, 予測精度検証  

最終章となる本章では、これまで学んだ全テクニックを総動員して、過去の統計データをもとに未来のレースの勝利艇を予想する**「簡易予測モデル」**の作成に挑戦します。

#### 6.1 複数データフレームの結合（`Join`）：レーサー情報とレース結果の結合

現実のデータ分析では、データが「レース結果データ」と「レーサー基本データ」のように別々のファイルに分かれていることが一般的です。これらを共通のID（`racer_id` など）を使って1つの大きなテーブルに合体させる操作を **`Join`（結合）** と呼びます。

```racket
#lang racket
(require racketframes)

;; 2つのCSVを読み込む
(define df-races (read-csv "data/races.csv"))        ; レース毎の成績
(define df-racers (read-csv "data/racer_info.csv"))   ; レーサーの過去1年勝率データ

;; racer_id をキーにして Left Join（左結合）を行う
(define df-merged
  (df-join df-races df-racers
           #:on "racer_id"
           #:how 'left))

;; 結合後のデータフレームを確認
(df-summary df-merged)
```

これにより、各レースの出走艇ごとに「その選手の過去1年間の通算勝率」や「F回数（フライング履歴）」が紐付いた高度な分析用データフレームが完成します。

#### 6.2 簡易予測モデルの構築：過去の統計から次のレース結果を予測する

データが揃ったら、勝利確率を示す**「予測スコア (Predictive Score)」**を算出する数式モデルを定義します。

第4章までの分析から、以下の 3 つの要因が勝利に大きく寄与することが分かっています。
1. **コース有利度（枠番）**: 1号艇が最も高く、6号艇が最も低い。
2. **レーサーの実力**: 全国勝率（`win_rate`）。
3. **機力（モーター）**: モーター2連対率（`motor_rate`）。

これらを重み付けして合算する予測関数 `calc-predict-score` を作成します。

```racket
;; 枠番ごとのベーススコア
(define (course-score boat-num)
  (cond
    [(= boat-num 1) 40.0]
    [(= boat-num 2) 20.0]
    [(= boat-num 3) 15.0]
    [(= boat-num 4) 12.0]
    [(= boat-num 5) 8.0]
    [(= boat-num 6) 5.0]
    [else 0.0]))

;; レースの各艇の予測スコアを計算する関数
(define (predict-score boat-num win-rate motor-rate)
  (+ (course-score boat-num)
     (* win-rate 50.0)      ; 選手勝率の重み
     (* motor-rate 20.0)))  ; モーターの重み

;; データフレームに予測スコアの列 "score" を追加する
(define df-predicted
  (df-extend df-merged "score"
             (lambda (row)
               (predict-score (hash-ref row "boat_num")
                              (hash-ref row "win_rate")
                              (hash-ref row "motor_rate")))))
```

これで、すべての出走艇に対して客観的な数値スコアが与えられました。各レースで「最もスコアが高い艇」が、本モデルの予測1着候補となります。

#### 6.3 予測モデルの検証：実際のデータと照らし合わせて検証する

モデルを作って終わりにせず、そのモデルが**「どれくらいの精度で的中したか」を実際の確定着順（`rank`）と照合して検証**します。

```racket
;; 各レースで「最高スコアの艇」が実際に1着(rank = 1)になった割合を計算
(define (evaluate-model df-pred)
  ;; 各レースごとに最高スコアの艇を抽出
  (define df-top-score (df-groupby-max df-pred "race_id" "score"))
  
  ;; その中で実際に rank が 1 だった行をカウント
  (define correct-count
    (df-count (df-filter df-top-score (lambda (row) (= (hash-ref row "rank") 1)))))
  
  (define total-races (length (df-unique df-pred "race_id")))
  
  (printf "検証レース数: ~a\n" total-races)
  (printf "1着的中数: ~a\n" correct-count)
  (printf "予測的中率: ~a%\n" (* (/ correct-count total-races) 100.0)))

;; 検証の実行
(evaluate-model df-predicted)
```

##### 結果の考察とチューニング
もし的中率が 50% だった場合、「枠番の重みを少し下げて、レーサー勝率の重みを上げてみよう」といったモデルのチューニングを行います。

データの収集から前処理、集計、可視化、そしてモデリングと検証まで、あなたは自らの手で一通りの**データサイエンスのサイクル**を回し切ることができました！
Racket と RacketFrames というシンプルで強力な道具を使えば、どのようなデータ分析も自信を持って進めることができます。

お疲れ様でした！

---

* ※予測モデルの精度と統計的限界の整理：三角ロジックで整理予定
