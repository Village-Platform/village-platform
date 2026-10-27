# 06 — Audit log

Status: implemented (2026-10-27), then moved to the paper_trail gem at the maintainer's request — see **Revision**
Part of: super-admin "control everything"

## Goal

Answer "who changed what, when, and from which front door" for every privileged write: firm
approval/suspension, subscription review, role change, plan edit, article moderation, settings,
deletions.

## Pattern

**Append-only audit trail.** Rows are inserted, never updated or deleted by the app.

## Data

```
audit_events
  id, actor_id (fk users, null for system/cron), action (string, e.g. "firm.suspend"),
  subject_type, subject_id, changes (jsonb: { attr: [old, new] }), source ("admin"|"api"|"cron"),
  ip, request_id, created_at
  index (subject_type, subject_id, created_at), index (actor_id, created_at), index (created_at)
```

## Mechanics

- `Audit.record(actor:, action:, subject:, changes:)` called **explicitly inside the services and
  controllers that perform the write**, in the same transaction, so a rolled-back action leaves no
  audit row and a committed one always has one.
- Not model callbacks: callbacks fire for seeds, consoles and imports too, and lose the actor and
  the intent ("suspend" vs a generic update).
- Not a gem (PaperTrail/Audited): they version models; we need business actions. Revisit if
  per-attribute history of every model is wanted.
- `request_id` ties an audit row to the logs (observability).

## Admin

`/admin/audit` — filter by actor, subject, action, date; paginated. Each subject's show page gets a
"history" section. No edit, no delete.

## Retention

Keep forever at this scale (a few thousand rows a year). At 10x: partition by month.

## Interview question

Why write the audit row in the same transaction as the change, rather than publishing an event
after commit? What does each choice lose?

## Revision: PaperTrail instead of a custom table

The maintainer chose the `paper_trail` gem over the hand-written `audit_events` table. What changed:

- Versions are written by model callbacks for every save of an audited model, so the trail now also
  covers seeds, consoles and jobs (`source: "system"`), not only admin actions.
- The business action survives as metadata: `versions.operation` ("firm.suspend"), set with
  `audited(...)` / `Audit.operation(...)`, next to PaperTrail's create/update/destroy event.
- Writes that skip callbacks (`update_all`, `delete_all`) are invisible to it; the code was changed to
  per-row `update!` / `destroy` where an audit matters.
- Bonus from the gem: `object` holds the full previous state, so a version can be reified (restored).

Trade-off accepted: more rows (one per save, not per admin action) and a callback-based design, in
exchange for a maintained, well-known gem and full model history.
