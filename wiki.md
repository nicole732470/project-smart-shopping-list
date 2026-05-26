# PriceTracker Wiki

## What problem are we solving?

Online shoppers often want to buy items but not at full price. They'll see something they want, bookmark it, and hope to remember to check back later to see if the price has dropped. In practice, they forget, they lose the tab, or they end up buying at full price anyway.

PriceTracker is a personal price-watching tool. Users save products they're interested in, record prices they've seen at different stores, and track how those prices change over time. The long-term goal is to notify users when a product drops below a target "buy at" price, so they never miss a deal.

## Design board

Object-oriented design and user flow sketches:
[Miro board](https://miro.com/app/board/uXjVGjU99U8=/)

## Live demo

[smart-shoppinglist-6ae31171e85c.herokuapp.com](https://smart-shoppinglist-6ae31171e85c.herokuapp.com/)

Demo account: `demo@example.com` / `TrackSave!123` (see [Seed accounts](../README.md#seed-accounts))

## Tech stack

- **Framework:** Ruby on Rails 8.1
- **Database:** PostgreSQL
- **Frontend:** Bootstrap 5 + ERB views
- **Auth:** Rails 8 built-in authentication (session-based, bcrypt password hashing)
- **Hosting:** Heroku
- **CI:** GitHub Actions (Brakeman, Bundler-Audit, Rails test suite)

## Domain model

- **User** — owns a list of products; authenticates with email + password
- **Product** — an item the user is tracking (name, category, description). Scoped to its owning user.
- **PriceRecord** — a single observed price for a product at a given store (price, store name, URL, date observed, notes). Belongs to a product.

```
User 1 ── * Product 1 ── * PriceRecord
```

Users only ever see and act on their own products; attempting to access another user's product returns 404.

## MVP (current scope)

- [x] User sign up / sign in / sign out
- [x] CRUD on products, scoped per user
- [x] CRUD on price records attached to a product
- [x] Seeded demo data (20 products, 60 price records)
- [x] Bootstrap-based responsive UI
- [x] Deployed on Heroku
- [x] Automated tests running on GitHub Actions
- [x] Daily automatic price refresh (GitHub Actions cron → webhook)
- [x] Target price + in-app price-drop alerts (banner + card chip, with 24h cooldown)

## Similar products and references

These tools solve overlapping problems and are useful for comparison and inspiration:

- [Camelcamelcamel](https://camelcamelcamel.com/) — Amazon price history charts and alerts.
- [Keepa](https://keepa.com/) — Amazon price tracking and browser extensions.
- [Honey / PayPal Rewards](https://www.joinhoney.com/) — coupons and price context while shopping (not the same as long-term watchlists, but adjacent).
- [Google Shopping](https://shopping.google.com/) — compare prices across retailers for a quick snapshot.

## Features beyond MVP (planned / ideas)

- **Email delivery for price-drop alerts.** ✅ Wired via `MailerSettings` + SMTP (SendGrid on Heroku). Set `SMTP_ADDRESS`, `SMTP_PASSWORD`, `MAILER_FROM`, and `APP_URL`. Without SMTP, in-app banners still work.
- **"Resolved" / purchased state.** A toggle on each product to mark "bought" or "no longer watching," which hides it from the main grid.
- **Product images.** Either an uploaded image via Active Storage or a URL-scraped thumbnail.
- **Automatic price scraping.** Pull current prices from supported retailers (Amazon, Target, etc.) instead of requiring manual entry.
- **Price-history charts.** Visualize how a product's price has moved over time.
- **Shared wishlists.** Share a list of watched items with friends/family for gift ideas.
- **Import from URL.** Paste any product URL and auto-fill the form (name, image, initial price).

## Visual assets

PriceTracker uses a small set of visual assets to give the UI character beyond plain text. Sources and licenses are listed below.

### Photography

| Asset | Where it's used | Source | License |
|---|---|---|---|
| `app/assets/images/hero-shelves.jpg` | Banner image at the top of the About page | [Unsplash photo `1607082348824-0a96f2a4b9da`](https://unsplash.com/photos/1607082348824-0a96f2a4b9da) | [Unsplash License](https://unsplash.com/license) — free to use, no attribution required |

Approved sources we draw from:
- [Unsplash](https://unsplash.com/) — primary photography source
- [Pixabay](https://pixabay.com/) — secondary, used if Unsplash doesn't have what we need
- [RGBStock](https://www.rgbstock.com/images/) — also approved

### Icons

All UI icons (search, plus, arrow, package, trend, edit, trash) are hand-written inline SVGs in `app/views/shared/_icon.html.erb`. The stroke shapes are adapted from the open-source [Feather Icons](https://feathericons.com/) set ([MIT License](https://github.com/feathericons/feather/blob/main/LICENSE)). No icon font is loaded — every icon is inlined at render time so it inherits text colour and avoids an extra network request.

### Brand mark

The "P/T" wordmark is a typographic mark drawn with CSS; no external image is used.

### Custom error pages

`public/404.html`, `public/422.html`, `public/500.html`, and `public/406-unsupported-browser.html` are styled to match the in-app `pt-` design system (typography, palette, brand mark, button shapes). Each page links back to `/` and surfaces the error code prominently.

## Development notes

### Running locally
```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

Then log in as `demo@example.com` / `TrackSave!123`.

### Seed & load-test accounts

After `bin/rails db:seed`, see [README § Seed accounts](../README.md#seed-accounts).
All seeded products use **real retailer PDP URLs** from
[`db/seeds/real_product_catalog.rb`](../db/seeds/real_product_catalog.rb).

**Never** run `db:seed:replant` on Heroku production. To refresh only
`paginationtest@example.com`:

```bash
heroku run bin/rails paginationtest:reseed_real_urls -a smart-shoppinglist
```

### Running tests
```bash
bin/rails test
```

### Deploying to Heroku
```bash
git push heroku main
heroku run rails db:migrate -a smart-shoppinglist
```

### Scheduled tasks (daily price refresh)

Each product's latest price is re-scraped on a schedule so the price-history
chart stays current without anyone clicking "Fetch latest price" by hand.

We run the schedule from **GitHub Actions cron** rather than from a Heroku
worker dyno or Heroku Scheduler. This keeps the project free under the
GitHub Student credit (no extra Heroku worker required) and stays portable
if we ever migrate off Heroku — only `APP_URL` would need to change.

**How it works:**

1. `.github/workflows/refresh-prices.yml` runs **every 5 minutes during
   UTC hours 7–8** (≈ 2:00–3:55 AM Chicago CDT).
2. It POSTs to `https://<app>/admin/refresh_prices` with an
   `X-Admin-Token` header and `X-Trigger-Source` (`schedule` or `manual`).
3. `AdminController#refresh_prices` checks the token, creates a
   `PriceRefreshRun`, enqueues `RefreshPricesJob`, and returns **202
   Accepted** immediately (Heroku web requests must finish within 30 seconds).
4. The workflow polls `GET /admin/refresh_runs/:id` until the batch
   finishes, then writes a markdown report to the run **Summary** tab.
5. The job calls `PriceFetcher.refresh_batch` on **`Product.scrapeable`** rows
   only (real PDP URLs — skips `example.com` placeholders and `/search?` links).
   Limit comes from `RefreshSchedule` (auto-scales with scrapeable count). Over
   24 ticks in the 2-hour window the scrapeable catalog is covered. A new
   `PriceRecord` is written only when the price has actually changed.
6. Each run is persisted in `price_refresh_runs` for polling and debugging.

**Tuning (Heroku config vars):** `REFRESH_WINDOW_HOURS=2`,
`REFRESH_INTERVAL_MINUTES=5`, `REFRESH_STALE_HOURS=23`, `REFRESH_BATCH_MAX=500`.

**One-time setup:**

```bash
# 1. Generate a strong shared secret
openssl rand -hex 32

# 2. Set it on Heroku
heroku config:set ADMIN_REFRESH_TOKEN=<the-secret> -a smart-shoppinglist

# 3. Add two repo secrets at:
#    GitHub → Settings → Secrets and variables → Actions
#      APP_URL              = https://smart-shoppinglist-6ae31171e85c.herokuapp.com
#      ADMIN_REFRESH_TOKEN  = <same secret>
```

**Verifying it works:**

- **Manual trigger:** GitHub → Actions → "Daily price refresh" → "Run workflow".
  Open the run → **Summary** for attempted/succeeded/failed, duration, trigger
  source, and failure list. A red "poll timeout" step can appear while the batch
  still completes on Heroku (~3 min for ~53 serial scrapes) — check Summary or
  `heroku run bin/rails runner "pp PriceRefreshRun.last.as_api_json"`.
- **Production pagination account only:**
  `heroku run bin/rails paginationtest:reseed_real_urls -a smart-shoppinglist`
- **App logs (optional):** `heroku logs --tail -a smart-shoppinglist`
- **CLI full refresh (emergency):**
  ```bash
  bin/rails runner "PriceFetcher.refresh_all"
  ```

### Price-drop alerts (target price + in-app banner)

Users can set a per-product **target price** ("notify me when price drops to
$X"). Every time a new `PriceRecord` is written — whether by the daily
refresh cron, the manual "Fetch latest" button, or a hand-entered price —
the system checks whether the new price should trigger an alert.

**Trigger reasons** (an alert fires if either is true):

1. **`target_hit`** — the new price is at or below `product.target_price`.
2. **`history_low`** — the new price is strictly lower than every previous
   `PriceRecord` for this product (history-since-tracking-started).

**Pipeline:**

```
PriceRecord.after_create_commit
        ▼
PriceAlerter.call(record)
        ├── no-op if cooldown active (last_alerted_at within 24h)
        ├── compute reasons (target_hit, history_low)
        ├── PriceAlertMailer.price_drop(...).deliver_later
        │   (delivered when SMTP_ADDRESS + SMTP_PASSWORD are set)
        └── product.update_column(:last_alerted_at, Time.current)
```

**Email (production):**

```bash
heroku config:set \
  SMTP_ADDRESS=smtp.sendgrid.net \
  SMTP_USERNAME=apikey \
  SMTP_PASSWORD=<SendGrid API key> \
  MAILER_FROM="PriceTracker <verified@yourdomain.com>" \
  -a smart-shoppinglist
```

`APP_URL` must already match the deployed host so "View on PriceTracker" links work. Smoke test: `heroku run bin/rails mailer:smoke_test`.

**Where the user sees it:**

- **Product show page** — green "🎉 PRICE ALERT TRIGGERED" banner at the
  top whenever `last_alerted_at` is within the last 7 days, plus a
  "🎯 Notify at $X" row in the side meta whenever a target is set.
- **Product index cards** — each card shows either "🎉 Alert fired Nd ago"
  (recent alert) or "🎯 Notify at $X" (target set, no recent alert).
- **Edit / new (manual) form** — a "Notify me when price drops to" field;
  leave blank to opt out of alerts for that product.

**Implementation notes:**

- The 7-day banner window is independent of the 24-hour mailer cooldown.
  Cooldown protects the user's inbox; the banner is the lingering proof of
  the latest deal.
- `Product.alert_trigger_record` resolves to the `PriceRecord` whose
  creation most recently fired the alert. The banner shows that
  record's price and store.
- `PriceRecord.alerter_callback_enabled` is a `class_attribute` used by
  tests to suppress the `after_create_commit` callback when seeding fixture
  history (so test setup doesn't double-fire alerts).
