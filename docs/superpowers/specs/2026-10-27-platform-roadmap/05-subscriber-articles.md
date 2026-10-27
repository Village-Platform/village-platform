# 05 — Subscriber articles

Status: draft
Request: subscribers can "write articles on the app".
Depends on: 04 (`max_articles_per_month`), 06 (moderation is audited)

## Goal

A subscribed firm admin writes articles (offers, announcements) that appear in the app's feed.
Today only super admins write articles and they are trusted; subscriber content is not.

## Moderation

Add `status` to `articles`: `draft / pending / published / rejected`, default `published` for
existing rows (migration back-fills) so nothing changes for super-admin articles.

- Subscriber submits → `pending`. Super admin approves → `published` with `published_at = now`
  (or the requested time if later). Rejection stores a reason and notifies the author (Notifier,
  with a `dedupe_key`).
- Super-admin articles skip review (still `published` directly).
- Optional `firm_id` (nullable fk): an article can be about one of the author's own firms; the
  policy checks ownership.

Public scope becomes `published.where(published_at: ..now)` **and** the author is a super admin or
holds a current subscription — the same visibility rule as firms, so an expired subscriber's
articles disappear and return on renewal.

## Limits

`max_articles_per_month` counts articles created in the current calendar month (Cairo time) by the
author, under a lock on the user row, mirroring `Subscriptions::Approve`.

## API

`POST/PATCH/DELETE /api/v1/articles` open to firm admins via `ArticlePolicy`
(`create? = super_admin? || entitlements.articles_left.positive?`). Serializer gains `status`,
`firm_id`, `rejection_reason` (author and admin only). `GET /api/v1/me/articles` lists the author's
own articles in all states.

Images inside articles use the `article_image` profile (spec 01), as one cover image per article in
this spec. Rich inline media is out of scope.

## Admin

Articles index gets a "pending review" tab with approve/reject, using a shared
`Articles::Review` service (same pattern as `Subscriptions::Approve`).

## Abuse

Body length cap, link count cap, and the report button from spec 09. Without 09, moderation is
pre-publication only — acceptable at village scale.
