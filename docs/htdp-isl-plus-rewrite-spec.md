# 仕様案: `#lang racket` → HtDP **ISL+** へのリライト可否

日付: 2026-09-10（訂正: 対象言語を ASL ではなく **ISL+** に統一）  
ステータス: **仕様・判断のみ（実装なし）**  
参照（ISL+）: https://docs.racket-lang.org/htdp-langs/intermediate-lam.html  
関連外: PR #24（公式 `plot` 仕様）とは独立

## 0. 用語

| 名前 | 略称 | `#lang` 例 |
|------|------|------------|
| Intermediate Student with Lambda | **ISL+**（本仕様の対象） | `htdp/isl+` |
| Advanced Student | ASL（今回は対象外） | `htdp/asl` |

※ 当初リンクが Advanced だったが、ユーザー訂正により **ISL+ のみ** を検討する。

## 1. 問い

**いまのリポジトリ一式を `#lang racket` から ISL+ にリライトできるか？**

## 2. 結論（提案）

| 対象 | 判定 |
|------|------|
| **会場CLI・JSON・RacketFrames 本番コード** | **不可（全面リライトしない）** |
| **電子書籍サンプルの一部（純粋な導入例）** | **条件付き可（並記）** |
| **リポジトリ全体を ISL+ 一本化** | **非推奨** |

### 論拠
ISL+ は教育用に構文・`require`・利用可能ライブラリを強く制限する。本番のデータ処理は外部パッケージ前提。

### 根拠（現状との衝突例）
現行はすべて `#lang racket` で、ISL+ では実質扱えない／教材スタイルに合わない要素が多い。

- `require racketframes` / `json` / `racket/cmdline` / `racket/system`
- `command-line` CLI
- 可変ハッシュ中心の集計（`make-hash` / `hash-set!` / `set!`）— ISL+ は ASL よりミューテーションが制限される
- 日次 JSON のファイルI/Oパイプライン
- ラッパーの `system*`
- 承認済み公式 `plot` 導入も通常は `#lang racket` 前提

### 意見
- **本線は `#lang racket` のまま**
- ISL+ は入門章の「DrRacket 学習言語版」並記に限定するなら検討可

## 3. 部分移行する場合（任意・後続）

### 案A（推奨・最小）
- `ch01` など外部パッケージ非依存の例だけ `htdp/isl+` の別ファイルを追加
- 既存 racket 版は残す
- 原稿に言語レベル注記

### 案B（非推奨）
- ch02以降・会場表示まで ISL+ 化 → JSON / RacketFrames / mise と非互換

## 4. 受け入れ条件（実装する場合）

- [ ] 対象が DrRacket で Intermediate Student with Lambda として動く
- [ ] 既存会場CLI・`mise run test:racket` が回帰しない
- [ ] README に「ISL+ 対象ファイル」を明示
- [ ] 本番経路は `#lang racket` のまま

## 5. 承認ポイント

1. **全面 ISL+ 化はしない**（本線は racket）でよいか  
2. 将来、案A（並記）をやるか／やらなくてよいか  
3. 対象言語は **ISL+** で確定してよいか（ASL ではない）

承認後も実装は別指示まで着手しない。
