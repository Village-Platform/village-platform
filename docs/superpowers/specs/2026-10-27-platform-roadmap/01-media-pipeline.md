# 01 — Media pipeline (the general compression "engine")

Status: implemented (2026-10-27)
Request: "Any image/video or attachment must compress before upload to our server — create a
general service/engine."

## Goal

One definition of "what a valid, small file is" for every kind of attachment, used by:

- the **Android app**, to compress before upload;
- the **admin dashboard**, to optimize what an admin uploads (it has no compression step today);
- the **server**, to reject anything that does not meet the definition.

## Pattern

**Shared contract + server-side enforcement** (sometimes called "trust but verify"). The server
owns a registry of *media profiles* and publishes it; clients conform to it; the server validates
every upload against it. This is the same idea as an OpenAPI schema, applied to files.

Choosing this over "the server compresses everything" because the server cannot save upload
bandwidth (the user's mobile data) after the fact, and video transcoding needs CPU and `ffmpeg` the
640Mi web pod does not have. Choosing it over "the client compresses and the server trusts it"
because any HTTP client can call the API.

## Media profiles

`app/models/media_profile.rb` (plain Ruby, a frozen registry, no table):

| Profile | Types accepted | Max bytes | Max edge | Target encoding (client) | Server action |
| --- | --- | --- | --- | --- | --- |
| `category_icon` | PNG, JPEG, WEBP | 512KB (unchanged) | 512px | — (admin upload) | Re-encode (see 03) |
| `firm_image` | JPEG, WEBP | 1.5MB | 2048px | WEBP q≈82, EXIF stripped | Validate, strip EXIF |
| `firm_video` | MP4 (H.264 + AAC) | 40MB | 1280px (720p) | H.264 CRF≈26, ≤2.5 Mbps, AAC 96 kbps, ≤60s | Validate container/duration |
| `article_image` | JPEG, WEBP | 1.5MB | 2048px | as `firm_image` | as `firm_image` |
| `payment_screenshot` | PNG, JPEG, WEBP | 4MB (unchanged) | 2400px | WEBP **lossless** or PNG | Validate only |

Notes on the numbers (to verify on real devices before freezing them):

- 2048px is above every phone screen width in the village and keeps zoom usable. A 12MP phone photo
  (≈3–5MB JPEG) becomes roughly 250–500KB at WEBP q82 with no visible difference.
- 720p H.264 at ≈2.5 Mbps is ≈19MB per minute. 1080p doubles that for little gain on a phone.
- **Payment screenshots stay lossless.** They are evidence of a transfer; lossy artefacts on digits
  could cause a wrong review. Screenshots are small anyway.

## API contract

`GET /api/v1/media_profiles` — public, cacheable for an hour:

```json
{ "data": [ { "name": "firm_image", "content_types": ["image/jpeg","image/webp"],
              "max_bytes": 1572864, "max_edge_px": 2048, "max_duration_s": null,
              "target": { "format": "image/webp", "quality": 82 } } ] }
```

The Android app reads this at start-up and caches it, with **built-in defaults** for when the call
fails. The server can tighten a limit without a new app release; an old app that sends a file the
new limit rejects gets a clear `file_too_large` error, never a crash.

## Server side

- `Media::Validate.call(attachable:, profile:)` — content type sniffed from the bytes (Marcel, which
  Active Storage already uses), not taken from the client's header; size; dimensions; for video,
  duration from the MP4 header. Used by model validations, replacing the hand-written
  `icon_image_is_valid` and `payment_screenshot_is_valid` over time.
- `Media::Optimize.call(blob:, profile:)` — images only, libvips via `image_processing`: auto-rotate,
  resize to `max_edge`, strip metadata, re-encode to the target. Runs only when the upload is above
  the target (an already-small client upload is left as is).
- **EXIF stripping is a security requirement, not an optimization.** A photo taken inside a shop
  carries the phone's GPS position and sometimes the owner's home location. Strip on the client
  **and** on the server.

## Decisions

| | Decision | Recommendation | Why |
| --- | --- | --- | --- |
| D1 | Image format | WEBP | Supported by every Android version the app targets; 25–35% smaller than JPEG at equal quality. AVIF is smaller still but slow to encode on low-end phones. |
| D2 | Video codec | H.264 (AVC) | HEVC is ≈40% smaller but hardware encoding is not universal on cheap phones and licensing is murky. Revisit at 10x storage cost. |
| D3 | Storage for new media | **Cloudflare R2** via the S3 service | Cloudflare already fronts `aghour.dorfsys.com`; R2 has no egress fees; the S3 service is built into Active Storage (`aws-sdk-s3` gem). PostgreSQL keeps existing small files. **Maintainer decision required.** |
| D4 | Upload path for video | Active Storage **direct upload** (presigned PUT to R2) | The phone sends bytes straight to R2; the Rails pod never holds a 40MB body in memory. Images may use the same path for uniformity. |
| D5 | Server-side video transcoding | **Not now** | Needs a worker with `ffmpeg`; the app has no worker (`:async` in-process). Reconsider at 10x or if clients send bad files often. |

### Direct upload flow (D4)

1. App → `POST /rails/active_storage/direct_uploads` (authenticated; route wrapped so only signed-in
   users with an entitlement can call it) with `filename, byte_size, checksum, content_type, profile`.
2. Server validates size/type against the profile **before** signing; returns a presigned URL valid
   for a few minutes and a `signed_blob_id`.
3. App PUTs the file to R2.
4. App → the feature endpoint (e.g. `POST /firms/:id/media`) with the `signed_blob_id`.
5. Server re-validates the blob (the client could have uploaded different bytes) and attaches it.

Unattached blobs from abandoned uploads are purged daily (`ActiveStorage::Blob.unattached` older
than a day) — add it to the existing cron.

## Android side (the client "engine")

A `media` module with one entry point, `MediaCompressor.compress(uri, profile): CompressedFile`:

- Images: decode with downsampling, apply EXIF rotation, scale to `max_edge`, encode WEBP at the
  target quality, drop metadata.
- Video: AndroidX **Media3 Transformer** (on-device, hardware encoder) to H.264 720p at the target
  bitrate; reject before encoding if longer than `max_duration_s`.
- Runs in a WorkManager job so a large video survives the app going to background; shows progress.
- The upload step retries with backoff; the direct-upload checksum makes a retried PUT safe.

## Failure modes

- A client lies about content type → caught by byte sniffing.
- A client compresses badly → `file_too_large`; the user sees a message, not a stuck upload.
- R2 unavailable → upload fails; the firm itself is unaffected (media is optional).
- At 10x: storage cost grows linearly; video is ≈95% of it. The lever is D2 (HEVC) or a shorter max
  duration, not more servers.

## Tests

Request specs: profiles endpoint shape; each profile rejects wrong type, oversize and (images) an
oversize edge; EXIF is gone after `Media::Optimize` (needs libvips locally — see CLAUDE.md, `ruby-vips`
is production-only today; this spec moves it to all groups).

## Interview questions

1. Your client compresses and your server validates. Why not just compress on the server — and what
   changes if a third-party client starts uploading?
2. Why presigned direct uploads instead of streaming through the app server, and how do you stop a
   user from uploading arbitrary bytes to your bucket with a presigned URL?

Reference: Rails Guides, *Active Storage Overview*, section "Direct Uploads"; AndroidX Media3
documentation, "Transformer".
