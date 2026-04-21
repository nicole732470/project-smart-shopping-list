# PriceTracker Wiki

## What problem are we solving?

Online shoppers often want to buy items but not at full price. They'll see something they want, bookmark it, and hope to remember to check back later to see if the price has dropped. In practice, they forget, they lose the tab, or they end up buying at full price anyway.

PriceTracker is a personal price-watching tool. Users save products they're interested in, record prices they've seen at different stores, and track how those prices change over time. The long-term goal is to notify users when a product drops below a target "buy at" price, so they never miss a deal.

## Design board

Object-oriented design and user flow sketches:
[Miro board](https://miro.com/app/board/uXjVGjU99U8=/)

## Live demo

[smart-shoppinglist-6ae31171e85c.herokuapp.com](https://smart-shoppinglist-6ae31171e85c.herokuapp.com/)

Demo account: `demo@example.com` / `password`

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

## Features beyond MVP (planned / ideas)

- **Target price + price-drop alerts.** Let users set a "notify me at" price per product; send an email when a new PriceRecord comes in below that threshold.
- **"Resolved" / purchased state.** A toggle on each product to mark "bought" or "no longer watching," which hides it from the main grid.
- **Product images.** Either an uploaded image via Active Storage or a URL-scraped thumbnail.
- **Automatic price scraping.** Pull current prices from supported retailers (Amazon, Target, etc.) instead of requiring manual entry.
- **Price-history charts.** Visualize how a product's price has moved over time.
- **Shared wishlists.** Share a list of watched items with friends/family for gift ideas.
- **Import from URL.** Paste any product URL and auto-fill the form (name, image, initial price).

## Development notes

### Running locally
```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

Then log in as `demo@example.com` / `password`.

### Running tests
```bash
bin/rails test
```

### Deploying to Heroku
```bash
git push heroku main
heroku run rails db:migrate -a smart-shoppinglist
```
