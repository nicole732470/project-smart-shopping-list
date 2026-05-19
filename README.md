# PriceTracker (Smart Shopping List)

## Team

Nicole Li, Andrew Xue, Amie Masih, Rahib Taher

## MVP

A web app where signed-in users save products they are watching, record prices seen at different stores, and review them from a simple dashboard. The baseline vision is to paste a product link, set a target price, and get notified when the price meets that condition (notifications are a stretch goal beyond the current milestone).

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
| `demo@example.com` | `TrackSave!123` | Full real-product catalog (49 unique PDP URLs) |
| `shopper1@example.com` … `shopper39@example.com` | `Shopper!#{n}A#{((n-1) % 9) + 1}z` | 39 load-test users × 30 products each — catalog cycles so pagination stays >1,000 rows |
| `paginationtest@example.com` | `Pagy123!` | 1,250 products for Pagy stress tests (same real PDP catalog, recreated by `db:seed`) |

All seeded `source_url` values point at **real retailer product detail pages**
(Amazon `/dp/…`, Best Buy `/site/…/….p`, Walmart `/ip/…`, Lululemon, etc.).
The canonical list lives in [`db/seeds/real_product_catalog.rb`](db/seeds/real_product_catalog.rb)
(49 unique PDP URLs, cycled for volume). Seeds **do not** use `example.com`
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

## Automatic daily price refresh

Every **scrapeable** product (real PDP `source_url`; see
[`Product.scrapeable`][scrapeable] in `app/models/product.rb`) is re-scraped on a
nightly schedule so the price-history chart stays fresh without anyone clicking
*Fetch latest price* by hand. Load-test rows with non-PDP URLs are skipped.

[scrapeable]: app/models/product.rb

- **Schedule** — [`.github/workflows/refresh-prices.yml`](.github/workflows/refresh-prices.yml)
  runs every 5 minutes during UTC hours 7–8 (≈ 2:00–3:55 AM Chicago CDT) and can
  also be triggered manually from the *Actions* tab.
- **Trigger** — the workflow `POST`s to `/admin/refresh_prices` with
  `X-Admin-Token` and `X-Trigger-Source` (`schedule` or `manual`).
- **Worker** — `AdminController#refresh_prices` returns **202 Accepted** immediately,
  creates a [`PriceRefreshRun`](app/models/price_refresh_run.rb) row, and enqueues
  `RefreshPricesJob`, which calls `PriceFetcher.refresh_batch` with a limit from
  [`RefreshSchedule`](app/services/refresh_schedule.rb) based on **scrapeable**
  product count (auto-scales; default window covers the catalog in ~24 batches).
- **Observability** — the workflow polls `GET /admin/refresh_runs/:id` (same token)
  for up to ~3 minutes, then writes a markdown report to the GitHub Actions
  **Summary** tab: attempted / succeeded / failed / duration / stale remaining /
  per-product failure messages. A green workflow step means the batch **finished**
  (not that every scrape succeeded). Poll timeout can occur on large batches even
  when the job completes on Heroku — check Summary or `PriceRefreshRun` in the DB.
- **Dedup** — a new `PriceRecord` is written **only when the price has actually
  changed**. Per-product failures go to `product.last_fetch_error` and never
  crash the batch.

We picked GitHub Actions cron over Solid Queue + a Heroku worker dyno because it
stays inside the GitHub Student credit, keeps the schedule in version control, and
is portable if we migrate off Heroku — only `APP_URL` would change.

For setup, tuning ENV vars, the site-support matrix, seed/load-test notes, and
troubleshooting, see:

- [`docs/scrapers.md`](docs/scrapers.md) — architecture, batch flow, `Product.scrapeable`.
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

The alert then surfaces in the UI **without** requiring an SMTP provider:

- a green **"PRICE ALERT TRIGGERED"** banner on the product show page for
  the next 7 days (with the trigger price and store);
- a **"🎉 Alert fired N days ago"** chip on the product card in the index;
- a **"🎯 Notify at $X"** chip + side-meta row whenever a target is set.

Outbound email delivery is intentionally left unwired for this milestone —
templates render correctly via `bin/rails runner` and the mailer previews
under `/rails/mailers/price_alert_mailer`, but no SMTP credentials are
configured. See [`wiki.md` § Price-drop alerts](wiki.md) for the full
pipeline diagram and implementation notes.

## AI deal recommendations

Product detail pages include a buy-or-wait recommendation from
`DealAdvisor`. By default it uses a local price-history heuristic so the app
continues working in development, tests, demos, and production even when no AI
provider is configured.

To enable the OpenAI-backed recommendation path, set:

```sh
ENABLE_AI_DEAL_ADVICE=true
OPENAI_API_KEY=...
OPENAI_DEAL_ADVISOR_MODEL=gpt-5.4-mini
```

If the API request times out, fails, or returns an unusable response, the app
logs the issue and falls back to the local recommendation.

## Ideas captured from early planning

- Save product links to the database with a user id.
- Save the date an item was added.
- Optionally save an image per item.
- After login, show a grid of saved items with cards; mark items as resolved.
- Set a “buy at” price and notify when price drops to that margin.
- Start by storing the price you saw manually (scraping across stores is uncertain).
