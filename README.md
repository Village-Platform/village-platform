# Aghour Services API — أجهور الكبرى

JSON API backend (Rails 8.1, API-only, PostgreSQL) for the village app.
The native Android app consumes it. Kept simple on purpose; extend step by step.

## Stack

- Ruby 4.0.1, Rails 8.1, PostgreSQL
- Auth: `has_secure_password` (bcrypt) + JWT bearer tokens (30 days)
- Authorization: Pundit
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
| POST   | `/subscriptions`                   | user          |
| GET    | `/admin/subscriptions?status=pending`, `/admin/subscriptions/:id` | super_admin |
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

## Subscriptions (firm owners)

1. Owner opens `GET /payment_methods` and `GET /subscription_plans`, pays via InstaPay or Vodafone Cash.
2. Owner submits `POST /subscriptions` with the plan, payment method and transfer reference → `pending`.
3. Super admin checks the transfer, then `approve` (→ `active`, user promoted to `firm_admin`) or `reject` with a reason.
4. Renewals stack: a new approval starts when the remaining time ends.
5. A firm is public only if it is `active` **and** its owner has a current subscription.
   No cron job needed — expiry is time-based. `max_firms` on the plan limits how many firms an owner can add.

Safety: one pending request per user, and a transfer reference can't be reused (DB unique indexes).

## Next steps (planned)

1. Payment screenshot upload (Active Storage) + expiry reminders
2. Admin dashboard (server-rendered, Arabic RTL, dark green & gold)
3. Images via Active Storage (firm logos, category icons, article covers)
4. Token revocation / refresh tokens
5. Push notifications (FCM) for news
6. Dockerfile + deployment
