# Issue #17 仕様案: 公式 `plot` ライブラリの導入検討

関連: https://github.com/bluehive/mypublish-racket-statistics/issues/17  
ステータス: **仕様のみ（実装はこのPRに含めない）**  
日付: 2026-09-10

## 1. 背景と現状

### 論拠
電子書籍第5章は「可視化」が主題だが、現行サンプルは端末向けASCII散布図であり、公式 `plot` の学習体験とずれている。

### 根拠（現状コード）
- `code/ch05-visualization.rkt` の `df-plot-scatter` は `printf` による点文字プロット
- `mise run plot:scatter` はこのスクリプトを実行
- 原稿 `books/racket-statistics/ch05-racketframes-visualization.md` もASCII寄り
- 会場表示（`venue-racketframes-display.rkt`）は表中心で、まだ本格プロットを使っていない

### 意見
Issue本文の提案どおり、**公式 `plot` を第5章の本線に据える**のがよい。`graphite` は発展課題に回す。

## 2. 目標（取り入れる範囲）

| 優先 | 内容 | 備考 |
|------|------|------|
| P0 | 第5章サンプルを公式 `plot` の散布図へ置換（または併記） | PNG出力も |
| P0 | 依存・実行手順を README / mise に明記 | `raco pkg install plot`（通常同梱確認） |
| P1 | 会場データ向けの簡易プロット（枠番勝率棒、選手勝率ヒスト等） | 既存JSONを入力 |
| P2 | `graphite` の紹介（任意章・コラム） | 必須にしない |
| 対象外 | GUI必須の対話操作をCIで検証 | headlessはファイル出力で足りる |

## 3. 技術方針

### 3.1 ライブラリ選択
- **採用: `plot`（公式）**
  - scatter / line / histogram / 2D・3D
  - PNG / PDF / SVG 出力が標準
  - ドキュメント: https://docs.racket-lang.org/plot/
- **見送り（当面）: `graphite`**
  - ggplot2風で強力だが、入門書の必須依存を増やしたくない

### 3.2 APIの置き方（案）
共通モジュールは既存の表表示と役割分担する。

```
code/boatrace-table-format.rkt  … 端末表（既存）
code/boatrace-plot.rkt          … 新規（仕様。実装は後続PR）
  provide:
    plot-scatter-xy      ; 汎用散布図 → ファイル or 画面
    plot-motor-rank      ; 第5章互換: motor_rate vs place
    plot-boat-winrates   ; 枠番別勝率の棒グラフ（任意）
```

ヘッドレス実行を優先し、既定はファイル出力:

```racket
(plot-file
  (points pts #:sym 'fullcircle)
  "output/ch05-motor-scatter.png"
  #:title "モーター2連対率 vs 着順"
  #:x-label "モーター2連対率"
  #:y-label "着順")
```

DrRacket利用者向けに、同じrendererを `plot`（画面表示）でも呼べる薄いラッパを用意する。

### 3.3 第5章の移行方針
1. **段階A（推奨）**: ASCII版を残しつつ、公式 `plot` 版を `code/ch05-visualization-plot.rkt` として追加。`mise run plot:scatter` は公式版を指す。ASCIIは `plot:scatter:ascii` に退避。
2. **段階B**: 原稿を公式 `plot` の最小例に更新（points + 必要なら回帰直線は後続）。
3. **段階C**: 会場表示から「任意でPNGを吐く」オプション（例: `PLOT=1 mise run show:hamanako`）を検討。

### 3.4 データ入力
- 第5章: 当面 `data/sample_races.csv`（現行どおり）
- 発展: `data/parsed_*_races.csv` または会場JSON由来の行リスト
- 欠損・未確定着順（place < 1）はプロット前に除外（直近レース表示と同じ基準）

## 4. 受け入れ条件（実装PR用）

- [ ] `raco pkg install` 手順がREADMEにあり、新規環境で再現できる
- [ ] `mise run plot:scatter` が `output/` にPNG（またはSVG）を生成する
- [ ] 第5章の「モーター2連対率 vs 着順」が公式 `plot` で表現されている
- [ ] CI / `mise run test:racket` がヘッドレスで落ちない（画面必須にしない）
- [ ] Issue #17 をクローズ可能な説明がPR本文にある

## 5. 非目標

- すべての会場表示にグラフを強制しない
- 3D / contour / violin を入門必須にしない（コラム可）
- GitHubに大容量画像を大量コミットしない（`.gitignore` で `output/*.png` 等を維持・確認）

## 6. 作業分割（後続PR）

1. **本PR（仕様）**: 本ドキュメントのみ
2. **実装PR-A**: `boatrace-plot.rkt` + ch05公式plot版 + mise更新
3. **実装PR-B**: 原稿ch05の追記・校正
4. **実装PR-C（任意）**: 会場勝率の棒グラフ

## 7. 判断まとめ（ユーザー承認ポイント）

| 項目 | 提案 |
|------|------|
| 公式 `plot` を第5章本線にする | **採用** |
| `graphite` | 発展・任意 |
| ASCII散布図 | 互換タスクとして残す |
| 会場CLIへのプロット統合 | 後続・任意 |

承認後、実装PR-Aから着手する。
