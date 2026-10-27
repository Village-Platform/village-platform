# 10 — Notification composer

Status: draft
Part of: super-admin "control everything"
Depends on: 06

## Goal

A super admin sends an announcement to an audience: everyone, all firm admins, subscribers whose
subscription ends within N days, or the owners of firms in one category.

## Mechanics

- `/admin/notifications/new`: title, body, audience, preview of recipient count, send.
- `Notifications::Broadcast.call(actor:, audience:, title:, body:)` creates a `broadcasts` row and
  then one `Notifier.notify` per recipient with `dedupe_key: "broadcast:#{id}:#{user_id}"` — a
  retried or double-clicked send delivers nothing twice (idempotency the reminder job already
  relies on).
- Recipient fan-out runs with `insert_all` in batches of 1,000.

## Scale

Hundreds of users: in-request is fine. At 10x (tens of thousands) the request would time out
behind Cloudflare's 100s limit; move the fan-out to a job (the app has `:async` only, so that means
introducing a real queue — Solid Queue fits the stack without Redis).

## Push

The in-app feed exists; there is no push (FCM) yet. Push is its own spec when wanted — it adds
device tokens, a third-party dependency and delivery failures to handle.
