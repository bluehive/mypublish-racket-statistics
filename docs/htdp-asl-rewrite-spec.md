# 仕様案: `#lang racket` → HtDP 学習言語（ASL / ISL+）へのリライト可否

日付: 2026-09-10  
ステータス: **仕様・判断のみ（実装なし）**  
参照: https://docs.racket-lang.org/htdp-langs/advanced.html  
関連外: PR #24（公式 `plot` 仕様）とは独立

## 0. 用語の整理

ユーザー言及の「isl+」とリンク先は別物です。

| 名前 | 言語 | `#lang` 例 |
|------|------|------------|
| Intermediate Student with Lambda | **ISL+** | `htdp/isl+` |
| Advanced Student | **ASL**（リンク先） | `htdp/asl` |

本仕様はリンク先どおり **ASL（Advanced）** を主に検討し、ISL+ との差も注記する。

## 1. 問い

**いまのリポジトリ一式を `#lang racket` から ASL（または ISL+）にリライトできるか？**

## 2. 結論（提案）

| 対象 | 判定 |
|------|------|
| **会場CLI・JSON収集表示・RacketFrames本番コード** | **不可（全面リライトしない）** |
| **電子書籍サンプルの一部（ch01 など純粋な導入）** | **条件付き可（別言語の並記・段階移行）** |
| **リポジトリ全体を ASL 一本化** | **非推奨** |

### 論拠
HtDP学習言語は教育用に構文・`require`・ライブラリを制限している。本リポジトリの本番経路は外部パッケージとファイルI/Oに依存する。

### 根拠（現状コード）
次はすべて `#lang racket` であり、ASLではそのまま動かない／実質書けない要素を含む。

- `require racketframes` / `json` / `racket/cmdline` / `racket/system` 等（会場・全国表示）
- `command-line` によるCLI引数
- 大量の `make-hash` / `hash-set!` / `set!` を伴う集計（ASLにhashはあるが、パッケージ連携とスタイルが教材向きでない）
- `call-with-input-file` + `read-json` の日次JSONパイプライン
- ラッパーの `system*` で別スクリプト起動
- 承認済みの公式 `plot` 導入（PR #24）も通常は `#lang racket` + `plot` 前提

ASLの `require` は教材・相対パス制約が強く、**RacketFrames や Boatrace JSON 処理を学習言語だけで完結させるのは現実的でない**。

### 意見
- **データ解析の本線は `#lang racket` のまま維持**する。
- 学習言語への寄せは「入門章の並記」に留め、本番CLIを無理にASL化しない。

## 3. もし部分移行するなら（任意・後続）

### 3.1 スコープ案A（推奨・最小）
- `code/ch01-basics.rkt` など、外部パッケージ非依存の導入例だけ  
  `#lang htdp/asl`（または ISL+）の **別ファイル** として追加
- 既存 `#lang racket` 版は残す（壊さない）
- 原稿に「DrRacket の言語レベル」注記を追加

### 3.2 スコープ案B（非推奨）
- ch02〜ch06・会場表示までASL化  
  → JSON / RacketFrames / mise CLI と衝突し、コスト対効果が悪い

### 3.3 ISL+ について
- ISL+ は ASLよりさらに制限が強い（ミューテーション等が段階的）
- 本リポジトリの集計コード向きではない  
- 「isl+」と書いた意図が **ASL** なら、以降の議論は ASL に統一する

## 4. 受け入れ条件（実装する場合）

- [ ] 対象ファイルが DrRacket で指定言語レベルとして実行できる
- [ ] 既存 `mise run test:racket` / 会場CLIが回帰しない（racket版は残置）
- [ ] README に「どの章が学習言語か」を明示
- [ ] 会場・全国・RacketFrames経路は `#lang racket` のままである

## 5. 判断を仰ぐポイント

1. **全面ASL化はしない**（本線は `#lang racket`）でよいか  
2. 部分移行するなら **案A（ch01等の並記）** までか、そもそも不要か  
3. 意図言語は **ASL** でよいか（ISL+ ではない）

承認後も、実装は別PR・別指示まで着手しない（本PRは仕様のみ）。
