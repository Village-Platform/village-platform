# FCM Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Push the existing in-app notifications and new admin campaigns to Android devices through FCM, with a `screen` + `id` destination on every push, DB-owned topics, scheduled sends and auto-push on article publish.

**Architecture:** The inbox (`notifications`) stays the source of truth; FCM is a delivery channel. Durable work runs on Solid Queue in the primary Postgres, so a job enqueued inside a transaction commits with it. One `Fcm::Client` talks to Google; everything else goes through it, and specs swap it for `FakeFcm`.

**Tech Stack:** Rails 8.1, PostgreSQL, Solid Queue, `googleauth`, `Net::HTTP`, FCM HTTP v1, Instance ID topic API, RSpec request specs.

**Spec:** `docs/superpowers/specs/2026-10-30-fcm-push-notifications-design.md`

## Global Constraints

- **Do not `git commit` or open PRs.** Leave all changes uncommitted (user instruction). There are no commit steps.
- Run `bundle exec rspec` before Task 1 and record the baseline; known failures: four in `spec/seeds_spec.rb`, one in `spec/jobs/subscription_expiry_reminders_job_spec.rb`.
- Style: `rubocop-rails-omakase` — double quotes, spaces inside array/hash brackets (`[ :a ]`), endless policy methods. `bin/rubocop` baseline: 2 offenses in `config/application.rb`.
- Coverage goes in request specs (`spec/requests/`); jobs in `spec/jobs/`, services in `spec/services/`.
- Admin copy is hardcoded Arabic in views/controllers; API error codes go into **both** `config/locales/ar.yml` and `en.yml` under `errors.api.*`.
- FCM `data` values are strings only. Payload keys: `screen`, `id`, plus `notification_id` (per-user push) or `campaign_id` (topic push).
- `Notifications::Destination::SCREENS = %w[ none article firm category subscription ]`; admin may pick `%w[ none article firm category ]`.
- Topic key format `\A[a-z][a-z0-9_]*\z`, max 50, `attr_readonly`. Built-in key `all` (`system: true`), seeded `news` (`public: true`).
- A campaign targets 1–5 topics. FCM condition syntax: `'a' in topics || 'b' in topics`.
- `FCM_SERVICE_ACCOUNT_JSON` (whole JSON string). Absent → `Fcm::Client` is a logging no-op.
- FCM error mapping: 404 `UNREGISTERED` → delete device; 400 → log, keep token; 429/500/503 → retry (5 attempts, honour `Retry-After`); 401/403 → fail, no retry.
- Metric attributes come from closed sets only (never ids/tokens).
- `Notifier.notify` keeps its signature; existing `data` keys (`subscription_id`, `days_left`) stay for old apps.

## Review Focus

1. **Shared phone after logout** — user A detaches, B uses the phone as a guest: the token must leave A's user-level topics and A's system pushes must stop. Test in Task 4 (`detach removes the user's topics`) and Task 6 (`does not push to a detached device`).
2. **Token reused by a new install / re-registration with an existing token under a different `installation_id`** — the unique `token` index would raise `RecordNotUnique` (409). Expected: the stale device row is taken over, not an error. Test in Task 4 (`moves a token that another installation held`).
3. **Campaign target deleted between scheduling and sending** (article destroyed, firm suspended) — expected: campaign `canceled` with `last_error`, no push. Test in Task 7 (`cancels when the destination disappeared`).
4. **Admin reschedules a campaign twice quickly** — two queued jobs; only the job whose `scheduled_at` matches sends. Test in Task 7 (`ignores a stale job after reschedule`).
5. **User deleted (soft) while subscribed to a topic** — must get no inbox row from a campaign. Test in Task 7 (`skips soft-deleted users`).

---

### Task 1: Solid Queue in the primary database

**Files:**
- Modify: `Gemfile` (add `gem "solid_queue"`), `config/environments/production.rb:22`, `config/environments/development.rb`, `config/puma.rb`
- Create: `config/queue.yml`, `db/migrate/<ts>_create_solid_queue_tables.rb`, `bin/jobs`, `config/recurring.yml` (empty `production: {}`)
- Modify: `deploy/k8s/web.yaml` (env `SOLID_QUEUE_IN_PUMA: "1"`)
- Test: `spec/jobs/solid_queue_setup_spec.rb`

**Interfaces:**
- Produces: `config.active_job.queue_adapter = :solid_queue` in production and development; Solid Queue tables in the primary schema (`db/schema.rb`). Test env stays `:test`.

- [ ] **Step 1: Write the failing test**

```ruby
RSpec.describe "Solid Queue setup" do
  it "keeps its tables in the primary database" do
    expect(ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")).to be(true)
  end
end
```

- [ ] **Step 2: Run it** — `bundle exec rspec spec/jobs/solid_queue_setup_spec.rb` → FAIL (table missing).
- [ ] **Step 3: Install.** `bundle add solid_queue`, run `bin/rails solid_queue:install`, then move the generated `db/queue_schema.rb` table definitions into one migration `CreateSolidQueueTables` and delete `db/queue_schema.rb`. Remove any `config.solid_queue.connects_to` line the installer added to `production.rb` and any `queue:` database entry in `config/database.yml`. Set the adapter to `:solid_queue` in production and development. Add `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]` to `config/puma.rb` and `SOLID_QUEUE_IN_PUMA=1` to `.env.example` with a comment. `bin/rails db:migrate`.
- [ ] **Step 4: Run it** → PASS. Then `bin/rails runner 'ApplicationJob.set(wait: 1.second); puts ActiveJob::Base.queue_adapter.class'` prints `ActiveJob::QueueAdapters::SolidQueueAdapter`.
- [ ] **Step 5: Full suite** — `bundle exec rspec` → only the baseline failures.

---

### Task 2: `Fcm::Client`, errors, message builder, fake

**Files:**
- Modify: `Gemfile` (`gem "googleauth"`)
- Create: `app/services/fcm.rb`, `app/services/fcm/client.rb`, `app/services/fcm/errors.rb`, `app/services/fcm/message.rb`
- Create: `spec/support/fake_fcm.rb`
- Test: `spec/services/fcm/client_spec.rb`, `spec/services/fcm/message_spec.rb`

**Interfaces:**
- Produces:
  - `Fcm.client -> Fcm::Client | FakeFcm` (memoized; `Fcm.client = x` to swap; `Fcm.reset!`).
  - `Fcm::Client.new(credentials_json: ENV["FCM_SERVICE_ACCOUNT_JSON"], http: Net::HTTP)`
  - `#enabled? -> Boolean`
  - `#deliver(message_hash) -> String` (FCM `name`, e.g. `"projects/x/messages/123"`; `"disabled"` when not enabled)
  - `#subscribe(topic_key, tokens) -> Array<String>` and `#unsubscribe(topic_key, tokens) -> Array<String>` — return the tokens FCM reported as `NOT_FOUND`/`INVALID_ARGUMENT`; slice into batches of 1000.
  - Errors in `fcm/errors.rb`: `Fcm::Error < StandardError`; `Fcm::Unregistered`, `Fcm::InvalidArgument`, `Fcm::AuthError`, `Fcm::Retryable` with `attr_reader :retry_after` (Integer seconds or nil).
  - `Fcm::Message.build(target:, title:, body:, data:) -> Hash` where `target` is `{ token: }`, `{ topic: }` or `{ condition: }`; stringifies every `data` value; sets `android: { priority: "high" }`.
  - `Fcm::Message.target_for_topics(keys) -> Hash` — one key → `{ topic: key }`; several → `{ condition: "'a' in topics || 'b' in topics" }`.
  - `FakeFcm` (spec/support): `#deliveries`, `#subscribed` (`{ "news" => [tokens] }`), `#unsubscribed`, `#fail_next_with(error)`, `#enabled? = true`; `deliver` returns `"projects/test/messages/#{n}"`. Installed with `around` for every example: `Fcm.client = FakeFcm.new`, restored after.

- [ ] **Step 0: Verify the topic endpoint.** Read the current Firebase docs ("Manage topics" / server topic management) and confirm `POST https://iid.googleapis.com/iid/v1:batchAdd` / `:batchRemove` with body `{ to: "/topics/<key>", registration_tokens: [...] }`, header `access_token_auth: true` and an OAuth bearer still work. If they changed, record what replaces them at the top of `fcm/client.rb` and implement that instead; tell the user.
- [ ] **Step 1: Write the failing tests** (`http` stubbed with a lambda-backed double returning `Net::HTTPResponse`-like objects with `code`, `body`, `[]("Retry-After")`):

```ruby
it "returns the message name on 200"            # body {"name":"projects/p/messages/1"} -> "projects/p/messages/1"
it "raises Unregistered on 404 UNREGISTERED"     # {"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}
it "raises InvalidArgument on 400"
it "raises Retryable with retry_after on 429"    # Retry-After: "30" -> retry_after == 30
it "raises Retryable on 503 without Retry-After" # retry_after nil
it "raises AuthError on 401 and 403"
it "is a no-op when no credentials are set"      # Fcm::Client.new(credentials_json: nil).deliver(...) == "disabled", http never called
it "returns the tokens FCM rejected from subscribe" # batchAdd results [{},{"error":"NOT_FOUND"}] -> [tokens[1]]
it "sends 1000 tokens per topic call"            # 2500 tokens -> 3 requests
# message_spec
it "stringifies data values"                     # { id: 42 } -> { "id" => "42" }
it "builds a condition for several topics"       # %w[ news owners ] -> "'news' in topics || 'owners' in topics"
it "targets a single topic directly"             # %w[ all ] -> { topic: "all" }
```

- [ ] **Step 2: Run** `bundle exec rspec spec/services/fcm` → FAIL.
- [ ] **Step 3: Implement.** Credentials: `Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: StringIO.new(json), scope: "https://www.googleapis.com/auth/firebase.messaging")`; `project_id` from the JSON; cache the access token and refresh when `expires_at` is < 60s away (guard with a `Mutex`, Puma is threaded). `deliver` posts `{ message: }` to `https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send` with `open_timeout: 5, read_timeout: 10`. Error classification reads `error.details[].errorCode`, falling back to HTTP status.
- [ ] **Step 4: Run** → PASS; `bin/rubocop app/services/fcm spec/support/fake_fcm.rb` clean.

---

### Task 3: Schema — devices, topics, topic subscriptions

**Files:**
- Create: migrations `CreateDevices`, `CreateTopics`, `CreateTopicSubscriptions`
- Create: `app/models/device.rb`, `app/models/topic.rb`, `app/models/topic_subscription.rb`
- Modify: `app/models/user.rb` (`has_many :devices, dependent: :delete_all`, `has_many :topic_subscriptions, dependent: :delete_all`)
- Modify: `db/seeds.rb` (topics `all` system, `news` public, Arabic names "الجميع", "الأخبار"), `spec/seeds_spec.rb`
- Create: `spec/factories/devices.rb`, `spec/factories/topics.rb`
- Test: `spec/services/topic_membership_spec.rb`, `spec/seeds_spec.rb`

**Interfaces:**
- Produces:
  - `devices`: `installation_id` (string, not null, unique), `token` (string, not null, unique), `user_id` (FK, nullable, indexed), `platform` (string, default `"android"`, not null), `locale`, `app_version`, `last_seen_at`, timestamps.
  - `topics`: `key` (unique), `name` (not null), `description` (text), `public` (bool, default false, not null), `system` (bool, default false, not null), timestamps.
  - `topic_subscriptions`: `topic_id` FK not null, `user_id` FK nullable, `device_id` FK nullable (`on_delete: :cascade`), check `num_nonnulls(user_id, device_id) = 1`, partial unique `(topic_id, user_id) WHERE user_id IS NOT NULL`, `(topic_id, device_id) WHERE device_id IS NOT NULL`.
  - `Topic::EVERYONE_KEY = "all"`; `Topic.everyone -> Topic`; scopes `Topic.listed` (`public: true, system: false`), `Topic.ordered`.
  - `Device#topics -> ActiveRecord::Relation<Topic>` — topics the device belongs to through its own or its user's subscriptions, **excluding** `all`.
  - `Device#topic_keys -> Array<String>` — `["all", *topics.pluck(:key)]`.
  - `Topic#devices -> ActiveRecord::Relation<Device>` — devices subscribed directly or through their user (for `all`: `Device.all`).
  - `Topic.recipient_user_ids(topics) -> Array<Integer>` — non-deleted users reachable through any of the topics (directly, or through one of their devices); for a set containing `all`, every non-deleted user id.
  - `Device` validations: `platform` inclusion `%w[ android ]`, `token` length ≤ 4096.
  - `Topic has_many :topic_subscriptions, dependent: :delete_all` (membership, not history — the one deliberate exception to the repo's `restrict_with_error` habit); `before_destroy` aborts for `system?` with error "لا يمكن حذف موضوع النظام".

- [ ] **Step 1: Write the failing tests** in `spec/services/topic_membership_spec.rb`:

```ruby
it "puts a device in a topic through its user"     # user subscribed to news -> device.topic_keys == %w[ all news ]
it "puts a guest device in a topic directly"        # device-level subscription -> topic.devices includes device
it "rejects a subscription with both user and device" # expect { create(...) }.to raise_error(ActiveRecord::StatementInvalid)
it "lists recipients through users and their devices, without soft-deleted users"
it "makes every non-deleted user a recipient of all"
it "refuses to destroy the system topic"            # Topic.everyone.destroy == false; errors present
```
And in `spec/seeds_spec.rb`: seeds create `all` (system) and `news` (public), and re-running creates no new topics.

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** migrations and models (`find_or_create_by!(key:)` in seeds).
- [ ] **Step 4: Run** the two spec files → PASS (seeds spec: only the four baseline failures remain).

---

### Task 4: Device registration API and topic sync job

**Files:**
- Create: `app/controllers/api/v1/devices_controller.rb`, `app/services/devices/register.rb`, `app/services/devices/detach.rb`, `app/jobs/sync_device_topics_job.rb`, `app/serializers/device_serializer.rb`
- Modify: `config/routes.rb` (under `api/v1`), `app/controllers/concerns/error_handling.rb`, `lib/observability/metrics.rb`
- Test: `spec/requests/api/v1/devices_spec.rb`, `spec/jobs/sync_device_topics_job_spec.rb`

**Interfaces:**
- Consumes: `Device`, `Topic`, `Fcm.client#subscribe/#unsubscribe` (Task 2/3).
- Produces:
  - Routes: `PUT /api/v1/devices/:installation_id` → `devices#update`; `POST /api/v1/devices/:installation_id/detach` → `devices#detach`. `param: :installation_id`.
  - `Devices::Register.call(installation_id:, token:, user:, locale: nil, app_version: nil, platform: "android") -> Device`. Raises `Devices::OwnershipError` when `user` is nil and the existing device has a `user_id`. When `user` claims a device owned by someone else, detaches it first (`Devices::Detach`). Deletes any other device row holding the same `token` before saving. Enqueues `SyncDeviceTopicsJob` when the device is new, the token changed or the user changed.
  - `Devices::Detach.call(device:) -> Device` — remembers the user's topic ids, clears `user_id`, enqueues `SyncDeviceTopicsJob.perform_later(device.id, topic_ids:)`.
  - `SyncDeviceTopicsJob.perform(device_id, topic_ids: nil)` — reconciliation: the topics to check are `Topic.where(id: topic_ids)` when given, else `Topic.where(key: device.topic_keys)`; for each, `subscribe` the token when `device.topic_keys.include?(topic.key)`, else `unsubscribe`. This one job also serves admin membership changes and opt-in toggles (the spec's separate `SyncTopicMembersJob` is folded into it). Tokens FCM rejects → delete the device. Missing device → return.
  - `DeviceSerializer.render(device) -> { platform:, locale:, app_version:, topics: [keys], user_attached: Boolean }` (never `installation_id` or `token`).
  - `ErrorHandling`: `rescue_from Devices::OwnershipError` → `render_error(:forbidden, "forbidden")`.
  - Controller `rate_limit to: 30, within: 1.minute, only: :update` → `render_error(:too_many_requests, "rate_limited")`; add `errors.api.rate_limited` to `ar.yml` ("طلبات كثيرة، حاول بعد قليل.") and `en.yml` ("Too many requests. Try again shortly.").
  - Metric `devices_registered` (counter `aghour.push.devices_registered`, attributes `%i[ result ]`: `created`, `updated`).
  - Detach requires `authenticate_user!` and `device.user_id == current_user.id`, else `forbidden`.

- [ ] **Step 1: Write the failing request specs:**

```ruby
it "registers a guest device"                         # PUT without auth -> 200; Device.count 1; user_id nil; SyncDeviceTopicsJob enqueued
it "attaches the device to the signed-in user"        # PUT with auth_headers(user) -> device.user == user
it "updates the token on rotation without a new row"  # second PUT, new token -> Device.count 1; job enqueued again
it "moves a token that another installation held"     # device A has token T; PUT installation B with T -> 200; A gone
it "refuses an anonymous change to a user's device"   # device owned by user; PUT without auth -> 403 forbidden
it "moves the device to a new user on login"          # owned by A; PUT with B's auth -> user B; A's topics resynced
it "detaches on logout"                               # POST detach with auth -> user_id nil
it "refuses to detach someone else's device"          # -> 403
it "never returns the installation id or token"       # json["data"].keys excludes both
it "rate limits registration"                         # 31 PUTs in a minute -> 429 rate_limited (use memory store for this example)
```
Job spec:
```ruby
it "subscribes the token to all and its topics"       # FakeFcm#subscribed == { "all" => [t], "news" => [t] }
it "unsubscribes from topics it no longer belongs to" # perform(id, topic_ids: [news.id]) after detach -> unsubscribed["news"] == [t]
it "detach removes the user's topics"                 # end-to-end: user in owners topic, detach, perform_enqueued_jobs -> unsubscribed["owners"]
it "deletes a device whose token FCM rejects"
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** (`Device.lock` the row in `Register` inside a transaction; token takeover via `Device.where(token:).where.not(installation_id:).delete_all`).
- [ ] **Step 4: Run** both files → PASS.

---

### Task 5: Topics API (list, opt in, opt out)

**Files:**
- Create: `app/controllers/api/v1/topics_controller.rb`, `app/controllers/api/v1/device_topics_controller.rb`, `app/serializers/topic_serializer.rb`
- Modify: `config/routes.rb`
- Test: `spec/requests/api/v1/topics_spec.rb`

**Interfaces:**
- Consumes: `Topic.listed`, `Device#topic_keys`, `SyncDeviceTopicsJob` (Task 3/4).
- Produces:
  - `GET /api/v1/topics` — `Topic.listed.ordered`; device from header `X-Installation-Id` (optional) → each item `{ key, name, description, subscribed }`. Unknown header → `subscribed: false` everywhere (no 404: the header is a hint).
  - `PUT` / `DELETE /api/v1/devices/:installation_id/topics/:key` → `device_topics#update` / `#destroy`. Same ownership rule as Task 4 (anonymous request on a user's device → 403). Logged in → `TopicSubscription` on `current_user`; guest → on the device. Non-listed topic → 404 `not_found`. Idempotent: subscribing twice → 200, one row. Enqueues `SyncDeviceTopicsJob` for every device of the subscriber with `topic_ids: [topic.id]`.

- [ ] **Step 1: Write the failing specs:**

```ruby
it "lists public topics with subscribed for this device"
it "lets a guest opt in and out per device"           # row on device; DELETE removes it
it "subscribes a signed-in user at user level"        # TopicSubscription.user == user; all the user's devices resynced
it "is idempotent"
it "refuses non-public and system topics"             # PUT .../topics/all -> 404
it "refuses an anonymous toggle on a user's device"   # -> 403
```
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.

---

### Task 6: Destinations and push for system notifications

**Files:**
- Create: `app/services/notifications/destination.rb`, `app/jobs/push_notification_job.rb`, `app/jobs/concerns/fcm_retries.rb`
- Modify: `app/services/notifier.rb`, `app/services/subscriptions/approve.rb`, `app/services/subscriptions/reject.rb`, `app/jobs/subscription_expiry_reminders_job.rb`, `lib/observability/metrics.rb`
- Test: `spec/services/notifications/destination_spec.rb`, `spec/jobs/push_notification_job_spec.rb`, extend `spec/requests/api/v1/notifications_spec.rb`

**Interfaces:**
- Produces:
  - `Notifications::Destination.new(screen:, id: nil)`; `SCREENS`, `ADMIN_SCREENS` (see Global Constraints); `#valid? -> Boolean`, `#error -> String | nil` (Arabic, for admin forms); `#target -> record | nil` (`Article.published` not deleted / `Firm.visible` / `Category` / `Subscription`); `#to_data -> { "screen" => s, "id" => id.to_s }` (`id` omitted for `none`); `Destination.none`.
  - `Notifier.notify(user:, kind:, dedupe_key: nil, data: {}, destination: Notifications::Destination.none, **interpolations)` — stores `data.merge(destination.to_data)`; inside one transaction creates the row and enqueues `PushNotificationJob.perform_later(notification.id, device.id)` for each of `user.devices`.
  - Subscription callers pass `destination: Notifications::Destination.new(screen: "subscription", id: subscription.id)`.
  - `PushNotificationJob.perform(notification_id, device_id)` — skips when either is gone or `device.user_id != notification.user_id` (detached since); sends `Fcm::Message.build(target: { token: }, title:, body:, data: notification.data.merge("notification_id" => id))`. `Fcm::Unregistered` → delete device, metric `push_tokens_pruned`. `Fcm::InvalidArgument` → log + metric `push_sent{source: "system", result: "invalid"}`, no raise.
  - `FcmRetries` concern (included in push jobs): `rescue_from Fcm::Retryable` → if `executions < 5`, `retry_job(wait: [ error.retry_after.to_i, 2**executions ].max.seconds)`, else re-raise; `discard_on Fcm::AuthError` **after** logging and `push_sent{result: "auth_error"}`.
  - Metrics: `push_sent` (`aghour.push.sent`, attributes `%i[ source result ]`, sources `system`/`campaign`, results `ok`/`invalid`/`unregistered`/`auth_error`/`retry`), `push_tokens_pruned` (`aghour.push.tokens_pruned`).

- [ ] **Step 1: Write the failing tests:**

```ruby
# destination_spec
it "accepts a published article"; it "rejects a draft or deleted article"
it "rejects a firm that is not visible"; it "rejects an unknown screen"
it "serializes ids as strings"                        # to_data == { "screen" => "article", "id" => "7" }
# push_notification_job_spec
it "pushes title, body and destination to the device" # FakeFcm.deliveries.last[:data] includes "screen","id","notification_id"
it "does not push to a detached device"               # device.update!(user: nil) before perform -> no delivery
it "deletes the device on Unregistered", :metrics     # metric_value("aghour.push.tokens_pruned") == 1
it "retries with Retry-After on Retryable"            # assert_enqueued_with(job: PushNotificationJob) after fail_next_with(Fcm::Retryable.new(retry_after: 30))
it "stops without retry on AuthError"
# notifications_spec (request)
it "enqueues one push per device of the user when notified"
it "adds the destination to data and keeps subscription_id" # approve a subscription -> data includes "subscription_id", "screen" => "subscription"
```
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** the three files plus `spec/jobs/subscription_expiry_reminders_job_spec.rb` → PASS (except the known DST failure).

---

### Task 7: Campaigns and the delivery job

**Files:**
- Create: migrations `CreateNotificationCampaigns`, `CreateCampaignTopics`, `AddCampaignIdToNotifications`
- Create: `app/models/notification_campaign.rb`, `app/models/campaign_topic.rb`, `app/services/campaigns/schedule.rb`, `app/jobs/deliver_campaign_job.rb`
- Modify: `app/models/notification.rb` (`belongs_to :campaign, class_name: "NotificationCampaign", optional: true`), `lib/observability/metrics.rb`
- Create: `spec/factories/notification_campaigns.rb`
- Test: `spec/jobs/deliver_campaign_job_spec.rb`

**Interfaces:**
- Consumes: `Notifications::Destination`, `Topic.recipient_user_ids`, `Fcm::Message.target_for_topics`, `FcmRetries`.
- Produces:
  - `notification_campaigns` columns as in the spec, plus `article_id` (FK, nullable, unique where not null). `enum :status, { scheduled: 0, sending: 1, sent: 2, failed: 3, canceled: 4 }, validate: true`.
  - `NotificationCampaign`: `has_many :campaign_topics, dependent: :delete_all`, `has_many :topics, through:`; validates title ≤ 100, body ≤ 500, topics count 1..5, destination valid (`#destination -> Notifications::Destination`). `#cancel!(reason = nil)` (only from `scheduled`, else raises `ActiveRecord::RecordInvalid`).
  - `Campaigns::Schedule.call(campaign:) -> NotificationCampaign` — `scheduled_at ||= Time.current`, `status = scheduled`, saves and enqueues `DeliverCampaignJob.set(wait_until: scheduled_at).perform_later(campaign.id, campaign.scheduled_at.iso8601(6))` in one transaction. Rescheduling = call again with a new `scheduled_at`.
  - `DeliverCampaignJob.perform(campaign_id, scheduled_at_iso)`, steps exactly as the spec's Flow 2. Push data: `destination.to_data.merge("campaign_id" => id.to_s)`. Inbox rows via `Notification.insert_all` in batches of 1000 with `kind: :system_announcement`, `campaign_id`, `data: destination.to_data`, `dedupe_key: "campaign:#{id}:user:#{user_id}"`.
  - Metric `campaigns_delivered` (`aghour.push.campaigns`, attributes `%i[ result ]`: `sent`, `failed`, `canceled`).

- [ ] **Step 1: Write the failing tests:**

```ruby
it "sends one topic push and writes inbox rows"       # topics [news]; 2 subscribed users + 1 guest device -> 1 delivery with topic "news"; 2 notifications; status sent; recipients_count 2
it "uses a condition for several topics"              # deliveries.last[:condition] == "'news' in topics || 'owners' in topics"
it "is a no-op when run twice"                        # perform twice -> 1 delivery, 2 notifications
it "skips a canceled campaign"
it "ignores a stale job after reschedule"             # schedule at t1, reschedule t2, perform(id, t1) -> no delivery
it "does not resend when the message name is saved"   # fcm_message_name present, status sending -> 0 deliveries, inbox written
it "cancels when the destination disappeared"         # article destroyed before perform -> status canceled, last_error present
it "skips soft-deleted users"
it "marks failed on AuthError", :metrics              # status failed; metric campaigns result failed
```
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (`campaign.with_lock` for step 1 of the flow; send and insert outside the lock). **Step 4: Run** → PASS.

---

### Task 8: Admin — topics and members

**Files:**
- Create: `app/controllers/admin/topics_controller.rb`, `app/controllers/admin/topic_members_controller.rb`, `app/views/admin/topics/{index,show,new,edit,_form}.html.erb`
- Modify: `config/routes.rb` (`resources :topics do resources :members, only: %i[ create destroy ], controller: "topic_members" end`), `app/views/layouts/admin.html.erb` (nav link "المواضيع", reuse an existing icon)
- Test: `spec/requests/admin/topics_spec.rb`

**Interfaces:**
- Consumes: `Topic`, `TopicSubscription`, `SyncDeviceTopicsJob`.
- Produces: admin CRUD for topics (params `key, name, description, public`; `key` only on create); `system` topics cannot be edited or destroyed (redirect with alert "لا يمكن تعديل موضوع النظام."). Members: `POST /admin/topics/:topic_id/members` with `user_id` (adds user-level subscription, enqueues sync for the user's devices); `DELETE /admin/topics/:topic_id/members/:id` (id = user id). Show page lists members (paginated) with device counts and a user search using `like`.

- [ ] **Step 1: Write the failing specs:** creates a topic; rejects an invalid key; cannot rename `key` on update; cannot edit or delete `all`; adds a member and enqueues `SyncDeviceTopicsJob`; removes a member; non-admin is redirected to login.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** using `.card`, `.tbl`, `page_header`, `destroy_and_redirect`. **Step 4: Run** → PASS; `spec/requests/admin/brand_assets_spec.rb` still passes.

---

### Task 9: Admin — campaigns and single-user send

**Files:**
- Create: `app/controllers/admin/notification_campaigns_controller.rb`, `app/views/admin/notification_campaigns/{index,show,new,_form}.html.erb`
- Modify: `config/routes.rb` (`resources :notification_campaigns, only: %i[ index show new create ] do patch :cancel, on: :member end`), `app/controllers/admin/notifications_controller.rb`, `app/views/admin/notifications/new.html.erb`, `app/views/layouts/admin.html.erb`, `config/locales/ar.yml` (`enums.notification_campaign.status`: مجدولة، جارٍ الإرسال، أُرسلت، فشلت، أُلغيت)
- Test: `spec/requests/admin/notification_campaigns_spec.rb`, update `spec/requests/admin/paranoid_crud_spec.rb:212-235`

**Interfaces:**
- Consumes: `NotificationCampaign`, `Campaigns::Schedule`, `Notifications::Destination::ADMIN_SCREENS`, `Notifier.notify(destination:)`.
- Produces:
  - Campaign form params: `title, body, screen, target_id, scheduled_at` (datetime-local, blank = now), `topic_ids: []` (checkboxes). Create → `Campaigns::Schedule`; invalid → re-render 422 with the destination error. Cancel → `cancel!`, notice "تم إلغاء الحملة.". Index filters by status with `enum_badge`. Show displays the resolved target title (or "غير موجود").
  - `Admin::NotificationsController#create`: only the specific-user path remains; gains `screen` and `target_id`; sends through `Notifier.notify(user:, kind: :system_announcement, destination:, ...)` — add i18n `notifications.system_announcement.title/body` as `%{title}` / `%{body}` in `ar.yml` and `en.yml` so `Notifier` can carry admin text. The "all users" radio is removed and replaced by a link to "حملة جديدة".

- [ ] **Step 1: Write the failing specs:** creates a scheduled campaign for two topics and enqueues `DeliverCampaignJob` with `wait_until`; "send now" enqueues for now; rejects 6 topics; rejects an article that does not exist; cancels a scheduled campaign; cannot cancel a sent one (alert); single-user send stores destination in `data` and enqueues `PushNotificationJob` per device; the old `target=all` param no longer creates notifications for everyone.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** the two spec files → PASS.

---

### Task 10: Auto-push on article publish

**Files:**
- Create: migration `AddNotifyTopicIdToArticles`, `app/services/articles/sync_push_campaign.rb`
- Modify: `app/models/article.rb` (`belongs_to :notify_topic, class_name: "Topic", optional: true`; `has_one :push_campaign, class_name: "NotificationCampaign"`), `app/controllers/admin/articles_controller.rb` (permit `:notify_topic_id`; call the service after a successful create/update), `app/views/admin/articles/_form.html.erb` (select "إرسال إشعار إلى" with blank "بدون إشعار"), `app/views/admin/articles/show.html.erb` (campaign status badge)
- Test: `spec/requests/admin/article_push_spec.rb`

**Interfaces:**
- Consumes: `Campaigns::Schedule`, `NotificationCampaign#cancel!`.
- Produces: `Articles::SyncPushCampaign.call(article) -> NotificationCampaign | nil`:
  - topic set, published_at present, no campaign → create one (title = article title, body = `article.body.truncate(140)`, screen `article`, `scheduled_at = [published_at, Time.current].max`).
  - campaign `scheduled` and `published_at` changed → reschedule; topic cleared or `published_at` cleared → `cancel!`.
  - campaign already `sent`/`sending` → nothing (an edit never re-pushes).

- [ ] **Step 1: Write the failing specs:** publishing now with a topic schedules a campaign for now; a future `published_at` schedules for that time; moving `published_at` reschedules; clearing the topic cancels; editing after send creates nothing; a draft (no `published_at`) creates nothing.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.

---

### Task 11: Operations and documentation

**Files:**
- Modify: `.env.example` (`FCM_SERVICE_ACCOUNT_JSON=` with a comment: dev project key locally, never committed), `deploy/k8s/README.md` (secrets list + `SOLID_QUEUE_IN_PUMA`), `deploy/observability/grafana-alerting/rules.yaml` (alert: `aghour_push_sent_total{result=~"auth_error|invalid"}` rate > 0 for 10m, and any `auth_error`), `README.md` (endpoint table rows for devices and topics), `CLAUDE.md` (k3s instead of Vercel as the live target; Solid Queue replaces `:async`; push section: inbox is the source of truth, destination contract, `FakeFcm` in specs)
- Create: `docs/push-notifications.md` (Android contract from the spec, with request/response examples for each endpoint and the payload table)

- [ ] **Step 1:** Write the docs and config changes above. Copy the alert rule's structure from an existing rule in `rules.yaml`.
- [ ] **Step 2: Verify** `kubectl kustomize deploy/k8s >/dev/null` and `kubectl kustomize deploy/observability >/dev/null` succeed (skip with a note if `kubectl` is not installed).
- [ ] **Step 3: Final checks** — `bundle exec rspec` (only the baseline failures), `bin/rubocop` (only the 2 baseline offenses), `bundle exec brakeman -q --no-pager` (no new warnings).
- [ ] **Step 4: Manual smoke test with the dev Firebase key** — set `FCM_SERVICE_ACCOUNT_JSON` in `.env`, run the server with `SOLID_QUEUE_IN_PUMA=1`, register a real dev device token via `PUT /api/v1/devices/:id`, send a campaign to `all` from `/admin/notification_campaigns/new`, confirm it arrives and the tap payload has `screen`/`id`. Report the result to the user; do not commit.
