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
| `firm_admin`  | Create and manage **own** firms (created as `pending`).        |
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

## Next steps (planned)

1. Subscriptions for firm owners (InstaPay / Vodafone Cash, manual approval by super admin)
2. Admin dashboard (server-rendered, Arabic RTL, dark green & gold)
3. Images via Active Storage (firm logos, category icons, article covers)
4. Token revocation / refresh tokens
5. Push notifications (FCM) for news
6. Dockerfile + deployment
