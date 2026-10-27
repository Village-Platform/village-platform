# 02 — Firm media gallery

Status: draft
Request: "Firms should have many images and many videos, compressed before upload."
Depends on: 01 (profiles, direct upload), 04 (per-plan limits)

## Goal

A firm owner (while subscribed) adds, orders and removes images and videos on their firm. The
public sees them on visible firms only. Super admins can remove any item (moderation).

## Data model

A dedicated `firm_media` table rather than `has_many_attached :images` on `Firm`:

```
firm_media
  id, firm_id (fk, not null), kind (image|video), position (int, not null),
  caption (string ≤ 200), width, height, duration_s, created_at, updated_at
  index (firm_id, kind, position)
FirmMedium has_one_attached :file
```

Why a table and not `has_many_attached`: ordering (`position`), a caption, a cover choice,
per-item moderation and counting per kind all need columns. `has_many_attached` gives none of
these, and adding them later means migrating attachments.

`dependent:` — `Firm has_many :media, dependent: :destroy` is the **one deliberate exception** to
the `restrict_with_error` rule: media has no meaning without its firm, and blocking a firm delete
because it has photos would surprise everyone. Purging the files happens through Active Storage's
`purge_later`.

## Limits (from plan, spec 04)

`max_images_per_firm`, `max_videos_per_firm`. Checked in the service with a row lock on the firm
(`firm.lock!`), so two parallel uploads cannot both take the last slot. A firm owner whose
subscription expires keeps their media stored but it stops being public, same as the firm.

## API

```
GET    /api/v1/firms/:firm_id/media                 public (visible firms), owner, super admin
POST   /api/v1/firms/:firm_id/media                 { kind, signed_blob_id, caption }
PATCH  /api/v1/firms/:firm_id/media/:id             { caption, position }
DELETE /api/v1/firms/:firm_id/media/:id
```

`FirmSerializer` gains, additively, `cover_image_url` and `media_count: { images, videos }` so the
list screen needs no extra call. The full gallery stays on its own endpoint (keeps the firm list
light). URLs are public, long-cached variant URLs for images; videos are served from R2 with HTTP
range support (needed for seeking).

`FirmMediumPolicy`: `create?/update?/destroy?` = owner with a current subscription, or super admin.
`Scope` follows `policy_scope(Firm)` — media of an invisible firm is invisible.

## Admin

Firm show page gets a media grid (thumbnail, kind badge, caption, delete). Upload from admin uses
the same `Media::Optimize` for images; admins do not upload video in this spec.

## Android

Gallery strip on firm details; full-screen viewer; ExoPlayer for video. Owner screen with add
(picker → `MediaCompressor` → direct upload → attach), reorder, delete. Old app versions ignore the
new fields and keep working.

## Tests

Request specs: owner adds within limit; over limit → `403 media_limit_reached` (new error code in
both locale files); expired owner cannot add; public cannot see media of a pending/suspended firm;
another owner cannot delete; super admin can.

## Interview questions

1. Why a separate table instead of `has_many_attached`? What would make you change your mind?
2. Two uploads race for the last slot. Walk through what the row lock protects and what it costs.

Reference: Rails API docs, `ActiveRecord::Locking::Pessimistic`.
