# Changelog

All notable changes to **PriceTracker (Smart Shopping List)** are documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Refresh batch observability.** Each cron/manual refresh creates a
  `price_refresh_runs` row; GitHub Actions polls `GET /admin/refresh_runs/:id`
  and writes attempted/succeeded/failed counts, duration, and failure details
  to the run **Summary** tab.
- **Real PDP seed catalog.** [`db/seeds/real_product_catalog.rb`](db/seeds/real_product_catalog.rb)
  (49 retailer product URLs) replaces `example.com` placeholders and `/search?`
  links in `db/seeds.rb`. Production-safe
  `paginationtest:reseed_real_urls` rake task updates only the Pagy stress-test
  account on Heroku.

### Changed
- **Async batched nightly refresh (P0).** `/admin/refresh_prices` returns 202 and
  enqueues `RefreshPricesJob`; `RefreshSchedule` auto-sizes batches across a
  2-hour UTC window (24 ticks). Heroku 30s HTTP limit no longer applies to the
  scrape work itself.
- **`Product.scrapeable` scope.** Cron batches skip non-PDP URLs (`example.com`,
  retailer search pages). `RefreshSchedule.batch_size` counts scrapeable products
  only.
- **GitHub Actions refresh workflow** waits for batch completion (poll + Summary)
  instead of treating HTTP 202 alone as success.

### Fixed
- Daily refresh 503 at stress-test scale (1265+ products) by moving work off the
  synchronous request path.
- CI tests for advisory-lock overlap, `REFRESH_BATCH_MAX`, and scrapeable-aware
  `refresh_batch` specs.

## [v1.1.0] — 2026-05-17 — Milestone 2 (UI + auto-scrape + notifications)

Second milestone release. Three big themes drive this release: a full UI
refresh, automatic daily price refresh without anyone clicking *Fetch latest
price*, and a complete price-drop alert pipeline (target-price + history-low)
with in-app banner / card chips and a ready-to-send mailer.

Deployed at <https://smart-shoppinglist-6ae31171e85c.herokuapp.com/>.

Tag: [`v1.1.0`](https://github.com/NU-CS-Software-Studio-Spring-26/project-smart-shopping-list/releases/tag/v1.1.0)

### Added
- **Automatic daily price refresh.** A GitHub Actions cron workflow runs
  daily at 09:00 UTC and `POST`s to a token-protected `/admin/refresh_prices`
  webhook on the deployed app, which re-scrapes every product with a
  `source_url`. New `PriceRecord` rows are written **only when the price has
  actually changed**, so the chart isn't polluted with duplicate observations.
  Per-product failures (timeouts, 403 from bot-managed sites, unparseable HTML)
  are captured in `last_fetch_error` and never crash the run. Picked over a
  Heroku worker + Solid Queue stack to stay free under the GitHub Student
  credit and remain portable if we ever migrate off Heroku — only `APP_URL`
  would need to change. See `docs/scrapers.md` and `wiki.md` § Scheduled tasks.
- **Target-price + history-low price-drop alerts.** Each product can carry an
  optional "notify me when price drops to $X" threshold. Whenever a new
  `PriceRecord` is written — by cron, by the manual *Fetch latest* button, or
  by hand — `PriceAlerter`:
  1. Returns no-op if an alert fired within the last 24 hours (cooldown).
  2. Computes reasons: `target_hit` (price ≤ target) and `history_low`
     (strictly below every previous record for this product).
  3. Renders and enqueues a `PriceAlertMailer.price_drop` email.
  4. Stamps `product.last_alerted_at = Time.current`.
  In-app surfaces are live without an SMTP provider: a green
  **"PRICE ALERT TRIGGERED"** banner on the product show page (7-day window)
  with trigger price + store + current target, a **"🎯 Notify at $X"** row in
  the side meta, and per-card chips on the products index ("🎉 Alert fired
  Nd ago" or "🎯 Notify at $X"). Outbound SMTP wiring is intentionally
  deferred to a future release — templates render correctly via mailer
  previews; only provider credentials are missing.
- **Apple-style ledger UI redesign.** Full visual refresh of the product list,
  product detail, price-record forms, and global chrome. Includes a hero CTA
  on the products list, a lowest-price pin on the detail page, a "savings"
  chip on each card when the latest price is above the lowest, custom-branded
  `404` / `422` / `500` / `406` error pages, and a P/T favicon.
- **Price-history charts** for every product, including ones with a single
  recorded observation; chart includes an accessible text summary that
  describes lowest / highest / first / latest prices for screen readers.
- **Price-trend visualization.** Each product surfaces an up / down / stable
  trend badge based on recent observations.
- **Budget Planner.** New page that takes a budget and recommends candidate
  products against the UPC Item DB API, with category filtering and a clear
  "over budget" indicator (renamed from the original "recommendation system"
  for clarity).
- **About, Privacy, and Terms** pages wired into the footer, with an Unsplash
  hero image on About and documented attribution for all visual assets.
- **Manual product fallback.** When a site can't be auto-scraped (Cloudflare,
  Akamai, PerimeterX, JS-rendered prices, …), users can switch the new-product
  form to "Fill in manually" mode and still keep the source URL on file for
  future manual logging.
- **Mobile-responsive layout** across the product grid, detail page, and forms.
- **Auto-submitting filter form** on the products index — changing the
  category or sort select re-runs the search without an extra button press.
- **Auto-dismissing flash notifications** for less visual clutter after success
  actions.
- **Empty states** for the products list (no products yet), the price-history
  ledger (no observations yet), and the search (no matches).

### Accessibility
- Color contrast lifted to **WCAG AA** across muted text, button hover states,
  and badges.
- `lang="en"` on `<html>` for screen-reader language detection.
- "Skip to main content" link for keyboard users.
- ARIA labels and a hidden text summary on the price-history chart so chart
  data is reachable by assistive tech (the same numbers are also rendered as
  a full ledger table below the chart).
- Visible "Over budget" badge + ARIA labels on Budget Planner cards.
- More descriptive product-card link labels ("View details for <name>" instead
  of a bare "View").

### Security
- **Password strength** rules: minimum length, one special character, no
  repeated character runs, must not equal the user's email, must not match the
  common-password blocklist.
- **Rate-limited registrations** mirror the existing sign-in rate limit
  (10 attempts / 3 minutes).
- `nokogiri` bumped to 1.19.3 to clear an open bundler-audit advisory.
- Brakeman ignore-list refreshed against the redesigned views — zero remaining
  warnings on `main`.
- The new `/admin/refresh_prices` endpoint is gated by a shared secret
  (`X-Admin-Token` header), compared in constant time via
  `ActiveSupport::SecurityUtils.secure_compare`, with CSRF skipped only on
  that single action.

### Documentation
- `docs/scrapers.md` rewritten with a Mermaid diagram of the daily-refresh
  pipeline, request flow, one-time setup, troubleshooting, and a cost analysis
  vs. the Heroku Scheduler / Solid Queue alternatives.
- `wiki.md` gains **Scheduled tasks** and **Price-drop alerts** sections with
  full pipeline diagrams, UI touch-points, and implementation notes.
- `README.md` adds top-level **Automatic daily price refresh** and
  **Target price + price-drop alerts** sections aligned with the new docs.
- Known-blocker docs for Cloudflare/Akamai, PerimeterX/URBN, and Target's CSR
  rollout so future contributors don't burn time chasing sites that block
  server-side scraping by design.
- Visual-asset sourcing and licensing documented in `wiki.md`.

### Tests
- 31 new tests for `PriceAlerter`, `PriceAlertMailer`, and the
  `PriceRecord.after_create_commit` integration (cooldown, target-hit,
  history-low, combined-reason, no-target, no-records-yet edge cases).
- 12 new tests for the alert UI: `target_price` round-trips through
  `PATCH /products/:id`, banner visibility on `show`, card chips on `index`.
- New `AdminController` test suite covering happy-path, missing-token,
  wrong-token, and unset-`ENV` refresh requests.
- New `PriceFetcher.refresh_all` tests for the summary return value
  (`succeeded` / `failed` / `duration`) and isolation of per-product failures.
- Comprehensive authentication test suite covering session, redirect,
  password-reset, and cross-user authorization paths.
- All suites preserved on PostgreSQL through CI on every push and PR.

## [v1.0.0] — 2026-04-29 — Milestone 1 (MVP)

First public release. The application is deployed on Heroku at
<https://smart-shoppinglist-6ae31171e85c.herokuapp.com/> and supports a complete
end-to-end "happy path" for tracking product prices.

Tag: [`v1.0.0`](https://github.com/NU-CS-Software-Studio-Spring-26/project-smart-shopping-list/releases/tag/v1.0.0)

### Added
- User accounts with email + password (`has_secure_password`), session-cookie auth,
  signup / sign-in / sign-out flows, and password reset.
- Products CRUD scoped to the current user — no user can read or mutate another
  user's products or price records.
- Manual price entry: per-product price history table with store, date, notes,
  and optional store URL.
- Automatic price scraping from a product page URL:
  - Adapter pattern with a registry (`app/services/price_scrapers/`).
  - Generic `JsonLdAdapter` that supports any site exposing `schema.org` Product
    JSON-LD (Target, Walmart, Best Buy, Lululemon, Nike, etc.).
  - Site-specific `AmazonAdapter` for Amazon's CSS-driven layout.
  - First scrape happens synchronously on product creation; users only need to
    paste a URL + pick a category, and the title / image / first price are
    fetched automatically.
  - Manual "Fetch latest price" button on each product detail page.
  - Price deduping: a new `PriceRecord` is only created when the scraped price
    actually differs from the last scraped price for that product.
  - Heroku Scheduler-friendly `PriceFetcher.refresh_stale` task for off-process
    refreshes (no extra worker dyno required).
- Products list page: case-insensitive multi-token search across name,
  category, and description.
- Bootstrap-based responsive UI with consistent global header, footer, primary
  CTA, and flash styling. Empty states for products list and price history.
- Database schema documentation in `docs/database.md` and full scraper
  architecture reference in `docs/scrapers.md`.
- CI on every push and PR: RuboCop lint, Brakeman static analysis,
  bundler-audit, importmap audit, and the full Minitest suite against PostgreSQL.

### Security
- Secrets (Rails master key, third-party API keys) are stored in environment
  variables / encrypted credentials only — never committed to the repository.
- Authentication is rate-limited (10 attempts / 3 minutes) and CSRF-protected.
- Failed login responses are intentionally generic so they cannot be used to
  enumerate which email addresses exist.
