# 13 — Featured firms

Status: implemented (2026-10-27)
Part of: super-admin "control everything"
Depends on: 04

## Difference from spec 04

Spec 04's priority is automatic (by plan). Featuring is **editorial**: a super admin pins a few
firms to a "featured" strip on the home screen for a period (a campaign, a new opening, a paid
promotion).

## Data

```
featured_placements
  id, firm_id, starts_at, ends_at, position, note, created_by_id
  check (ends_at > starts_at)
```

Time-based like subscriptions — no job flips a flag. `scope :current` mirrors `Subscription.current`.
A featured firm still has to be in `Firm.visible`; featuring never overrides visibility.

## API

`GET /api/v1/firms/featured` — new endpoint (additive), returns up to 10 current placements in
`position` order, firms serialized with `FirmSerializer`.

## Admin

Firm show page: "feature this firm" with dates. A list of current and scheduled placements.
