# Handoff Index

全エージェントはタスク開始時にまずこのファイルを読む。新しい handoff を書いたら先頭行に追記する(新しいものが上)。要約セルは1-2文・120字以内で書く。データ行が30行を超えたら直近20行+進行中行を残し、残りは `docs/handoff/_INDEX-archive.md` へ退避する。

| NNN | date | role | pipeline | status | 要約 |
|-----|------|------|----------|--------|------|
| 001 | 2026-08-11 | builder | markdown-viewer | needs-review | md を Emacs 内で読めるようにし、Markdown に無い横並びと折りたたみを閲覧モードで実装。表の3pxずれはフォント設定の判断待ち |
