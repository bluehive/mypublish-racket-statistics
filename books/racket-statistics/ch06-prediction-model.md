---
title: "第6章　予想スコアモデルの構築と的中率検証（クライマックス）"
---

> **この章のゴール**  
> 枠番・勝率・機力を多角的にスコア化した予測モデルを構築し、過去データとの結合 (`df-join`) により全自動でレース結果を予想・答え合わせテストする。  
> **使用ライブラリ**: `racketframes`

これまで学んできたすべての技術（データ収集、型安全なデータ操作、基本統計量の集計、散布図プロットによる可視化）を総動員して、いよいよ本電子書籍の最大クライマックスである **「ボートレース予想スコアモデルの構築と的中率テスト」** に挑みます！

---

#### 6.1 予想モデルの数理設計

各艇の強さを表す **予想スコア ($Score$)** を以下の数式でモデル化します。

$$Score = (\text{枠番アドバンテージ点}) + (\text{全国勝率} \times 50) + (\text{モーター2連対率} \times 30)$$

##### 枠番アドバンテージ点
- 1号艇: 40点
- 2号艇: 25点
- 3号艇: 15点
- 4号艇: 10点
- 5号艇: 5点
- 6号艇: 0点

---

#### 6.2 テーブルの結合 (`df-join`)：出走表と過去成績のガッチャンコ

本日の出走表データ（`df-today`）に、第2章で蓄積した過去データ（`df-history`）から算出した「過去勝率」や「モーター2連対率」を `df-join`（テーブル結合）で結合します。

```racket
#lang racket
(require racketframes)

(define df-today (read-csv "data/parsed_races.csv"))
(define df-history (read-csv "data/parsed_races.csv"))

;; racer_id をキーにして出走表と過去成績データをガッチャンコ結合
(define df-merged (df-join df-today df-history "racer_id"))
```

---

#### 6.3 予想スコアの全自動計算

結合したデータに対して、設計した数式を適用し全艇のスコアを一括計算します。

```racket
(define (calc-boat-score row)
  (define b-num (hash-ref row "boat_num"))
  (define w-rate (hash-ref row "win_rate"))
  (define m-rate (hash-ref row "motor_rate"))
  
  (define course-score
    (cond [(= b-num 1) 40.0] [(= b-num 2) 25.0] [(= b-num 3) 15.0]
          [(= b-num 4) 10.0] [(= b-num 5) 5.0]  [else 0.0]))
  
  (+ course-score (* w-rate 50.0) (* m-rate 30.0)))
```

---

#### 6.4 予測の検証：実際の結果と答え合わせをしよう！

モデルを作成したら、実際に「どれくらい的中したか」を確定着順（`rank`）と照らし合わせて **テスト（答え合わせ）** します。

```racket
;; 予想1位の艇が、実際のレースで何%の確率で1着(rank = 1)になったか計算
(define (evaluate-model df-pred)
  (define df-top-score (df-groupby-max df-pred "race_id" "score"))
  (define correct-count
    (df-count (df-filter df-top-score (lambda (row) (= (hash-ref row "rank") 1)))))
  (define total-races (length (df-unique df-pred "race_id")))
  
  (printf "検証したレース数: ~a\n" total-races)
  (printf "1着的中数: ~a\n" correct-count)
  (printf "予測的中率: ~a%\n" (* (/ correct-count total-races) 100.0)))

(evaluate-model df-predicted)
```

---

#### 6.5 おわりに：データサイエンスのサイクルを回し切ったあなたへ

データの収集から前処理、統計集計、グラフ化、そしてテーブルの結合と予測モデルの検証まで、あなたは自らの手で一通りの **「データサイエンスのサイクルの全工程」** を回し切ることができました！

Racket と RacketFrames というシンプルで美しい道具を使えば、どのようなデータ分析も自信を持って進めることができます。

お疲れ様でした！

---

#### 6.6 章のまとめ：三角ロジックによる整理

* **【主張 (Claim)】**: 枠番・勝率・機力を多角的にスコア化した結合モデルを構築することで、過去データに基づく客観的な未来予測と的中率検証が可能になる。
* **【事実・データ (Fact)】**: `df-join`による出走表と過去データの結合、および`evaluate-model`による1着的中率の答え合わせテスト（`code/ch06-prediction.rkt`）。
* **【論拠・理由付け (Reasoning)】**: 各指標の重み付け計算を過去実績の「答え」と照合しチューニングするサイクルを回すことで、データの客観的証拠に基づいた再現性の高い予測が実現するため。
