# 04 — Subscription entitlements and priority

Status: implemented (2026-10-27)
Request: "Subscribe to manage your firms, add images, videos and write articles on the app, with
high priority of view."

## Today

A plan has one entitlement, `max_firms`. A current subscription makes the owner's active firms
visible (`Firm.visible`). Firms are listed by name. Articles are written only by super admins.

## Pattern

**Entitlements** (also called feature gating): a plan is a bundle of named limits and flags, and
the code asks "is this user entitled to X" in one place instead of checking plan names.

## Data

New columns on `subscription_plans`, each with a default that preserves current behaviour and a
check constraint (as `max_firms` has):

| Column | Type | Default | Meaning |
| --- | --- | --- | --- |
| `max_images_per_firm` | int ≥ 0 | 5 | Spec 02 |
| `max_videos_per_firm` | int ≥ 0 | 0 | Spec 02 |
| `max_video_seconds` | int ≥ 0 | 60 | Overrides profile max when lower |
| `max_articles_per_month` | int ≥ 0 | 0 | Spec 05; 0 = cannot write |
| `priority` | int 0–100 | 0 | Listing rank weight |

Columns rather than a JSON `features` column: limits are read in hot paths, need constraints, and
the admin plan form is a fixed set of inputs. A JSON blob would move validation into Ruby only.

`User#entitlements` returns a value object built from the current plan (or unlimited for super
admins, or all zeros for no subscription). `can_add_firm?` becomes a method on it; the old method
delegates so nothing breaks.

**Plan change while subscribed** — limits are read from the *current* subscription's plan at the
moment of the action. Downgrading never deletes existing media; it only blocks adding more.

## "High priority of view"

Every firm in `Firm.visible` is already owned by a subscriber **or** by the super admin (all the
imported Aghour places). So priority means:

1. Subscriber firms rank above super-admin-owned places.
2. Among subscribers, higher `priority` plans rank first.
3. Ties break by a stable key so pagination does not skip or repeat rows.

Implementation: the listing query joins the owner's current subscription and orders by
`COALESCE(plan.priority, -1) DESC, firms.name, firms.id`. This is computed per query, not stored on
`firms`, because subscriptions expire by time with no job flipping flags (a stored rank would go
stale exactly at expiry).

- **Now:** a join on a few hundred rows — no index work needed beyond the existing ones.
- **At 10x:** add an index on `subscriptions (user_id, ends_at) WHERE status = 1`, check with
  `EXPLAIN ANALYZE`.
- **Fairness:** with many firms in the same tier, the same ones always sit on top. A daily seeded
  shuffle within a tier (`ORDER BY md5(firms.id::text || current_date::text)`) spreads exposure
  without breaking pagination within a day. Optional; maintainer decision.

The same rank applies to category firm lists (`/categories/:id/firms`) and to search. Ordering is a
behaviour change, not a field change, so old Android versions keep working and simply show the new
order.

## API

`SubscriptionPlanSerializer` gains the five fields (additive) so the app can show what each plan
includes. `GET /api/v1/me` gains `entitlements` with limits and current usage, so the app can
disable "add video" before the user tries.

## Admin

Plan form gets the five inputs. Plan list shows them as compact badges.

## Tests

Request specs: defaults keep today's behaviour; listing order (subscriber > super admin place;
higher priority first; stable tiebreak); `me` returns entitlements; downgrade keeps media.

## Interview questions

1. Why compute listing rank at query time instead of storing it? When would you store it?
2. Entitlements as columns vs a JSON column vs a separate `plan_features` table — defend your pick.

Reference: Martin Kleppmann, *Designing Data-Intensive Applications*, ch. 3 (indexes) and ch. 11
(derived data and staleness).
