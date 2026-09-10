# 進捗メモ（2026-09-09）

## 完了（PR #19 / #20 / #21 → main）

- 直近3レース: 結果未確定日を除外。各レースは1〜3着のみ。選手番号列を追加
- 表表示共通化: `code/boatrace-table-format.rkt`（固定桁・勝率表・直近表）
- 先頭行プレビュー廃止 → 会場別選手勝率 Top20（読み込み期間・出走10以上）
- ボート本体 / モーター勝率 Top10（出走表 programs と結果を結合）
- 勝率・連対率表示: すべて `%`・小数第2位・切り捨て（共通 `fmt-rate`）
- 全国月次 Top も同じ表示モジュールを利用

## データ

- 結果JSON収集（約3年・開催日のみ）: 津579 / 蒲郡607 / 常滑620 / びわこ563
- ThinkPad `data/raw/{tsu,gamagori,tokoname,biwako}/` へコピー済み（git未コミット）
- 出走表 `data/programs/` は取得進行中（本体・モーター集計の精度向上用）

## ブランチ整理

- `fix/recent-races-table-align` ほか当日の fix ブランチを local / remote とも削除
- 作業は `main`（PR #21 merge: `e453cbe`）

## 残作業（任意）

- `data/programs` 全日期間の取得完了後、本体・モーター Top10 を再確認
- 必要なら raw JSON の git 管理方針を決める

## 検討中（2026-09-10）

- Issue #17: 公式 `plot` 導入 → 仕様は `docs/issue-17-plot-spec.md`（実装は後続）
