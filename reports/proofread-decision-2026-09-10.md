# 校正採否メモ（2026-09-10）

入力:
- `reports/antigravity-proofread-2026-09-10.md`（Antigravity）
- `reports/grok-independent-proofread-2026-09-10.md`（独立チェック）

## 採用（本PR）
- 誤字: 視視化→視覚化、本気構造→本質的な構造、自働→自動
- プレースホルダ「三角ロジックで整理予定」の除去／本文化
- ch02 の `file:///home/mevius/...` → 相対リンク
- intro 複勝率→2連対率、インストーラー表記、式表記の余分スペース
- ch04「24箇所」→「24場」、太字崩れの修正
- ch05 節番号 5.5→5.4、「右肩下がり」は既に統一寄りのため維持
- ch06 `(evaluate-model df-predicted)` → `df-pred`
- ch03 呼び出し側で行リストを df 構造 `(list (first df) rows)` に戻す
- appendix-d 余分空白、appendix-e「抑圧」→「抑制」、curl 太字ネスト

## 却下（Antigravity誤認）
- `#:build?` → `#:build-path?` … **誤り**。Racket 8.x では `#:build?` が正しく、付属 `code/ch02-json-parser.rkt` も `#:build?`。

## 保留（著者判断が必要・別PR推奨）
- `rank` / `win_rate` / `motor_rate` の尺度・列意味の全書統一
- 第6章スコア係数の再設計
- 「予想」vs「予測」の方針決定と一括置換
- mise の読み（ミズ／ミーズ）
- 「決定論的相関」のトーン緩和
