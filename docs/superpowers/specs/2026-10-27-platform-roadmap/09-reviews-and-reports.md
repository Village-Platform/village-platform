# 09 — Reviews and reports

Status: reports implemented (2026-10-27); ratings not built — waiting on the maintainer decision below
Part of: super-admin "control everything"
Depends on: 06

Two features with different risk; ship **reports first**, reviews later.

## Reports (moderation input)

Any signed-in user reports a firm, a firm medium or an article with a reason
(`wrong_info / inappropriate / spam / closed / other`) and optional text.

```
reports
  id, reporter_id, subject_type, subject_id, reason, note, status (open|resolved|dismissed),
  resolved_by_id, resolution_note, created_at, resolved_at
  unique (reporter_id, subject_type, subject_id) WHERE status = 'open'
```

`POST /api/v1/reports` with `rate_limit` (Rails 8) per user. Admin queue grouped by subject with a
count; resolving can suspend the firm or remove the medium/article in one action (audited).

## Reviews (ratings)

Star rating 1–5 plus optional text, one per user per firm (unique index), editable.
`firms.rating_avg` and `rating_count` kept as counters updated in the same transaction.

Risks to accept before building: fake reviews from new accounts (require account age or a phone
check), owners reviewing their own firm (block in policy), and the social cost of a 1-star review
in a village where everyone knows everyone. **Maintainer decision: is a public rating wanted at
all?** Reports alone may be enough.

## Android

Report button (additive, new endpoint). Ratings only if approved above.
