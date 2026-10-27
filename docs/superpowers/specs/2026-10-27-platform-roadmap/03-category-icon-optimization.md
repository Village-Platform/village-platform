# 03 — Category icon optimization

Status: implemented (2026-10-27)
Request: "Compress category icons to the minimum size possible without decreasing quality."
Depends on: 01 (`Media::Optimize`, `category_icon` profile)

## Facts

- Icons are uploaded by super admins from `/admin/categories` (browser, no Android upload path).
- Icons are shown as small tiles; the largest display on a high-density phone is about 96dp ×
  xxxhdpi (4×) = 384px.
- The icon endpoint already caches immutably by content hash (`icon_version`), so a smaller file is
  served once per device and then never again. **The bandwidth win is real but small**; the main
  win is first-load speed on slow mobile data.

## Design

On attach (admin create/update and `Category#attach_default_icon!`), run
`Media::Optimize.call(blob:, profile: :category_icon)`:

1. Resize so the longest edge is at most **512px** (keeps a margin above 384px).
2. Strip metadata.
3. Encode both **lossless WEBP** and **lossy WEBP q90**; keep the smaller one *only if* its
   difference from the source is below a perceptual threshold (vips `dE00` average < 1.0). Icons
   with flat colour and transparency usually win with lossless.
4. Replace the attachment with the result; `icon_version` changes automatically, so caches roll.

"Before upload" in the browser is possible (canvas re-encode) but adds JavaScript to an admin that
deliberately has none, for an action done a dozen times a year. Server-side is the right place here.

## Backfill

`bin/rails categories:optimize_icons` — idempotent (skips blobs already at or under target, using a
`metadata["optimized"]` flag on the blob). Run once in production.

## Compatibility

- The `icon_url` contract is unchanged; only the bytes and `v` change.
- WEBP with alpha needs Android 4.2.1+; the app's `minSdk` is far above that. **Verify `minSdk` in
  the Android project before shipping.**

## Dependency change

`ruby-vips` moves from the `:production` group to the default group so this is testable locally
(libvips must then be installed in dev and CI). Without it the spec cannot be covered by tests.

## Tests

Request spec: uploading a 500KB PNG icon results in an attached WEBP ≤ the original, edge ≤ 512px,
`icon_url` with a new `v`.
