# 14 — CSV export

Status: draft
Part of: super-admin "control everything"
Depends on: 06 (exports are audited), 07 (`export.run` permission)

## Goal

Export the current filtered admin list (firms, users, subscriptions) as CSV for accounting and
offline review.

## Mechanics

- An "export" button on each index page reuses the same filter params (`filter_params`) and query.
- Streamed with `send_data` built by `find_each` + Ruby's `CSV` — a few thousand rows fit in
  memory at this scale; at 10x stream with `ActionController::Live` or generate in a job.
- UTF-8 with BOM so Excel opens Arabic correctly.

## Security

- Exports contain phone numbers: personal data. Audited (who exported what, with which filters).
- **CSV injection:** prefix any cell starting with `=`, `+`, `-`, `@` with `'` so a firm named
  `=HYPERLINK(...)` cannot run as a formula when an admin opens the file.
- Never include password digests, tokens or screenshot URLs.
