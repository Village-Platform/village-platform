# Platform roadmap — index

Date: 2026-10-27
Status: draft, awaiting maintainer review

## Why this exists

Two requests arrived together:

1. The super-admin "control everything" request, which the admin redesign parked under **Out of
   scope** as one list (`2026-10-26-admin-dashboard-redesign-design.md`). One spec for all of it
   would be one huge migration, one huge review and one release the Android app cannot roll back.
2. A media and subscription request: firms get image and video galleries, category icons get
   smaller, every upload is compressed before it reaches the server, and the subscription becomes
   the product ("manage firms, add media, write articles, be seen first").

Each spec below is sized to ship alone: its own migration, policy, request specs and (when the
Android client reads it) an additive API change.

## Corrections to the original request

These change the design, so they are stated before anything else.

- **"Compress before upload to our server" can only happen on the client.** The server receives the
  bytes first and cannot shrink them before they arrive. The "general engine" is therefore two
  halves sharing one contract: the Android app compresses, and the server publishes the targets and
  rejects anything that does not meet them (see `01`). The server can never trust the client, so
  its checks stay even when every client behaves.
- **"Minimum size without decreasing quality" is two goals that pull apart.** Truly lossless
  re-encoding saves roughly 5–30% on images and almost nothing on video. Real savings (often 70–95%
  on phone photos and videos) come from *visually lossless* encoding: resize to the largest size a
  phone screen shows, then encode at a quality where a person cannot see the difference. The specs
  use that definition and name the exact targets so they can be tested.
- **Videos cannot live where files live today.** Files are stored in PostgreSQL (`stored_files`) on
  a 5Gi volume on one k3s node. Twenty one-minute videos at 1080p is roughly 300–400MB, so a few
  dozen firms would fill the database disk, bloat backups and slow every restore. Videos (and, once
  it exists, all new media) need object storage (`01`, decision D3).

## The specs

| # | Spec | Request | Depends on | Android change |
| --- | --- | --- | --- | --- |
| 01 | [Media pipeline](01-media-pipeline.md) | 5 | — | New compression module, new upload flow |
| 02 | [Firm media gallery](02-firm-media-gallery.md) | 2 | 01, 04 | Gallery screens |
| 03 | [Category icon optimization](03-category-icon-optimization.md) | 3 | 01 | None |
| 04 | [Subscription entitlements and priority](04-subscription-entitlements.md) | 4 | — | Plan details, ordering |
| 05 | [Subscriber articles](05-subscriber-articles.md) | 4 | 04, 06 | Article editor |
| 06 | [Audit log](06-audit-log.md) | 1 | — | None |
| 07 | [Roles and permissions](07-roles-and-permissions.md) | 1 | 06 | None |
| 08 | [Payments review queue](08-payments-review.md) | 1 | 06 | None |
| 09 | [Reviews and reports](09-reviews-and-reports.md) | 1 | 06 | Rating, report button |
| 10 | [Notification composer](10-notification-composer.md) | 1 | 06 | None (uses existing feed) |
| 11 | [Settings store](11-settings-store.md) | 1 | 06 | Reads config endpoint |
| 12 | [Category tree and custom fields](12-category-tree-and-fields.md) | 1 | — | Nested categories, field display |
| 13 | [Featured firms](13-featured-firms.md) | 1 | 04 | Featured strip |
| 14 | [CSV export](14-csv-export.md) | 1 | 06 | None |

"Media galleries" from the parked list is spec `02`.

## Suggested order

1. **06 Audit log** first. Every later admin power is a write that someone will later ask "who did
   this?" about. Adding it afterwards means back-filling every controller.
2. **04 Entitlements**, then **01 Media pipeline**, then **02 Gallery** and **03 Icons**. This is
   the revenue path, and 02 needs 04 to know how many files a plan allows.
3. **05 Subscriber articles** (needs moderation, which needs 06).
4. The rest by demand: 08 and 13 support revenue; 09, 10, 11, 12, 14 support operations.

## Rules that apply to every spec

- **Additive API only.** A released Android version cannot be rolled back. New fields are added,
  old fields keep their meaning, and nothing an old client reads is renamed or removed. Ordering
  changes (04) are allowed because no client depends on alphabetical order for correctness.
- **Super-admin writes go through services shared with the API** where both exist, as
  `Subscriptions::Approve` already does, so the two front doors cannot drift apart.
- **Every admin write is audited** once 06 exists.
- **Error codes** go into both `config/locales/ar.yml` and `en.yml`.
- **Coverage is request specs**, as everywhere else in this repo.

## Scale note

The village has hundreds of firms, not millions. Nothing here needs a queue, a search engine or a
second service **now**. Where a spec makes a choice that changes at 10x, it says so.
