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
| `demo@example.com` | `Demo1234!` | Curated demo data, ~30 products with realistic price history |
| `shopper1@example.com` … `shopper39@example.com` | `Shopper!#{n}A#{((n-1) % 9) + 1}z` | 39 load-test users, each with ~30 products and 6–10 price records per product — together they push the dataset past 1,200 products and ~9,600 price records so pagination and list performance are visible |

Sign in as any of the shoppers to see paginated lists in action. Pagination is provided by [Pagy](https://github.com/ddnexus/pagy) — products index paginates at 24 per page, the per-product price ledger at 20 per page.

On Heroku there's also a legacy `paginationtest@example.com` (password `Pagy123!`) account with 1,250 products and ~6,900 price records — that one was inserted directly into production and isn't recreated by the seed task locally.

## Automatic daily price refresh

Every product with a `source_url` is re-scraped on a nightly schedule so the
price-history chart stays fresh without anyone clicking *Fetch latest
price* by hand.

- **Schedule** — `.github/workflows/refresh-prices.yml` runs every 5
  minutes during UTC hours 7–8 (≈ 2:00–3:55 AM Chicago CDT) and can also
  be triggered manually from the *Actions* tab.
- **Trigger** — the workflow `POST`s to `/admin/refresh_prices` on the
  deployed app, authenticated by a shared secret (`X-Admin-Token` header,
  matched against `ENV["ADMIN_REFRESH_TOKEN"]` via constant-time compare).
- **Worker** — `AdminController#refresh_prices` returns **202 Accepted**
  immediately and enqueues `RefreshPricesJob`, which calls
  `PriceFetcher.refresh_batch` with a limit auto-calculated by
  `RefreshSchedule` from the current product count. Over 24 ticks in the
  2-hour window the full catalog is covered. A new `PriceRecord` is written
  **only when the price has actually changed** (dedup). Per-product
  failures are captured in `product.last_fetch_error` and never crash the
  cron tick.

We picked GitHub Actions cron over Solid Queue + a Heroku worker dyno
because it stays inside the GitHub Student `$13/month` credit, keeps the
schedule in version control, and is portable if we ever migrate off
Heroku — only `APP_URL` would change.

For setup steps, debugging, the full list of supported / unsupported
retailers, and the legal/ethical scraping notes, see:

- [`docs/scrapers.md`](docs/scrapers.md) — adapter contract, site support
  matrix, full request flow, troubleshooting.
- [`wiki.md` § Scheduled tasks](wiki.md) — one-time secret setup and
  manual-trigger verification.

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
