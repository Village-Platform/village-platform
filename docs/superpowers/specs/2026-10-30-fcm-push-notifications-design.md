# FCM push notifications — design

Status: approved in conversation 2026-10-30, awaiting spec review.

## Goal

Deliver notifications to the Android app through Firebase Cloud Messaging (FCM), on top of the
existing in-app inbox. Two sources:

- **System notifications** — the four subscription notices `Notifier.notify` already creates
  (`subscription_approved`, `_rejected`, `_expiring`, `_expired`).
- **Custom campaigns** — written in the admin dashboard, sent to one or more **topics**, now or at a
  scheduled time; also created automatically when an article is published.

Every push carries a **destination** so a tap opens the right screen (an article push opens that
article).

Success: a device that registered receives the push and lands on the right screen; a device that
did not (or an old app version) still finds the notification in the inbox; nothing is lost on a pod
restart; a duplicate push is rare and a lost one does not happen.

## Decisions

| Question | Decision |
|---|---|
| Audience | Logged-in users **and** guests. Devices register with or without login. |
| Click action | `data` payload with a code-defined `screen` + `id`. Admin picks a screen and a target. |
| Targeting | DB-owned topics; admin assigns users; public topics are opt-in from the app (guests per device). A campaign targets 1–5 topics. Built-in `all` topic = every device. |
| Inbox | Inbox stays the source of truth. Campaigns also write inbox rows for logged-in recipients; guests get push only. |
| "Smart" in v1 | Auto-push on article publish, scheduled send, dead-token cleanup. |
| Background work | Solid Queue on the **primary** Postgres, run inside Puma (`SOLID_QUEUE_IN_PUMA`). |
| Out of scope | Per-device language, quiet hours, open-rate tracking, iOS. |

Deployment target is the single-node k3s cluster (`deploy/k8s/`). `CLAUDE.md` still describes
Vercel and is updated as part of this work.

## Firebase setup (prerequisite, done by the user)

- Two Firebase projects: dev and prod. The Android debug build should use a distinct package
  (e.g. `com.aghourservices.dev`) registered in the dev project; release uses `com.aghourservices`
  in prod. Check the Gradle flavors.
- `google-services.json` is client config only; the server cannot send with it.
- For each project, a **service-account private key** (Firebase console → Project settings →
  Service accounts). Stored as `FCM_SERVICE_ACCOUNT_JSON` — the dev key in local `.env`, the prod key
  in the `village-env` k8s secret. Never committed.

## Data model

### `devices`

| column | type | notes |
|---|---|---|
| `installation_id` | string, not null, unique | Stable per install (Firebase Installation ID or a UUID the app keeps). Natural key. Acts as the install's secret. |
| `token` | string, not null, unique | FCM registration token; rotates. |
| `user_id` | FK users, nullable, indexed | Null = guest. |
| `platform` | string, default `android` | |
| `locale` | string | Stored now, used later for per-device language. |
| `app_version` | string | Tells which installs understand which screens. |
| `last_seen_at` | datetime | Updated on each registration. |

### `topics`

| column | notes |
|---|---|
| `key` | not null, unique, `[a-z][a-z0-9_]*`, ≤ 50, `attr_readonly` — it is the FCM topic name. |
| `name` | Arabic display name, not null. |
| `description` | optional. |
| `public` | boolean, default false — listed in the app for opt-in. |
| `system` | boolean, default false — the seeded `all` topic; cannot be edited or deleted, membership implicit (every device). |

Seeded idempotently in `db/seeds.rb`: `all` (system) and `news` (public).

### `topic_subscriptions`

`topic_id` (not null) plus exactly one of `user_id` / `device_id` (check constraint
`num_nonnulls(user_id, device_id) = 1`). Partial unique indexes on `(topic_id, user_id)` and
`(topic_id, device_id)`. No rows for the `all` topic.

A token belongs to an FCM topic when its device is subscribed or its device's user is subscribed.

### `notification_campaigns`

| column | notes |
|---|---|
| `title`, `body` | not null. |
| `screen`, `target_id` | destination (see below). |
| `status` | enum `scheduled`, `sending`, `sent`, `failed`, `canceled`. |
| `scheduled_at` | not null; "send now" = creation time. |
| `sent_at`, `recipients_count`, `last_error` | filled by the job. |
| `fcm_message_name` | FCM's response name; its presence means the push was already accepted. |
| `created_by_id` | FK users (admin), nullable for auto campaigns. |
| `article_id` | FK articles, nullable — set for auto-push on publish. |

`campaign_topics` join table (`campaign_id`, `topic_id`, unique pair). 1–5 topics per campaign
(FCM's condition limit), validated.

### `notifications` (existing)

Add nullable `campaign_id` (FK, indexed). `data` keeps its shape and now always contains the
destination: `{ "screen": "article", "id": "42" }`.

### `articles` (existing)

Add nullable `notify_topic_id` (FK topics) for auto-push.

## Destination contract

`Notifications::Destination` owns a code-defined list:

| screen | id | validation |
|---|---|---|
| `none` | — | opens the inbox |
| `article` | article id | must exist and not be deleted |
| `firm` | firm id | must be in `Firm.visible` (otherwise the app would get a 404) |
| `category` | category id | must exist |
| `subscription` | subscription id | used by system notifications |

FCM `data` payload (all values strings, as FCM requires):
`{ "screen": "...", "id": "...", "notification_id": "..." }` for a per-user push;
`{ "screen": "...", "id": "...", "campaign_id": "..." }` for a topic push (one message reaches many
users, so it cannot carry a per-user notification id). The notification block carries `title` and `body`.

**Rule for the app:** a `screen` it does not recognise opens the inbox. This is what keeps old app
versions safe when a new screen is added. Adding a screen = one entry here + an app release.

## Components

- **`Fcm::Client`** — `deliver(message)` → FCM HTTP v1
  `POST https://fcm.googleapis.com/v1/projects/{project_id}/messages:send`. OAuth via the
  `googleauth` gem (scope `https://www.googleapis.com/auth/firebase.messaging`), token cached until
  shortly before expiry. Uses `Net::HTTP` (already traced by OpenTelemetry). With no
  `FCM_SERVICE_ACCOUNT_JSON` it is a logging no-op. Tests swap it for a fake through
  `Fcm.client=`.
- **`Fcm::Topics`** — `add(topic_key, tokens)` / `remove(topic_key, tokens)`, ≤ 1000 tokens per call,
  via `https://iid.googleapis.com/iid/v1:batchAdd` / `:batchRemove`. **First implementation task:
  confirm this endpoint and its auth against current Firebase docs** (it is what the Admin SDKs use;
  not re-verified for this design).
- **`Fcm::Error` hierarchy** — `Fcm::Unregistered`, `Fcm::InvalidArgument`, `Fcm::Retryable`
  (429/5xx, carries `retry_after`), `Fcm::AuthError` (401/403).
- **`Devices::Register`** — upsert by `installation_id`; enforces the ownership rules below; enqueues
  `SyncDeviceTopicsJob` when the token or user changed.
- **`Devices::Detach`** — clears `user_id`, removes the token from the user's topics.
- **`Campaigns::Schedule`** — creates/reschedules a campaign and enqueues `DeliverCampaignJob`.
- **Jobs:** `PushNotificationJob(notification_id, device_id)` (one per device, so a retry never
  re-sends to the user's other devices), `DeliverCampaignJob(campaign_id, scheduled_at)`,
  `SyncDeviceTopicsJob(device_id, topic_ids:)` — a reconciliation job used for token changes,
  logout, admin membership changes and opt-in toggles alike.

## Flows

### 1. System notification

`Notifier.notify` creates the `Notification` and calls `PushNotificationJob.perform_later` in the
same transaction. Because Solid Queue lives in the same database, the job row commits atomically
with the notification (transactional outbox). The job sends one message per device token of the
user. The existing `dedupe_key` prevents a second row and therefore a second push. Callers keep
sending notifications outside their own transactions (unchanged rule from `Subscriptions::Approve`).

### 2. Campaign

Admin saves → `Campaigns::Schedule` → status `scheduled` →
`DeliverCampaignJob.set(wait_until: scheduled_at).perform_later(id, scheduled_at)`. The job:

1. Locks the campaign. Proceeds only if `status == scheduled` and `scheduled_at` equals the job's
   argument — a canceled or rescheduled campaign makes stale jobs no-ops; a doubled run is a no-op.
   Sets `sending`.
2. For an article campaign, re-checks the article is still published and not deleted; otherwise
   `canceled`.
3. Unless `fcm_message_name` is present, sends **one** FCM message with a topic condition
   (`'news' in topics || 'firm_owners' in topics`, or `topic: "all"`) and saves the name.
4. Writes inbox rows for logged-in recipients with `insert_all` in batches of 1000,
   `dedupe_key: "campaign:#{id}:user:#{user_id}"`. Recipients: for `all`, every non-deleted user;
   otherwise users subscribed directly or through one of their devices.
5. Sets `sent`, `sent_at`, `recipients_count`. On a non-retryable error: `failed` + `last_error`.

Delivery is **at-least-once**: a crash after FCM accepts the message but before the name is saved
re-sends on retry. Accepted; FCM has no idempotency key.

### 3. Auto-push on article publish

The admin article form gets a "notify topic" select (`notify_topic_id`). Saving an article with a
topic and no existing campaign creates one: screen `article`, title/body from the article (body
truncated), `scheduled_at = published_at`. Changing `published_at` reschedules it while still
`scheduled`; clearing the topic cancels it.

### 4. Topic membership sync

- Device token or user changed → `SyncDeviceTopicsJob`: add the token to `all` and every topic it
  belongs to. A rotated-out token is not unsubscribed; FCM drops it once it is invalid.
- Admin adds/removes a user, or a user/guest toggles a public topic → `SyncDeviceTopicsJob` for each
  affected device, limited to that topic: subscribe if the device still belongs, else unsubscribe
  (a device subscribed both directly and through its user stays in).
- Our DB is the source of truth; FCM topics are a mirror. FCM cannot list topic members, so drift is
  repaired by re-running sync, never by reading FCM.

## Error handling

| FCM response | Action |
|---|---|
| `UNREGISTERED` (404) | Delete the device; metric `push_tokens_pruned`. |
| `INVALID_ARGUMENT` (400) | Log with payload; do **not** delete the token (usually our payload bug). |
| 429 / 500 / 503 | `retry_on Fcm::Retryable`, exponential backoff, honouring `Retry-After`, 5 attempts. |
| 401 / 403 | `Fcm::AuthError`: no retry, job fails, metric + alert. Prevents a retry storm on a bad key. |

A push failure never rolls back or deletes the inbox row.

## API (all additive)

| Endpoint | Auth | Behaviour |
|---|---|---|
| `PUT /api/v1/devices/:installation_id` | optional | Body `token`, `locale`, `app_version`, `platform`. Upsert. With a bearer, attaches to `current_user`. `rate_limit`. |
| `POST /api/v1/devices/:installation_id/detach` | required | Device must belong to `current_user`. |
| `GET /api/v1/topics` | optional | Public topics with `subscribed`; device identified by `X-Installation-Id` header. |
| `PUT` / `DELETE /api/v1/devices/:installation_id/topics/:key` | optional | Public topics only. Logged in → user-level subscription; guest → device-level. |

Ownership rules:

- An anonymous request cannot modify a device that has a `user_id` (`403 forbidden`).
- An authenticated request may claim a guest device or its own device. Claiming a device that
  belongs to another user first detaches that user (the same phone, a new login).
- `installation_id` is never returned in any listing.

New error codes, if any, go into both `config/locales/ar.yml` and `en.yml`. `NotificationSerializer`
is unchanged in shape.

## Admin UI

Arabic, server-rendered, existing components (`.card`, `.tbl`, `.badge-*`, `page_header`,
`enum_badge`, `like`, `destroy_and_redirect`).

- `/admin/topics` — index, new/edit, show with a members tab (search user, add, remove), member
  count. `all` is read-only.
- `/admin/notification_campaigns` — index with status badges; new form (title, body, topics
  multi-select max 5, screen select + target id, optional send time); show page with the resolved
  target's title; cancel while `scheduled`.
- `/admin/notifications/new` — keeps "one specific user", gains screen + id and pushes. The
  "all users" option is removed (the in-request loop goes away); the page links to a campaign to
  `all` instead.
- Article form — "notify topic" select.

## Configuration and infrastructure

- Gems: `solid_queue`, `googleauth`.
- Solid Queue tables migrated into the **primary** database (not a separate `queue` database), so
  enqueue is transactional. Production `config.active_job.queue_adapter = :solid_queue`;
  `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]` in `config/puma.rb`; `SOLID_QUEUE_IN_PUMA=1`
  in `deploy/k8s/web.yaml`. Development may use `:async` or Solid Queue; test stays `:test`.
- ENV: `FCM_SERVICE_ACCOUNT_JSON` added to `.env.example` (empty), the k8s README secrets list and
  `village-env`.
- At 10x: move the worker to its own Deployment so campaigns cannot take web threads.

## Observability

`Observability::Metrics`: `push_sent{source,result}`, `push_tokens_pruned`,
`campaigns_delivered{result}`, `devices_registered`. One Grafana alert on push failure rate in
`deploy/observability/grafana-alerting/rules.yaml`.

## Android contract (`docs/push-notifications.md`)

- Register (`PUT /devices/:installation_id`) on launch, in `onNewToken`, and right after login with
  the bearer. Call `detach` on logout before dropping the JWT.
- Request `POST_NOTIFICATIONS` on Android 13+ at a meaningful moment.
- On tap: read `screen` + `id`; known screen → navigate; unknown → inbox. Mark `notification_id` read
  when present.
- Old app versions that never register keep working through the inbox.

## Testing

Request specs (repo convention) with a fake `Fcm` client:

- Devices: register, token rotation, attach on login, **logout isolation** (shared phone stops
  receiving the previous user's topics), **anonymous takeover rejected**, rate limit.
- Topics API: list with `subscribed`, opt in/out for user and guest, non-public topic rejected.
- Admin: topics CRUD and members, campaign create/cancel, single-user send with destination.
- Jobs (`spec/jobs/`): `DeliverCampaignJob` once, twice (no-op), canceled, rescheduled, already-sent
  name skips FCM, inbox rows not duplicated, deleted article cancels; `PushNotificationJob` error
  classification (`UNREGISTERED` deletes device, 5xx retries, 401 fails without retry).
- `spec/seeds_spec.rb` updated for the `all` and `news` topics.
- Day counts use `travel_to` (Cairo DST rule in `CLAUDE.md`).
