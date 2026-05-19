require_relative "seeds/real_product_catalog"

puts "Clearing existing data..."
PriceRecord.destroy_all
Product.destroy_all
User.destroy_all

demo_password = "TrackSave!123"

puts "Creating demo user..."
demo_user = User.create!(
  email_address: "demo@example.com",
  password: demo_password,
  password_confirmation: demo_password
)
puts "  demo login: demo@example.com / #{demo_password}"

notes_options = [
  "Black Friday deal",
  "Holiday sale",
  "Limited time offer",
  "Coupon applied",
  "Regular price",
  "Clearance",
  ""
]

LOAD_TEST_USER_COUNT = 39
PRODUCTS_PER_USER = 30

users = [ demo_user ]

puts "Creating load-test users..."
LOAD_TEST_USER_COUNT.times do |i|
  password = "Shopper!#{i + 1}A#{(i % 9) + 1}z"
  users << User.create!(
    email_address: "shopper#{i + 1}@example.com",
    password: password,
    password_confirmation: password
  )
end

puts "Creating pagination stress-test account..."
pagination_user = User.create!(
  email_address: "paginationtest@example.com",
  password: "Pagy123!",
  password_confirmation: "Pagy123!"
)
users << pagination_user

puts "Creating products and price histories from real PDP catalog (#{RealProductCatalog.size} unique URLs)..."

PriceRecord.alerter_callback_enabled = false

def seed_product_for_user!(user, catalog_index, label_suffix: nil)
  entry = RealProductCatalog.at(catalog_index)
  name = label_suffix ? "#{entry.name} #{label_suffix}" : entry.name
  starting_price = rand(entry.price_low..entry.price_high) + rand(0..99) / 100.0
  target_price = [ starting_price * rand(0.72..0.92), 1 ].max.round(2)

  product = user.products.create!(
    name: name,
    category: entry.category,
    description: "Seeded from a real #{entry.store_name} product page for scrape + pagination testing.",
    source_url: entry.source_url,
    target_price: [ nil, target_price ].sample
  )

  rand(6..10).times do |record_index|
    drift = 1.0 + rand(-0.18..0.16)
    price = [ starting_price * drift, 1 ].max.round(2)

    product.price_records.create!(
      price: price,
      store_name: entry.store_name,
      url: entry.source_url,
      recorded_at: (record_index * rand(3..9) + rand(1..3)).days.ago,
      notes: notes_options.sample,
      source: [ "manual", "scraped" ].sample
    )
  end

  product
end

begin
  catalog_index = 0

  # Demo user: one pass through the catalog (unique-ish names).
  RealProductCatalog.size.times do |i|
    seed_product_for_user!(demo_user, i, label_suffix: "demo")
    catalog_index += 1
  end

  # Load-test shoppers: cycle the catalog to exceed 1,000 products total.
  users[1..LOAD_TEST_USER_COUNT].each_with_index do |user, user_index|
    PRODUCTS_PER_USER.times do |product_index|
      seed_product_for_user!(
        user,
        catalog_index,
        label_suffix: "#{user_index + 1}-#{product_index + 1}"
      )
      catalog_index += 1
    end
  end

  # Pagination account: enough rows to stress Pagy in production-like scenarios.
  1_250.times do |i|
    seed_product_for_user!(pagination_user, catalog_index + i, label_suffix: "pg-#{i + 1}")
  end

  scrapeable = Product.scrapeable.count
  puts "Done. Created #{User.count} users, #{Product.count} products, and #{PriceRecord.count} price records."
  puts "Scrapeable products (real PDP URLs): #{scrapeable}"
  puts "Large enough for pagination/performance checks: #{Product.count >= 1_000 ? 'yes' : 'no'}"
ensure
  PriceRecord.alerter_callback_enabled = true if defined?(PriceRecord)
end
