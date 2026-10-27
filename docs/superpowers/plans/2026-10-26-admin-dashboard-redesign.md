# Admin Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the eight existing `/admin/*` screens onto the artifact's design system — token-driven light/dark themes, 200px light sidebar, permanent topbar, denser tables — with no schema, API or domain change.

**Architecture:** `tailwindcss-rails` (Tailwind v4) compiles `app/assets/stylesheets/application.tailwind.css` to `app/assets/builds/tailwind.css` through the existing `assets:precompile` step. Colour lives once, as rgb channel triplets redefined under `[data-theme]`, so every utility flips theme with no `dark:` variants. The old `admin.css` component names (`.card`, `.btn`, `.tbl`…) are re-implemented as `@apply` components, which keeps the twenty views rendering while the look changes underneath them.

**Tech Stack:** Rails 8.1.4, Ruby 4.0.1, Propshaft, tailwindcss-rails (Tailwind v4), RSpec + FactoryBot, PostgreSQL. No node, no JS framework.

**Spec:** `docs/superpowers/specs/2026-10-26-admin-dashboard-redesign-design.md`

## Global Constraints

- No node in `Dockerfile.vercel`. `tailwindcss-ruby` ships a precompiled binary; the image must not gain a node install.
- `Gemfile.lock` must keep platform `x86_64-linux-gnu` resolving under `BUNDLE_DEPLOYMENT=1`.
- `config/locales/ar.yml` and `en.yml` are **not** edited. Admin copy is hardcoded Arabic in views; `ar.yml` strings ship to the Android client.
- No migrations, no model changes, no serializer changes, no route changes except `patch /admin/theme`.
- Latin digits everywhere. No Arabic-Indic numerals are introduced.
- Icons stay the existing inline SVGs from `Admin::IconsHelper`. No emoji.
- Token values are exactly those in the spec's token table; copy them, do not re-derive.
- `bin/rubocop` must end with only the two known offences in `config/application.rb`.
- Pre-existing failures stay: four in `spec/seeds_spec.rb`, one DST case in `spec/jobs/subscription_expiry_reminders_job_spec.rb`. Do not fix them here.
- Style: `rubocop-rails-omakase` — double quotes, spaces inside array/hash literal brackets.

## Review Focus

Five conditions the spec implies that would bite a real admin, each with its test placed in the task that owns the code:

1. **A crafted `admin_theme` cookie value** reaches `<html data-theme="...">`. Anything outside `light`/`dark` must be ignored, not interpolated. → Task 2.
2. **The theme endpoint from a logged-out visitor** must redirect to login and set no cookie. → Task 2.
3. **`redirect_back` with no `Referer`** must land on the dashboard, not raise. → Task 2.
4. **A fresh install with zero firms** renders the category bars; the artifact divides by the maximum of the set, and `[].max` is `nil` in Ruby. The card must render an empty state instead. → Task 4.
5. **`empty_state` in dark theme** draws `/brand/web/mark.png`, a dark-green mark, on a dark-green surface — invisible on every empty table. It needs the same theme swap as the sidebar mark. → Task 3.

---

### Task 1: Tailwind toolchain and token layer

Lands the build and the tokens without changing a single pixel: preflight stays off and `admin.css` keeps styling the app, so this task is purely additive and independently reviewable.

**Files:**
- Modify: `Gemfile`, `Gemfile.lock`, `.gitignore`
- Create: `app/assets/stylesheets/application.tailwind.css`
- Create: `app/assets/builds/.keep`
- Modify: `app/views/admin/shared/_head.html.erb:19`
- Test: `spec/assets/tailwind_build_spec.rb`

**Interfaces:**
- Consumes: nothing.
- Produces: the token utilities every later task uses — `bg-page`, `bg-surface`, `bg-surface2`, `text-ink`, `text-muted`, `border-line`, `bg-gold`, `text-goldink`, `bg-brand`, `text-ok`, `text-bad`, and their `/alpha` modifiers. Build command `bin/rails tailwindcss:build`; watch command `bin/rails tailwindcss:watch`.

- [ ] **Step 1: Write the failing test**

```ruby
# spec/assets/tailwind_build_spec.rb
require "rails_helper"

RSpec.describe "Tailwind build" do
  let(:css) { Rails.root.join("app/assets/builds/tailwind.css").read }

  it "defines the design tokens" do
    expect(css).to include("--color-gold")
    expect(css).to include("--color-surface2")
    expect(css).to include("--color-goldink")
  end

  it "defines both theme states" do
    expect(css).to include("prefers-color-scheme: dark")
    expect(css).to include('[data-theme="dark"]')
  end

  it "omits preflight so admin.css still applies" do
    expect(css).not_to include("-webkit-text-size-adjust")
  end

  it "emits utilities for classes used only in Ruby helpers" do
    expect(css).to include(".badge-gold")
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec rspec spec/assets/tailwind_build_spec.rb`
Expected: FAIL — `Errno::ENOENT`, no such file `app/assets/builds/tailwind.css`.

- [ ] **Step 3: Add the gem and run the installer**

```bash
bundle add tailwindcss-rails
bin/rails tailwindcss:install
```

Then undo anything the installer touched outside the admin surface: it may add `app/views/layouts/application.html.erb`, a `Procfile.dev` and a `bin/dev`. This app is not `api_only` but has no application layout, and the documented dev loop is `bin/rails s`. Delete all three if created.

- [ ] **Step 4: Write `app/assets/stylesheets/application.tailwind.css`**

Four parts, in this order:

1. Imports that **exclude preflight**, so `admin.css` survives this task:
   `@import "tailwindcss/theme" layer(theme);` then `@import "tailwindcss/utilities" layer(utilities);`
2. `@source "../../views";` and `@source "../../helpers";` — the helper path is not optional. `Admin::UiHelper` emits `.badge-*` class names from Ruby, and without that line Tailwind never sees them and purges them.
3. The `@theme` block mapping the eleven `--color-*` names to `rgb(var(--token))`, exactly as the spec lists them.
4. The channel-triplet definitions: `:root` with the light values; the dark values twice — once under `@media (prefers-color-scheme: dark)` guarded by `:root:not([data-theme="light"])`, once under `:root[data-theme="dark"]`. Values from the spec's token table. Omit `--stage`.

- [ ] **Step 5: Point the admin head at the build and gitignore it**

In `app/views/admin/shared/_head.html.erb`, add `<%= stylesheet_link_tag "tailwind" %>` **above** the existing `admin.css` link so admin.css still wins on conflicts this task. Add `/app/assets/builds/*` and `!/app/assets/builds/.keep` to `.gitignore`.

- [ ] **Step 6: Build and run the test**

Run: `bin/rails tailwindcss:build && bundle exec rspec spec/assets/tailwind_build_spec.rb`
Expected: PASS, 4 examples.

- [ ] **Step 7: Verify nothing regressed and the image still builds**

Run: `bundle exec rspec spec/requests/admin && bin/rubocop`
Expected: admin specs green; rubocop reports only the two `config/application.rb` offences.

Run: `docker build -f Dockerfile.vercel -t village-platform .`
Expected: success. If bundler cannot resolve the `tailwindcss-ruby` platform gem, run `bundle lock --add-platform x86_64-linux` and rebuild. Do **not** add node and do **not** edit the Dockerfile.

- [ ] **Step 8: Commit**

```bash
git add Gemfile Gemfile.lock .gitignore app/assets/stylesheets/application.tailwind.css app/assets/builds/.keep app/views/admin/shared/_head.html.erb spec/assets/tailwind_build_spec.rb
git commit -m "build: add tailwindcss-rails and the admin design token layer"
```

---

### Task 2: Theme persistence

**Files:**
- Create: `app/controllers/admin/theme_controller.rb`
- Modify: `config/routes.rb` (inside `namespace :admin`)
- Modify: `app/views/layouts/admin.html.erb:2`, `app/views/layouts/admin_auth.html.erb:2`
- Modify: `app/helpers/admin/ui_helper.rb`
- Test: `spec/requests/admin/theme_spec.rb`

**Interfaces:**
- Consumes: Task 1's tokens.
- Produces: `Admin::UiHelper#theme_attribute` → `{ "data-theme" => "dark" }` / `{ "data-theme" => "light" }` / `{}`, spread onto `<html>` by both admin layouts. Route helper `admin_theme_path` (PATCH). Cookie name `admin_theme`, values `light` / `dark` only.

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/admin/theme_spec.rb
require "rails_helper"

RSpec.describe "Admin theme", type: :request do
  before { sign_in_admin }

  it "stores a valid preference and renders it on <html>" do
    patch "/admin/theme", params: { theme: "dark" }, headers: { "HTTP_REFERER" => "/admin/firms" }
    expect(response).to redirect_to("/admin/firms")
    get "/admin"
    expect(response.body).to include('data-theme="dark"')
  end

  it "ignores a crafted value and renders no attribute" do
    patch "/admin/theme", params: { theme: '" onload="alert(1)' }
    get "/admin"
    expect(response.body).not_to include("onload")
    expect(response.body).not_to include("data-theme")
  end

  it "falls back to the dashboard when there is no referer" do
    patch "/admin/theme", params: { theme: "light" }
    expect(response).to redirect_to("/admin")
  end

  it "renders no attribute before any choice is made" do
    get "/admin"
    expect(response.body).not_to include("data-theme")
  end

  it "honours the preference on the login page" do
    patch "/admin/theme", params: { theme: "dark" }
    delete "/admin/logout"
    get "/admin/login"
    expect(response.body).to include('data-theme="dark"')
  end
end

RSpec.describe "Admin theme without a session", type: :request do
  it "redirects to login and sets no cookie" do
    patch "/admin/theme", params: { theme: "dark" }
    expect(response).to redirect_to("/admin/login")
    expect(cookies["admin_theme"]).to be_blank
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec rspec spec/requests/admin/theme_spec.rb`
Expected: FAIL — no route matches `PATCH /admin/theme`.

- [ ] **Step 3: Add the route**

In `config/routes.rb`, inside `namespace :admin`: `patch "theme", to: "theme#update", as: :theme`.

- [ ] **Step 4: Implement `Admin::ThemeController#update`**

`Admin::ThemeController < Admin::BaseController`, so the existing `super_admin?` re-check guards it. `update` permits `params[:theme]` against `%w[ light dark ]`; a member sets `cookies.permanent[:admin_theme]`, anything else calls `cookies.delete(:admin_theme)`. Then `redirect_back fallback_location: admin_root_path`. The allowlist is the security control named in the spec — the value is interpolated into an HTML attribute.

- [ ] **Step 5: Implement `Admin::UiHelper#theme_attribute` and use it**

Returns a hash: `{ "data-theme" => value }` when the cookie is `light` or `dark`, `{}` otherwise. Spread it onto the `<html>` tag in both `layouts/admin.html.erb` and `layouts/admin_auth.html.erb`, keeping `lang="ar" dir="rtl"`.

- [ ] **Step 6: Run the tests**

Run: `bundle exec rspec spec/requests/admin/theme_spec.rb`
Expected: PASS, 6 examples.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/admin/theme_controller.rb app/helpers/admin/ui_helper.rb app/views/layouts/admin.html.erb app/views/layouts/admin_auth.html.erb spec/requests/admin/theme_spec.rb
git commit -m "feat(admin): persist the light/dark theme preference in a cookie"
```

---

### Task 3: Component layer, shell and helpers

The look changes here. Keeping the old class names in the new component layer is what lets the twenty views keep rendering unmodified; Tasks 4-7 then adjust markup screen by screen.

**Files:**
- Modify: `app/assets/stylesheets/application.tailwind.css`
- Delete: `app/assets/stylesheets/admin.css`
- Modify: `app/views/layouts/admin.html.erb`, `app/views/admin/shared/_head.html.erb`
- Modify: `app/helpers/admin/ui_helper.rb`
- Test: `spec/requests/admin/shell_spec.rb`, and `spec/assets/tailwind_build_spec.rb` (preflight expectation inverts)

**Interfaces:**
- Consumes: Task 1's tokens, Task 2's `theme_attribute`.
- Produces, for Tasks 4-7:
  - Component classes: `.card`, `.btn` / `.btn-ghost` / `.btn-danger`, `.badge-green` / `.badge-gold` / `.badge-red` / `.badge-gray`, `.stat` / `.stat-hi`, `.tbl`, `.tab` / `.tab-on`, `.lbl` / `.input` / `.select`, `.switch`, `.actions-row`, `.brand-mark`.
  - `page_header(title, subtitle: nil, &block)` — **the icon argument is gone**; sets `content_for(:title)` and `content_for(:subtitle)`, and renders the block into `.actions-row`.
  - `nav_group(label, &block)` wrapping `nav_link(label, path, icon_name, exact: false, count: nil)`.
  - `badge(text, tone)` where tone is one of `green` / `gold` / `red` / `gray`.
  - `switch(value)` — read-only inline toggle.
  - `theme_toggle` — a `button_to` pair to `admin_theme_path`.
  - `brand_mark(size:)` — renders both marks, CSS shows one per theme.

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/admin/shell_spec.rb
require "rails_helper"

RSpec.describe "Admin shell", type: :request do
  before { sign_in_admin }

  it "renders the grouped sidebar with the design's vocabulary" do
    get "/admin"
    %w[ عام المحتوى الأشخاص المالية التصنيفات الأنشطة الباقات\ والأسعار ].each do |label|
      expect(response.body).to include(label)
    end
  end

  it "renders the topbar chrome" do
    get "/admin"
    expect(response.body).to include("ابحث عن نشاط، مستخدم، دفعة")
    expect(response.body).to include(admin_logout_path)
  end

  it "renders both brand marks so one shows per theme" do
    get "/admin"
    expect(response.body).to include("/brand/web/mark.png")
    expect(response.body).to include("/brand/web/mark-light.png")
  end

  it "renders a theme toggle" do
    get "/admin"
    expect(response.body).to include(admin_theme_path)
  end

  it "shows a theme-aware mark in empty states" do
    get "/admin/users", params: { q: "nothing-matches-this" }
    expect(response.body).to include("/brand/web/mark-light.png")
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec rspec spec/requests/admin/shell_spec.rb`
Expected: FAIL — sidebar still renders `المنشآت` / `الأقسام`, and only `mark-light.png`.

- [ ] **Step 3: Port the components into `@layer components`**

Switch the imports to the full `@import "tailwindcss";` (preflight on) and add an `@layer components` block implementing every class in the Interfaces list with `@apply`, taking the visual values from the spec's component section: `.card` is `bg-surface border border-line rounded-xl`; `.tbl` headers are `bg-surface2` with 10px muted start-aligned labels and `divide-y divide-line` rows; `.stat-hi` is `bg-gold/15 border-gold/40`; badges use `bg-ok/10 text-ok`, `bg-gold/20 text-goldink`, `bg-bad/10 text-bad`, `bg-surface2 text-muted`.

Two rules cannot be utilities and stay as plain CSS in this file: the mobile drawer's `body.nav-open .sidebar { transform: none }` descendant rule, and `.brand-mark` theme visibility (`[data-theme="dark"]` and the `prefers-color-scheme` pair showing `mark-light.png`, otherwise `mark.png`).

Then delete `app/assets/stylesheets/admin.css` and its `stylesheet_link_tag "admin"` line, and drop `--img-silhouette` from `_head.html.erb` — the sidebar no longer uses it. Keep `--img-scene`; the login page still does. Add weight `900` to the Cairo font request for the stat values.

- [ ] **Step 4: Rewrite the shell**

`layouts/admin.html.erb`: 200px `bg-surface` sidebar with `border-e border-line`, compact `brand_mark` header with "أجهور الكبرى" / "لوحة الإدارة", the four nav groups from the spec, footer with avatar, role line and logout. Permanent topbar with `content_for(:title)`, `content_for(:subtitle)`, search field, bell and `theme_toggle`. Content area renders `.actions-row`, then flash, then `yield`. Keep the existing inline `<script>` and the `body.nav-open` toggle and backdrop exactly as they are.

- [ ] **Step 5: Update `Admin::UiHelper`**

Collapse `TONES` to the four design tones using the spec's mapping, change `badge`'s default tone from `"muted"` to `"gray"`, and change the `TONES.fetch` fallback in `enum_badge` to `"gray"`. The names `success`, `info`, `danger`, `warning` and `muted` stop existing, so every call site passing one breaks — `app/views/admin/articles/index.html.erb:27,29`, `app/views/admin/dashboard/show.html.erb:89`, and the bare defaults at `articles/index.html.erb:25` and `users/show.html.erb:19`. Tasks 4 and 6 own those fixes; leave them failing here. Rewrite `page_header` without the icon argument. Add `nav_group`, `switch`, `theme_toggle`, `brand_mark`. Change `empty_state` to use `brand_mark` instead of the hardcoded `mark.png` — Review Focus item 5. Leave `egp`, `fmt_time`, `fmt_date`, `enum_label`, `enum_options`, `initials`, `filter_params`, `yes_no_badge` alone.

- [ ] **Step 6: Invert the preflight expectation in the build spec**

In `spec/assets/tailwind_build_spec.rb`, the "omits preflight" example becomes "includes preflight": expect `-webkit-text-size-adjust` to be present.

- [ ] **Step 7: Run the tests**

Run: `bin/rails tailwindcss:build && bundle exec rspec spec/assets spec/requests/admin`
Expected: PASS. `page_header` lost an argument, so any view still passing an icon raises — fixing those call sites is Tasks 4-7, so expect failures there and resolve them by passing the new signature with the icon dropped.

- [ ] **Step 8: Commit**

```bash
git add -A app/assets app/views/layouts/admin.html.erb app/views/admin/shared/_head.html.erb app/helpers/admin/ui_helper.rb spec/assets spec/requests/admin/shell_spec.rb
git commit -m "feat(admin): rebuild the shell and component layer on the new design"
```

---

### Task 4: Dashboard

**Files:**
- Modify: `app/controllers/admin/dashboard_controller.rb`
- Modify: `app/views/admin/dashboard/show.html.erb`
- Test: `spec/requests/admin/dashboard_spec.rb`

**Interfaces:**
- Consumes: Task 3's `.stat` / `.stat-hi` / `.card` / `.tbl` and `page_header`.
- Produces: `@stats` gains no keys; new `@firms_by_category` → `Array<[String, Integer]>`, category name and visible-firm count, descending.

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/admin/dashboard_spec.rb
require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  before { sign_in_admin }

  it "renders the four stat tiles" do
    get "/admin"
    [ "إجمالي الأهالي", "الأنشطة المسجلة", "الاشتراكات الفعالة", "المقالات المنشورة" ].each do |label|
      expect(response.body).to include(label)
    end
  end

  it "renders the action card" do
    get "/admin"
    expect(response.body).to include("تحتاج إجراءك")
  end

  it "counts visible firms per category" do
    firm = create(:firm)
    create(:firm, category: firm.category, owner: firm.owner)
    get "/admin"
    expect(response.body).to include(firm.category.name)
  end

  it "renders without raising when there are no firms at all" do
    get "/admin"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("لا توجد أنشطة بعد")
  end

  it "does not render a revenue tile" do
    get "/admin"
    expect(response.body).not_to include("الإيرادات")
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec rspec spec/requests/admin/dashboard_spec.rb`
Expected: FAIL — the view still renders the hero and six icon tiles.

- [ ] **Step 3: Add the aggregate to `DashboardController#show`**

One grouped query joined to category names, ordered by count descending:
`@firms_by_category = Firm.visible.joins(:category).group("categories.name").order(count: :desc).count.to_a`.
Leave the six `@stats` counts and the three collections untouched.

- [ ] **Step 4: Rewrite `dashboard/show.html.erb`**

Drop the `.hero` section entirely. Then, per the spec:

- Four `.stat` tiles — إجمالي الأهالي (`:users`, `.stat-hi`), الأنشطة المسجلة (`Firm.count` via `@stats`, sub-line `:pending_firms`), الاشتراكات الفعالة (`:current_subscriptions`), المقالات المنشورة (`:published_articles`). Keep each tile a `link_to` as today.
- A "تحتاج إجراءك" card listing pending subscriptions, pending firms and expiring-this-week, each row linking to its filtered index.
- A category bars card over `@firms_by_category`. Bar width is `value / max * 100`, and **`max` is nil when the set is empty** — render `empty_state("لا توجد أنشطة بعد")` instead of computing a width. This is Review Focus item 4.
- The three existing tables, restyled to `.tbl`, with their content and links unchanged — except `show.html.erb:89`, whose `badge(..., "danger" / "warning")` becomes `"red"` / `"gold"` now that Task 3 retired those tone names.

No revenue tile and no activity feed; the spec explains why.

- [ ] **Step 5: Run the tests**

Run: `bundle exec rspec spec/requests/admin/dashboard_spec.rb spec/requests/admin/brand_assets_spec.rb`
Expected: PASS. `brand_assets_spec` matters here — it scans `/admin`'s HTML for `/brand/web/*` and asserts the set is non-empty, so the sidebar marks must still be referenced after the hero is gone.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/dashboard_controller.rb app/views/admin/dashboard/show.html.erb spec/requests/admin/dashboard_spec.rb
git commit -m "feat(admin): re-cut the dashboard onto the new design"
```

---

### Task 5: Firms and subscriptions screens

The two review-heavy screens, and the only ones whose enum filter becomes the design's tab row.

**Files:**
- Modify: `app/views/admin/firms/{index,show,new,edit,_form}.html.erb`
- Modify: `app/views/admin/subscriptions/{index,show}.html.erb`
- Test: `spec/requests/admin/pages_spec.rb` and `spec/requests/admin/subscriptions_review_spec.rb` — both unchanged, both must end green

**Interfaces:**
- Consumes: Task 3's components, `page_header(title, subtitle:)`, `switch(value)`, `badge(text, tone)` with the four new tones.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Run the existing specs to see the red**

Run: `bundle exec rspec spec/requests/admin/pages_spec.rb spec/requests/admin/subscriptions_review_spec.rb`
Expected: FAIL — these views still call `page_header` with the icon argument Task 3 removed.

- [ ] **Step 2: Convert `firms/index.html.erb`**

`page_header "الأنشطة", subtitle:` with the firm count. The status filter becomes a `.tab` row of `link_to`s built with `filter_params(status: …)` — الكل / قيد المراجعة / نشط / موقوف — with the `q` search field and the category `.select` inline beside it. The table becomes `.tbl`. The "ظاهرة للجمهور" cell becomes `switch(@visible_ids.include?(firm.id))`. Row actions become the pill-styled set. Every path, HTTP method and `data-confirm` stays byte-identical: approve, suspend and edit must not change behaviour.

- [ ] **Step 3: Convert `firms/{show,new,edit,_form}.html.erb`**

`.card` wrappers, `.lbl` / `.input` / `.select` fields, `dl.details` restyled to the new type scale. `_form`'s field names and the `form_with` url stay as they are — `crud_spec` asserts a real create and update.

- [ ] **Step 4: Convert `subscriptions/index.html.erb`**

Same treatment: the status filter becomes the `.tab` row, `payment_method` and `q` stay as inline controls, table becomes `.tbl`. Keep the `state` and `status` columns distinct — they are different concepts, as the spec's domain notes say.

- [ ] **Step 5: Convert `subscriptions/show.html.erb`**

`.card` sections. The screenshot link and the approve/reject forms keep their paths and confirmations untouched; `ScreenshotRedirect`, `Subscriptions::Approve` and `Subscriptions::Reject` are not part of this change.

- [ ] **Step 6: Run the tests**

Run: `bundle exec rspec spec/requests/admin`
Expected: `pages_spec`, `subscriptions_review_spec`, `shell_spec`, `theme_spec`, `dashboard_spec` and `brand_assets_spec` green. `crud_spec` may still fail on the four screens Task 6 owns.

- [ ] **Step 7: Commit**

```bash
git add app/views/admin/firms app/views/admin/subscriptions
git commit -m "feat(admin): restyle the firms and subscriptions screens"
```

---

### Task 6: Users, categories, articles, plans and shared partials

**Files:**
- Modify: `app/views/admin/users/{index,show,new,edit,_form}.html.erb`
- Modify: `app/views/admin/categories/{index,new,edit,_form}.html.erb`
- Modify: `app/views/admin/articles/{index,new,edit,_form}.html.erb`
- Modify: `app/views/admin/subscription_plans/{index,new,edit,_form}.html.erb`
- Modify: `app/views/admin/shared/{_errors,_pagination}.html.erb`
- Test: `spec/requests/admin/pages_spec.rb` and `spec/requests/admin/crud_spec.rb` — both unchanged, both must end green

**Interfaces:**
- Consumes: Task 3's components and helpers.
- Produces: nothing.

- [ ] **Step 1: Convert the users screens**

`index`: `page_header "المستخدمون", subtitle:`; the `role` select becomes a `.tab` row via `filter_params(role: …)` with the `q` field inline; columns (الاسم / الهاتف / البريد / الصلاحية / تاريخ التسجيل) keep their order, and the phone keeps its `ltr` treatment. `show`, `new`, `edit`, `_form`: `.card` and the new field classes. Fix the bare `badge("لا يوجد")` at `show.html.erb:19` — it now resolves to the `gray` default from Task 3, so only confirm it renders.

- [ ] **Step 2: Convert the categories screens**

`page_header "التصنيفات", subtitle:` — the design's label, replacing "الأقسام". The index has no filter form, so no tab row. `yes_no_badge(category.active)` becomes `switch(category.active)` to match the design's inline toggle. Keep the position column and the destroy action, whose `dependent: :restrict_with_error` message surfaces through `destroy_and_redirect`.

- [ ] **Step 3: Convert the articles screens**

`page_header "الأخبار والمقالات", subtitle:` — the design's label. The `kind` select becomes the `.tab` row, `q` stays inline. **Retone the three status badges**, which Task 3 broke: line 25's bare `badge("مسودة")` now defaults to `gray`, line 27's `"success"` becomes `"green"`, line 29's `"info"` becomes `"gold"` — the design has no blue.

- [ ] **Step 4: Convert the subscription plans screens**

`page_header "الباقات والأسعار", subtitle:` — the design's label, replacing "باقات الاشتراك". No filter form. `yes_no_badge(plan.active)` becomes `switch(plan.active)`. `egp` keeps formatting the price.

- [ ] **Step 5: Convert the shared partials**

`_errors` becomes a `bg-bad/10 text-bad` card. `_pagination` keeps its `filter_params` links as `.btn-ghost` pills and still takes `meta:`.

- [ ] **Step 6: Run the tests and confirm the old tones are gone**

Run: `bundle exec rspec spec/requests/admin`
Expected: PASS, every admin spec.

Run: `grep -rnE 'badge\((.*"(success|info|danger|warning|muted)")' app/views app/helpers`
Expected: no output. Any hit is a badge that silently renders unstyled.

- [ ] **Step 7: Commit**

```bash
git add app/views/admin/users app/views/admin/categories app/views/admin/articles app/views/admin/subscription_plans app/views/admin/shared
git commit -m "feat(admin): restyle the remaining index, form and shared views"
```

---

### Task 7: Login page and whole-change verification

**Files:**
- Modify: `app/views/admin/sessions/new.html.erb`, `app/views/layouts/admin_auth.html.erb`
- Modify: `CLAUDE.md`
- Test: `spec/requests/admin/sessions_spec.rb` (unchanged, must stay green)

**Interfaces:**
- Consumes: everything above.
- Produces: nothing.

- [ ] **Step 1: Reskin the login page**

The artifact specifies no admin login, so keep the two-column visual layout and re-express it with the tokens: `.auth` grid, the `--img-scene` panel, and the form card using `.card` / `.lbl` / `.input` / `.btn`. It keeps `/brand/web/scene.jpg` and `logo.png`, and it honours `data-theme` from Task 2 but shows no toggle.

- [ ] **Step 2: Update `CLAUDE.md`**

In **Commands**, add `bin/rails tailwindcss:watch` beside `bin/rails s` and note that CSS is built by `assets:precompile` in the image. In **Architecture**, replace "one hand-written stylesheet (`app/assets/stylesheets/admin.css`)" with the Tailwind source and token layer, and record that the admin has light/dark themes driven by the `admin_theme` cookie. Keep "deliberately no admin gem and no JS framework" — it is still true.

- [ ] **Step 3: Run the full suite**

Run: `bundle exec rspec`
Expected: PASS except the five known pre-existing failures — four in `spec/seeds_spec.rb`, one DST case in `spec/jobs/subscription_expiry_reminders_job_spec.rb`. Any sixth failure belongs to this change and must be fixed.

- [ ] **Step 4: Run the static checks and the image build**

Run: `bin/rubocop && bundle exec brakeman -q --no-pager`
Expected: rubocop reports only the two `config/application.rb` offences; brakeman reports no new warning. The theme cookie is the one new user-controlled value reaching HTML — if brakeman flags it, the allowlist in Task 2 is not doing its job.

Run: `docker build -f Dockerfile.vercel -t village-platform .`
Expected: success, with `tailwindcss:build` running inside `assets:precompile`.

- [ ] **Step 5: Commit**

```bash
git add app/views/admin/sessions app/views/layouts/admin_auth.html.erb CLAUDE.md
git commit -m "feat(admin): reskin the login page and document the Tailwind workflow"
```
