# Aghour Services API — أجهور الكبرى

JSON API backend (Rails 8.1, API-only, PostgreSQL) for the village app.
The native Android app consumes it. Kept simple on purpose; extend step by step.

## Stack

- Ruby 4.0.1, Rails 8.1, PostgreSQL
- Auth: `has_secure_password` (bcrypt) + JWT bearer tokens (30 days)
- Authorization: Pundit
- Admin dashboard: plain Rails views at `/admin` (Arabic, right-to-left)
- Tests: RSpec + FactoryBot
- Locale: Arabic by default (`Accept-Language: en` for English)

## Setup

```bash
cp .env.example .env            # adjust DB credentials
docker compose up -d db         # or use your local PostgreSQL
bundle install
bin/rails db:prepare db:seed
bin/rails s
bundle exec rspec
```

Seeded super admin: `SUPER_ADMIN_PHONE` / `SUPER_ADMIN_PASSWORD` from `.env`.

## Roles

| Role          | Can do                                                        |
|---------------|---------------------------------------------------------------|
| `user`        | Browse categories, firms, news. Default on register.          |
| `firm_admin`  | Create and manage **own** firms while subscribed (created as `pending`). |
| `super_admin` | Everything: categories, news, approve firms, change roles.    |

## Endpoints (`/api/v1`)

| Method | Path                               | Auth          |
|--------|------------------------------------|---------------|
| POST   | `/auth/register`                   | public        |
| POST   | `/auth/login`                      | public        |
| GET/PATCH | `/me`                           | user          |
| GET    | `/categories`, `/categories/:id`   | public        |
| POST/PATCH/DELETE | `/categories[/:id]`     | super_admin   |
| GET    | `/categories/:id/firms`            | public        |
| GET    | `/firms?category_id=&q=&mine=true` | public        |
| GET    | `/firms/:id`                       | public        |
| POST   | `/firms`                           | firm_admin+   |
| PATCH/DELETE | `/firms/:id`                 | owner / super_admin |
| GET    | `/articles?kind=news`, `/articles/:id` | public    |
| POST/PATCH/DELETE | `/articles[/:id]`       | super_admin   |
| GET    | `/admin/users?role=`               | super_admin   |
| PATCH  | `/admin/users/:id` (`role`)        | super_admin   |
| GET    | `/payment_methods`                 | public        |
| GET    | `/subscription_plans[/:id]`        | public        |
| POST/PATCH/DELETE | `/subscription_plans[/:id]` | super_admin |
| GET    | `/subscriptions[/:id]`             | user (own)    |
| POST   | `/subscriptions` (JSON or multipart with `payment_screenshot`) | user |
| GET    | `/subscriptions/:id/payment_screenshot` | user (own) |
| GET    | `/notifications?unread=true`       | user          |
| PATCH  | `/notifications/:id/read`, `/notifications/read_all` | user |
| GET    | `/admin/subscriptions?status=pending`, `/admin/subscriptions/:id` | super_admin |
| GET    | `/admin/subscriptions/:id/payment_screenshot` | super_admin |
| PATCH  | `/admin/subscriptions/:id/approve` | super_admin   |
| PATCH  | `/admin/subscriptions/:id/reject` (`reason`) | super_admin |
| GET    | `/up`                              | health check  |

Lists accept `page` and `per_page` (max 50) and return `{ data: [...], meta: {...} }`.
Errors always look like `{ "error": { "code", "message", "details" } }`.

### Example

```bash
curl -X POST localhost:3000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"01000000000","password":"change-me-please"}'

curl localhost:3000/api/v1/me -H "Authorization: Bearer <token>"
```

## Admin dashboard

Open `http://localhost:3000/admin/login` and sign in with the seeded super admin.

- Built in-house with plain Rails views (ERB + one CSS file, `app/assets/stylesheets/admin.css`).
  No admin gem, no JavaScript framework, nothing to license.
- Arabic, right-to-left, dark green and gold. Works on phone screens too.
- Only `super_admin` users can sign in. The session lasts 12 hours, login is rate-limited,
  and access is re-checked on every request (a demoted admin loses access at once).
- Brand images: originals in `public/brand/` (logo, cover, splash, village photo). The dashboard uses
  web-optimized copies in `public/brand/web/` (logo, light logo mark for dark backgrounds, favicons,
  village scenery for the login page and dashboard banner, village silhouette for the sidebar).
  Regenerate them with ImageMagick if the originals change (see the commit that added them).

| Page | What you can do |
|------|-----------------|
| الرئيسية | Counters, pending subscription requests, subscriptions ending within 7 days, firms waiting for approval |
| الاشتراكات | Filter / search, view details and the payment screenshot, approve or reject with a reason |
| المنشآت | Filter / search, add, edit, approve, suspend, delete; shows whether the firm is visible to the public |
| الأقسام | Add, edit, order, enable/disable (can't delete a category that has firms) |
| الأخبار | Draft, publish now or schedule; filter by kind |
| باقات الاشتراك | Prices in EGP, duration, max firms (purchased plans can only be deactivated) |
| المستخدمون | Search, change role, reset password, see subscriptions and firms |

Approve / reject use the same services as the API, so renewal stacking, role promotion and notifications
behave the same everywhere.

## Subscriptions (firm owners)

1. Owner opens `GET /payment_methods` and `GET /subscription_plans`, pays via InstaPay or Vodafone Cash.
2. Owner submits `POST /subscriptions` with the plan, payment method and transfer reference → `pending`.
3. Super admin checks the transfer, then `approve` (→ `active`, user promoted to `firm_admin`) or `reject` with a reason.
4. Renewals stack: a new approval starts when the remaining time ends.
5. A firm is public only if it is `active` **and** its owner has a current subscription.
   No cron job needed — expiry is time-based. `max_firms` on the plan limits how many firms an owner can add.

Safety: one pending request per user, and a transfer reference can't be reused (DB unique indexes).

### Payment screenshot

Optional on `POST /subscriptions` as `subscription[payment_screenshot]` (multipart/form-data):
PNG, JPEG or WEBP, max 5MB. Files are stored with Active Storage (`storage/` locally).
The screenshot is never public: `GET .../payment_screenshot` checks access, then redirects
to a URL that expires after 5 minutes.

### Notifications and expiry reminders

In-app notifications are created when a subscription is approved or rejected, and by a daily job:
7 days and 1 day before expiry, and once after expiry. Owners who already renewed are skipped,
and every reminder has a dedupe key, so running the job twice sends nothing new.

```bash
bin/rails notifications:subscription_reminders
# crontab example (every day at 09:00 Cairo time):
# 0 9 * * * cd /path/to/aghour_services && RAILS_ENV=production bin/rails notifications:subscription_reminders
```

## Next steps (planned)

1. Images via Active Storage (firm logos, category icons, article covers)
2. Token revocation / refresh tokens
3. Push notifications (FCM) — deliver the existing notifications + news
4. Dockerfile + deployment
