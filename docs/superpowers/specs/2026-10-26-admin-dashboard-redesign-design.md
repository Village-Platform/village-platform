# Admin dashboard redesign — design

Date: 2026-10-26
Status: approved, pending implementation plan
Source design: Claude artifact `Qyu6AukTyKaUvUcV6Sc4ws` ("أجهور الكبرى — تصميم الشاشات"), admin half

## Goal

Bring `/admin/*` onto the design system defined in the artifact: its token layer, its light/dark
themes, its density and its component vocabulary. The eight screens that exist today are restyled;
no schema, no API and no domain behaviour changes.

The artifact also contains thirteen Android screens and six admin screens with no backend. Both are
out of scope here (see **Out of scope**).

## Decisions

| Decision | Choice | Why |
| --- | --- | --- |
| CSS strategy | `tailwindcss-rails` | Chosen by the maintainer over a hand-written semantic stylesheet, with the duplication cost understood and mitigated by the component layer below. |
| Tailwind version | v4 (gem default) | The artifact uses the v3 CDN with a JS config, but adopting a legacy major in a new integration is debt from day one. Translation cost is one `@theme` block, because the artifact carries no `dark:` variants. |
| Theme switching | Redefine tokens under `[data-theme]` | One definition site for colour. Every utility flips with no conditional classes. |
| Theme persistence | Server-read cookie | The theme is known before the first byte, so there is no flash of the wrong theme and no blocking JS in `<head>`. |
| Numerals | Latin | Chosen by the maintainer. Arabic-Indic digits are not introduced anywhere, including stat tiles and dates. |
| Icons | Keep the existing inline SVGs | The artifact uses emoji, which cannot take `currentColor` (so they will not go gold on the active nav item or cream in dark mode) and render differently per OS. `Admin::IconsHelper` already covers every nav entry. |
| Admin vocabulary | Adopt the artifact's labels in views only | Admin copy is hardcoded Arabic by project convention. `config/locales/ar.yml` is **not** touched, because those strings ship to the Android client and renaming them is a client-contract change. |

## Build and dependency changes

`tailwindcss-rails` depends on `tailwindcss-ruby`, which ships a precompiled standalone binary.
**No node is added** — `Dockerfile.vercel` has none and must not gain one.

Verified before approval:

- `Gemfile.lock` declares exactly one platform, `x86_64-linux-gnu`, and the production image is
  x86_64 (`LD_PRELOAD` hardcodes `/usr/lib/x86_64-linux-gnu/...`). Same target, so the platform gem
  resolves under `BUNDLE_DEPLOYMENT=1`.
- The build stage already runs `SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile`, and the gem
  hooks `tailwindcss:build` onto that task. **No Dockerfile change is expected.**

Not yet verified, and therefore the first implementation step:

    docker build -f Dockerfile.vercel -t village-platform .

If the platform gem fails to resolve, the fix is `bundle lock --add-platform x86_64-linux` — not a
Dockerfile change and not a switch to node.

Files:

- `app/assets/stylesheets/application.tailwind.css` — new source: `@import "tailwindcss"`, the
  `@theme` block, the `[data-theme]` definitions, and `@layer components`.
- `app/assets/builds/` — gitignored with a kept `.keep`; add `/app/assets/builds/*` and
  `!/app/assets/builds/.keep` to `.gitignore`.
- `app/assets/stylesheets/admin.css` — deleted. Its palette becomes tokens; its components become
  `@apply`.
- `app/views/admin/shared/_head.html.erb` — `stylesheet_link_tag "tailwind"`; the `--img-scene`
  and `--img-silhouette` block shrinks to `--img-scene` only (the login page still uses it); the
  Cairo request gains weight 900, which the artifact's `font-black` stat values need.
- `CLAUDE.md` — document `bin/rails tailwindcss:watch` for the dev loop. Deliberately no `foreman`
  and no `bin/dev`; the documented workflow stays `bin/rails s`.

## Token layer

Ported verbatim from the artifact as rgb channel triplets, mapped once in `@theme`:

```css
@theme {
  --color-page: rgb(var(--page));
  --color-surface: rgb(var(--surface));
  --color-surface2: rgb(var(--surface2));
  --color-ink: rgb(var(--ink));
  --color-muted: rgb(var(--muted));
  --color-line: rgb(var(--line));
  --color-gold: rgb(var(--gold));
  --color-goldink: rgb(var(--goldink));
  --color-brand: rgb(var(--brand));
  --color-ok: rgb(var(--ok));
  --color-bad: rgb(var(--bad));
}
```

| Token | Light | Dark | Used for |
| --- | --- | --- | --- |
| `page` | `255 255 255` | `8 40 28` | app background |
| `surface` | `255 255 255` | `13 52 37` | cards, sidebar, topbar |
| `surface2` | `245 245 245` | `18 64 47` | inputs, table headers |
| `ink` | `0 0 0` | `244 236 217` | body text |
| `muted` | `82 82 82` | `157 181 168` | labels, secondary text |
| `line` | `226 226 226` | `29 77 58` | borders, dividers |
| `gold` | `194 141 64` | `217 164 88` | primary action, active nav |
| `goldink` | `122 85 22` | `232 192 126` | gold-on-surface text |
| `brand` | `11 55 39` | `244 236 217` | icon tile tints (`bg-brand/10`) |
| `ok` | `31 122 77` | `95 207 147` | success badges |
| `bad` | `179 64 47` | `255 141 122` | danger badges, counts |

The artifact's `--stage` token is omitted: it backs the phone frame on the Android mockup pages and
has no admin use.

Opacity modifiers (`bg-gold/15`, `bg-ok/10`) work unchanged — v4 compiles them to `color-mix()`
against the resolved value, so channel triplets are not required for alpha, only convenient for the
theme swap.

### Theme resolution

Three states, one more than the artifact shows:

| Cookie `admin_theme` | `<html>` attribute | Result |
| --- | --- | --- |
| absent | none | follows `prefers-color-scheme` |
| `light` | `data-theme="light"` | forced light |
| `dark` | `data-theme="dark"` | forced dark |

The dark block is declared twice: once under `@media (prefers-color-scheme: dark)` guarded by
`:root:not([data-theme="light"])`, and once under `:root[data-theme="dark"]`. Without the guard, an
explicit light choice loses to a dark OS.

### Theme endpoint

- Route: `patch "theme", to: "theme#update", as: :theme` inside `namespace :admin`.
- `Admin::ThemeController < Admin::BaseController` — requires a signed-in super admin like every
  other admin controller.
- `update` writes `cookies.permanent[:admin_theme]` and `redirect_back fallback_location: admin_root_path`.
- **The value is validated against `%w[light dark]` and anything else clears the cookie.** The
  cookie is interpolated into an HTML attribute (`<html data-theme="...">`), so an unvalidated
  value is an attribute-injection vector.
- The toggle is a `button_to` in the shell topbar, so it carries CSRF protection and needs no JS.
  The login page reads the cookie but shows no toggle — `Admin::SessionsController` sits outside
  `BaseController` and cannot require an admin. `layouts/admin_auth.html.erb` renders the same
  `admin/shared/_head` partial and gains the same `data-theme` attribute, so the login page honours
  a stored preference.

A full page reload per toggle is accepted; this is a preference switch, not an interaction.

## Component layer

Utility-first duplicates class strings across views, so every pattern used more than twice becomes
an `@apply` component in `@layer components`. A tint change stays a one-file edit.

`.card`, `.btn` / `.btn-ghost` / `.btn-danger`, `.badge-green` / `.badge-gold` / `.badge-red` /
`.badge-gray`, `.stat` / `.stat-hi`, `.tbl` (header `bg-surface2`, 10px muted start-aligned labels,
`divide-y divide-line` rows), `.tab` / `.tab-on`, `.lbl` / `.input` / `.select`, `.switch`.

Page-specific arrangement (`grid-cols-3`, `col-span-2`, gaps) stays inline utilities — that is what
they are good at.

Row actions render as real `<button>` / `<a>` elements styled as the artifact's pills. The artifact
uses `<span>`; real elements keep them keyboard-reachable and, via `button_to`, CSRF-protected.

## Shell

`app/views/layouts/admin.html.erb`:

- `<html lang="ar" dir="rtl" data-theme="...">` from the cookie.
- Sidebar: 200px (was 264px), `bg-surface` with `border-e border-line` (was a dark-green gradient
  with a silhouette image). Compact mark + "أجهور الكبرى" / "لوحة الإدارة", grouped nav, footer with
  avatar, role line and logout.
- Topbar becomes permanent (it is mobile-only today): page title and subtitle via `content_for`,
  search field, bell, theme toggle.
- Content area: optional actions row, then flash messages, then `yield`.
- The dashboard **hero** and the sidebar silhouette are removed; the design opens onto stat tiles.
- Mobile behaviour is preserved. The sidebar drawer depends on a descendant rule
  (`body.nav-open .sidebar { transform: none }`) that no utility expresses, so those few rules stay
  as a small custom block in the stylesheet rather than moving into utilities.
- The layout's existing inline `<script>` is kept unchanged: `data-confirm` submit guards and the
  mobile nav toggle. No JS framework is introduced.

Nav groups, restricted to sections that have a backend:

- **عام** — لوحة التحكم
- **المحتوى** — التصنيفات · الأنشطة · الأخبار والمقالات
- **الأشخاص** — المستخدمون
- **المالية** — الباقات والأسعار · الاشتراكات

Pending counts stay on الاشتراكات and الأنشطة, rendered as the artifact's `bg-bad` pill.

## Helper changes

`Admin::UiHelper`:

- `TONES` collapses from nine values to the design's four (`green`, `gold`, `red`, `gray`).
  Mapping: `active`/`current`/`super_admin`/`true` → green; `pending`/`scheduled`/`firm_admin`/
  `announcement` → gold; `rejected`/`suspended` → red; everything else → gray.
- `badge` emits `.badge-<tone>`.
- `page_header` loses the icon tile and sets `content_for(:title)` / `content_for(:subtitle)` for
  the topbar; the actions block moves to the content actions row.
- `nav_link` gains a group heading and the new count pill.
- New `switch(value)` renders the design's inline read-only toggle, alongside the existing
  `yes_no_badge`.
- `egp`, `fmt_time`, `fmt_date`, `enum_label`, `enum_options`, `initials`, `filter_params` are
  unchanged.

`Admin::IconsHelper` is unchanged.

## Screens

Seven screens are a mechanical re-cut: filter forms become the artifact's `Tabs` plus inline
selects, tables gain the new header and divider treatment, forms gain `.lbl` / `.input` / `.select`.
Affected views: `firms` (index, show, new, edit, _form), `subscriptions` (index, show), `users`
(index, show, new, edit, _form), `categories`, `articles`, `subscription_plans` (index, new, edit,
_form), and the shared `_errors` / `_pagination` partials.

`sessions/new` and `layouts/admin_auth.html.erb` are not in the artifact. The two-column visual
login is kept and reskinned with the tokens; it continues to use `/brand/web/scene.jpg`.

### Dashboard

`DashboardController#show` currently computes six counts plus three collections. Re-cut as:

- **Four stat tiles** — إجمالي الأهالي (`User.count`, highlighted), الأنشطة المسجلة (`Firm.count`,
  sub-line `pending_firms`), الاشتراكات الفعالة (`current_subscriptions`), المقالات المنشورة
  (`published_articles`).
- **"تحتاج إجراءك" card** — pending subscriptions, pending firms, and expiring-this-week, all from
  counts already computed.
- **Per-category bars** — one added query, `Firm.visible.group(:category_id).count`, joined to
  category names.
- **Two existing tables** restyled: pending subscriptions, expiring subscriptions, pending firms.

Explicitly **not** built, with reasons:

- **Monthly revenue chart and the revenue stat tile.** Not hard, but "revenue" needs decisions that
  are the maintainer's: approved subscriptions only, bucketed by `starts_at` or `reviewed_at`, and
  how renewal stacking attributes a stacked period to a month. A finance question, not a CSS one.
- **Activity feed.** Needs the audit table, which does not exist.

## Testing

The existing request specs are the safety net and should stay green untouched — they assert status
codes and content, not CSS classes.

- `spec/requests/admin/brand_assets_spec.rb` fails if a view references a `/brand/web/*` file absent
  from `public/`. Removing the hero and silhouette must leave no dangling reference; the login page
  keeps `scene.jpg`.
- New: `spec/requests/admin/theme_spec.rb` — a valid value sets the cookie and redirects back; an
  invalid value clears it; the layout renders `data-theme` for `light`/`dark` and omits the
  attribute when the cookie is absent; the endpoint requires a signed-in super admin.
- `bin/rubocop` must report only the two known pre-existing offences in `config/application.rb`.
- Pre-existing failures stay as they are: four in `spec/seeds_spec.rb` and one DST case in
  `spec/jobs/subscription_expiry_reminders_job_spec.rb`. A restyle does not fix them.

## Risks

| Risk | Handling |
| --- | --- |
| Tailwind platform gem fails in the Vercel image | First implementation step is the Docker build; fix with `bundle lock --add-platform`. |
| v4 preflight changes appearance beyond the restyle | `shadow-sm`/`rounded-sm` shifted one step and preflight sets `cursor: default` on buttons; corrected by eye against the artifact. |
| Utility duplication across ~20 views | The `@layer components` inventory above; anything used more than twice is a component. |
| Theme cookie interpolated into an HTML attribute | Allowlist validation in the controller. |
| Vocabulary drift between admin and the Android client | `ar.yml` is untouched; renames are view-only. |

## Out of scope

Captured from the artifact for later, each its own subsystem needing a migration, a policy and an
API review: payments review, reviews and reports, roles and permissions, notification composer,
audit log, settings store, category sub-trees and per-category custom fields, featured firms, media
galleries, CSV export.

Any of these that the Android client reads must ship additively — a released app version cannot be
rolled back.

## Pattern notes

**Design Tokens.** Colour has exactly one definition site; the theme is a swap of that site rather
than a parallel set of classes. This is why dark mode costs ~15 lines instead of a second
stylesheet, and why the artifact needs no `dark:` variants at all.

**Anti-Corruption Layer.** The `@layer components` block is a translation boundary between the
mockup's utility vocabulary and the application's semantic one, which is what keeps a tint change
from becoming a twenty-file edit.

Architect interview questions this change should prepare answers for:

1. You adopted a utility-first CSS framework for a twenty-page admin maintained by one person. Defend
   that to a skeptical CTO who points at the build step and the duplicated class strings.
2. Your theme preference is a server-read cookie rather than client state. What breaks when the app
   sits behind a CDN with full-page caching, and how would you keep the theme correct then?

Reference: Tailwind CSS v4 theme variables — https://tailwindcss.com/docs/theme
