# 08 — Payments review queue

Status: implemented (2026-10-27)
Part of: super-admin "control everything"
Depends on: 06

## Today

`/admin/subscriptions` lists subscriptions with approve/reject through `Subscriptions::Approve` /
`Reject`. It works one row at a time and has no notion of "has this money actually arrived".

## Goal

Make review fast and safe:

- A **queue view**: pending only, oldest first, screenshot inline (via the existing 5-minute
  `ScreenshotRedirect`), payer phone, reference, plan, amount — approve/reject without leaving the
  page.
- **Duplicate signals**: highlight when the same payer phone or a near-identical reference was
  used before (already unique per method; this catches typos and re-use across methods).
- **Reconciliation note**: optional free-text "matched against statement on <date>" stored on
  approval.
- **SLA indicator**: pending age; dashboard tile for "pending > 24h".

## Out of scope

Automatic bank/wallet reconciliation — InstaPay and Vodafone Cash offer no merchant API for this
use. Revisit if a payment gateway is added (a gateway would replace manual review, not extend it).

## Data

`subscriptions.reconciliation_note` (string ≤ 300). No other schema change.

## Rules

Approval and rejection keep going through the existing services; the queue is only a new view.
