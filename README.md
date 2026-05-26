# PriceTracker (Smart Shopping List)

## Team

Nicole Li, Andrew Xue, Amie Masih, Rahib Taher

## MVP

A web app where signed-in users save products they are watching, record prices seen at different stores, and review them from a simple dashboard. Paste a product link, set a target price, and get in-app plus email notifications when the price hits your target or a new history low.

## Communication

- Weekly meetings on Saturday afternoons, with extra syncs when the app or deadlines need them.
- Decisions are coordinated through those meetings and ongoing chat; the team aims for consensus.
- If consensus is not reached in a reasonable time, decisions are resolved by majority vote.
- Decisions are documented with rationale. Small decisions can be async; blocking or complex issues are raised in meetings or escalated early.
- Choices prioritize simplicity and alignment with the MVP so progress stays steady.

## Links

- **OO design (Miro):** https://miro.com/app/board/uXjVGjU99U8=/
- **Scheduling (When2meet):** https://www.when2meet.com/?36156767-PyTqS
- **Heroku deployment:** https://smart-shoppinglist-6ae31171e85c.herokuapp.com/
- **Supported retailers (in-app):** `/supported` on the deployed app

## Local setup

This app is built on Rails 8.1 and should be run with the Ruby version in
`.ruby-version` (`4.0.4`) plus the Bundler version in `Gemfile.lock` (`4.0.9`).
If `bin/rails` reports macOS system Ruby 2.6, switch your Ruby manager to the
project version before installing gems.

Typical local setup:

```sh
ruby -v
gem install bundler:4.0.9
bundle install
bin/rails db:prepare
bin/rails test
bin/rails server
```

## Seed accounts

After running `bin/rails db:seed` the following accounts are available:

| Email | Password | Notes |
|---|---|---|
| `demo@example.com` | `TrackSave!123` | Full real-product catalog (57 unique PDP URLs) |
| `shopper1@example.com` … `shopper39@example.com` | `Shopper!#{n}A#{((n-1) % 9) + 1}z` | 39 load-test users × 30 products each — catalog cycles so pagination stays >1,000 rows |
| `paginationtest@example.com` | `Pagy123!` | 1,250 products for Pagy stress tests (same real PDP catalog, recreated by `db:seed`) |

All seeded `source_url` values point at **real retailer product detail pages**
(Amazon `/dp/…`, Best Buy `/site/…/….p`, Walmart `/ip/…`, Lululemon, Costco,
Home Depot, etc.).
The canonical list lives in [`db/seeds/real_product_catalog.rb`](db/seeds/real_product_catalog.rb)
(57 unique PDP URLs, cycled for volume). Seeds **do not** use `example.com`
placeholders or retailer `/search?` links.

Re-seed locally with `bin/rails db:seed:replant` (wipes **all** local users/products).

**Production:** never run `db:seed:replant` on Heroku — it would delete real team
accounts. To replace only the pagination stress-test account in place:

```sh
heroku run bin/rails paginationtest:reseed_real_urls -a smart-shoppinglist
```

This task touches **only** `paginationtest@example.com` (1,250 products). All other
users and their manually added products are left unchanged.

Sign in as any `shopperN@example.com` to exercise Pagy pagination (24 products per
page on the index). Pagination is provided by [Pagy](https://github.com/ddnexus/pagy).

Before pushing, run the full local CI gate:

```sh
bin/push-check   # RuboCop, Brakeman, tests, db:seed:replant smoke
```

## Supported retailers

The app tries to auto-fetch prices from any product detail URL. The in-app
**Supported Sites** page (`/supported`, also in the main nav) lists:

- **Tested** — 16 retailers in our seed catalog (including **Lululemon** and
  **Amazon** with dedicated scraping)
- **Also expected** — additional JSON-LD retailers (Costco, Kohl's, Wayfair, …)
- **Manual** — Target and eBay (track the link, enter prices by hand)
- **Limited** — sites that often block cloud/server refreshes

Technical details: [`docs/scrapers.md`](docs/scrapers.md). Retailer data lives in
[`app/helpers/supported_retailers_helper.rb`](app/helpers/supported_retailers_helper.rb).

The default scraper tries **JSON-LD → Open Graph meta → HTML microdata** before
giving up (see `JsonLdAdapter`).

## Automatic daily price refresh

Every **refreshable** product (all scrapeable PDP URLs — team accounts and the
pagination load-test catalog) is re-scraped on a nightly schedule. See
[`Product.refreshable`][refreshable] in `app/models/product.rb`.

[refreshable]: app/models/product.rb

- **Manual Run (Actions → Run workflow)** — **full-cycle** mode: one click runs
  **all batches back-to-back** (no 5-minute wait, no 24 clicks) until every
  refreshable product is updated or none remain stale.
- **Nightly cron** — one batch per 5-minute tick (24 ticks in the 2-hour window).
- **Trigger** — the workflow `POST`s to `/admin/refresh_prices` with
  `X-Admin-Token` and `X-Trigger-Source` (`schedule` or `manual`).
- **Worker** — `AdminController#refresh_prices` returns **202 Accepted** immediately,
  creates a [`PriceRefreshRun`](app/models/price_refresh_run.rb) row, and enqueues
  `RefreshPricesJob`, which calls `PriceFetcher.refresh_batch` with a limit from
  [`RefreshSchedule`](app/services/refresh_schedule.rb) based on **refreshable**
  product count. Manual runs loop batches until done; cron runs one batch per tick.
- **Observability** — the workflow polls `GET /admin/refresh_runs/:id` (up to ~90
  minutes for manual full-cycle stress runs, ~5 minutes for cron), then writes a
  markdown report to the GitHub Actions **Summary** tab (batches run, attempted /
  succeeded / failed, stale remaining, failure list).
- **Dedup** — a new `PriceRecord` is written **only when the price has actually
  changed**. Per-product failures go to `product.last_fetch_error` and never
  crash the batch.

We picked GitHub Actions cron over Solid Queue + a Heroku worker dyno because it
stays inside the GitHub Student credit, keeps the schedule in version control, and
is portable if we migrate off Heroku — only `APP_URL` would change.

For setup, tuning ENV vars, the site-support matrix, seed/load-test notes, and
troubleshooting, see:

- [`docs/scrapers.md`](docs/scrapers.md) — architecture, batch flow, `Product.refreshable`.
- [`docs/database.md`](docs/database.md) — `price_refresh_runs` table.
- [`wiki.md` § Scheduled tasks](wiki.md) — one-time secret setup and manual verification.

## Target price + price-drop alerts

Each product can carry an optional **target price** ("notify me when price
drops to $X"). Whenever a new `PriceRecord` is written — whether by the
daily refresh cron, the manual "Fetch latest" button, or a hand-entered
price — `PriceAlerter` checks two conditions:

1. **`target_hit`** — new price ≤ `product.target_price`.
2. **`history_low`** — new price strictly below every previous record for
   this product.

If either is true and no alert has fired in the last 24 hours, the system:

- renders + queues a `PriceAlertMailer.price_drop` notification, and
- stamps `product.last_alerted_at = Time.current`.

The alert then surfaces in the UI immediately, and sends email when SMTP is
configured:

- a green **"PRICE ALERT TRIGGERED"** banner on the product show page for
  the next 7 days (with the trigger price and store);
- a **"🎉 Alert fired N days ago"** chip on the product card in the index;
- a **"🎯 Notify at $X"** chip + side-meta row whenever a target is set;
- an HTML + text **email** via `PriceAlertMailer` when outbound SMTP is set.

### Email delivery (SendGrid / SMTP)

Set these Heroku config vars (or local `.env`) to send real alert emails:

```sh
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_USERNAME=apikey
SMTP_PASSWORD=<your SendGrid API key>
MAILER_FROM="PriceTracker <verified-sender@yourdomain.com>"
APP_URL=https://smart-shoppinglist-6ae31171e85c.herokuapp.com
```

SendGrid requires a [verified sender](https://docs.sendgrid.com/for-developers/sending-email/sender-identity). Without SMTP vars, alerts still appear in-app; emails are queued but not delivered.

Smoke test after configuring:

```sh
heroku run bin/rails mailer:smoke_test -a smart-shoppinglist
```

Mailer previews remain at `/rails/mailers/price_alert_mailer`. See
[`wiki.md` § Price-drop alerts](wiki.md) for the full pipeline.

## Sign in with Google

Users can sign in with **Google OAuth** (`omniauth-google-oauth2`) in addition to
email/password. If the Google account email matches an existing user (any casing),
sessions link to that account; duplicate rows are merged via `User.merge_accounts!`.

## Ask AI

The **Ask AI** page (`/ask`) accepts free-text shopping questions ("anything under
$100?", "best deals on my watchlist?") and returns up to three product picks from
the signed-in user's watchlist with short reasoning.

- Powered by **OpenRouter** when `OPENROUTER_API_KEY` is set (same
  `ENABLE_AI_DEAL_ADVICE` flag as deal recommendations).
- Falls back to keyword matching when the API is unavailable — the UI shows a
  source badge (`AI` vs heuristic).

## AI deal recommendations

Product detail pages include a buy-or-wait recommendation from
`DealAdvisor`. The **Budget Planner** (`/budgetplanner`) includes an AI
**DealPicker** panel for top picks under your budget. By default both use local
price-history heuristics so the app works without API keys.

To enable the OpenRouter / OpenAI paths, set:

```sh
ENABLE_AI_DEAL_ADVICE=true
OPENROUTER_API_KEY=...          # Ask AI + DealAdvisor/DealPicker (OpenRouter)
OPENAI_API_KEY=...              # optional OpenAI path for DealAdvisor
OPENAI_DEAL_ADVISOR_MODEL=gpt-5.4-mini
```

If the API request times out, fails, or returns an unusable response, the app
logs the issue and falls back to the local recommendation.

## Manual-only products (`auto_refresh`)

Products created via **Fill in manually** get `auto_refresh: false` — they are
saved and alert-eligible but skipped by nightly cron. Toggle **Auto refresh** on
the edit form to opt back in when a scrapeable URL is present.

## Ideas captured from early planning

- Save product links to the database with a user id.
- Save the date an item was added.
- Optionally save an image per item.
- After login, show a grid of saved items with cards; mark items as resolved.
- Set a “buy at” price and notify when price drops to that margin.
- Start by storing the price you saw manually (scraping across stores is uncertain).
