puts "Clearing existing data..."
PriceRecord.destroy_all
Product.destroy_all
User.destroy_all

# Don't fire the price-alerter (or its emails) during bulk seeding.
PriceRecord.alerter_callback_enabled = false

puts "Creating demo user..."
demo_user = User.create!(
  email_address: "demo@example.com",
  password: "Demo1234!",
  password_confirmation: "Demo1234!"
)
puts "  demo login: demo@example.com / Demo1234!"

puts "Creating products..."
products_data = [
  { name: "Apple iPhone 15 Pro", category: "Electronics", description: "6.1-inch Super Retina XDR display, A17 Pro chip, titanium design, 48MP camera system" },
  { name: "Samsung 65\" 4K QLED TV", category: "TVs & Home Theater", description: "65-inch QLED 4K Smart TV with Quantum HDR, Motion Xcelerator, and built-in Alexa" },
  { name: "Sony WH-1000XM5 Headphones", category: "Electronics", description: "Industry-leading noise canceling wireless headphones, 30-hour battery life" },
  { name: "Apple MacBook Air M2", category: "Computers & Laptops", description: "13.6-inch Liquid Retina display, Apple M2 chip, 8GB RAM, 256GB SSD" },
  { name: "PlayStation 5 Console", category: "Gaming", description: "Next-gen gaming console, 4K gaming, ray tracing, ultra-high speed SSD" },
  { name: "Dyson V15 Detect Vacuum", category: "Appliances", description: "Cordless vacuum with laser dust detection, HEPA filtration, 60 min run time" },
  { name: "Nike Air Max 270", category: "Clothing & Shoes", description: "Men's shoe with Max Air unit for all-day comfort, available in multiple colorways" },
  { name: "Atomic Habits by James Clear", category: "Books", description: "An Easy & Proven Way to Build Good Habits & Break Bad Ones — #1 NY Times Bestseller" },
  { name: "Kindle Paperwhite (16GB)", category: "Electronics", description: "The thinnest, lightest Kindle Paperwhite yet, waterproof, 3-month free Kindle Unlimited" },
  { name: "Instant Pot Duo 7-in-1", category: "Appliances", description: "7-in-1 electric pressure cooker, slow cooker, rice cooker, steamer, sauté, yogurt maker, warmer" },
  { name: "iPad Air (M2)", category: "Electronics", description: "11-inch Liquid Retina display, Apple M2 chip, 128GB storage, Wi-Fi" },
  { name: "Bose QuietComfort Earbuds II", category: "Electronics", description: "Wireless noise-cancelling earbuds with CustomTune sound calibration" },
  { name: "LG 27\" UltraGear Gaming Monitor", category: "Computers & Laptops", description: "27-inch QHD IPS, 165Hz refresh rate, 1ms response, G-SYNC compatible" },
  { name: "Nintendo Switch OLED", category: "Gaming", description: "7-inch OLED screen, enhanced audio, 64GB internal storage, wide adjustable stand" },
  { name: "Ninja Foodi Air Fryer", category: "Appliances", description: "8-quart 6-in-1 air fryer with DualZone technology and smart cook system" },
  { name: "Lululemon Align Leggings", category: "Clothing & Shoes", description: "Buttery-soft 25-inch leggings designed for yoga and everyday wear" },
  { name: "The Midnight Library by Matt Haig", category: "Books", description: "A novel about life, regret, and the infinite possibilities between choices" },
  { name: "Keurig K-Elite Coffee Maker", category: "Appliances", description: "Single serve K-Cup pod coffee brewer with iced coffee setting, brushed silver" },
  { name: "GoPro HERO12 Black", category: "Electronics", description: "Waterproof 5.3K60 action camera with HyperSmooth 6.0 stabilization" },
  { name: "Adidas Ultraboost 22", category: "Clothing & Shoes", description: "Men's running shoes with responsive Boost midsole and Primeknit+ upper" }
]

products = products_data.map { |p| demo_user.products.create!(p) }

puts "Creating price records..."
store_urls = {
  "Amazon"      => "https://www.amazon.com",
  "Walmart"     => "https://www.walmart.com",
  "Target"      => "https://www.target.com",
  "Best Buy"    => "https://www.bestbuy.com",
  "Costco"      => "https://www.costco.com",
  "eBay"        => "https://www.ebay.com",
  "Newegg"      => "https://www.newegg.com",
  "Apple Store" => "https://www.apple.com/shop"
}

price_ranges = {
  "Apple iPhone 15 Pro"         => [ 949, 1199 ],
  "Samsung 65\" 4K QLED TV"    => [ 799, 1299 ],
  "Sony WH-1000XM5 Headphones" => [ 279, 399 ],
  "Apple MacBook Air M2"        => [ 999, 1299 ],
  "PlayStation 5 Console"       => [ 449, 549 ],
  "Dyson V15 Detect Vacuum"     => [ 649, 799 ],
  "Nike Air Max 270"            => [ 89, 150 ],
  "Atomic Habits by James Clear"=> [ 11, 27 ],
  "Kindle Paperwhite (16GB)"    => [ 99, 149 ],
  "Instant Pot Duo 7-in-1"     => [ 59, 99 ],
  "iPad Air (M2)"                    => [ 599, 799 ],
  "Bose QuietComfort Earbuds II"     => [ 199, 299 ],
  "LG 27\" UltraGear Gaming Monitor" => [ 279, 399 ],
  "Nintendo Switch OLED"             => [ 299, 349 ],
  "Ninja Foodi Air Fryer"            => [ 129, 199 ],
  "Lululemon Align Leggings"         => [ 79, 98 ],
  "The Midnight Library by Matt Haig"=> [ 10, 18 ],
  "Keurig K-Elite Coffee Maker"      => [ 129, 189 ],
  "GoPro HERO12 Black"               => [ 349, 449 ],
  "Adidas Ultraboost 22"             => [ 120, 190 ]
}

notes_options = [ "Black Friday deal", "Holiday sale", "Limited time offer", "Coupon applied: SAVE10", "Regular price", "Clearance", "" ]

products.each do |product|
  range = price_ranges[product.name] || [ 50, 500 ]
  stores = store_urls.keys.sample(3)

  stores.each_with_index do |store, i|
    price = rand(range[0]..range[1]) + rand(0..99) / 100.0
    PriceRecord.create!(
      product: product,
      price: price,
      store_name: store,
      url: "#{store_urls[store]}/search?q=#{product.name.gsub(' ', '+')}",
      recorded_at: (i * 10 + rand(1..9)).days.ago,
      notes: notes_options.sample
    )
  end
end

puts "Demo user has #{Product.count} products and #{PriceRecord.count} price records."

# ─────────────────────────────────────────────────────────────────────────────
# paginationtest@example.com — large dataset so pagination is visible
# ─────────────────────────────────────────────────────────────────────────────
puts ""
puts "Creating pagination test user with large dataset..."
pagination_user = User.create!(
  email_address: "paginationtest@example.com",
  password: "Pagy123!",
  password_confirmation: "Pagy123!"
)
puts "  pagination login: paginationtest@example.com / Pagy123!"

PAGINATION_PRODUCTS  = 1_250
PAGINATION_RECS_MIN  = 3
PAGINATION_RECS_MAX  = 8

categories = [
  "Electronics", "Computers & Laptops", "Gaming", "TVs & Home Theater",
  "Appliances", "Clothing & Shoes", "Books", "Home & Kitchen",
  "Beauty", "Sports & Outdoors", "Toys", "Tools", "Pet Supplies", "Garden"
]
adjectives = %w[Pro Max Ultra Mini Lite Plus Air Smart Premium Classic Eco Compact Heavy-Duty Wireless]
nouns      = %w[Speaker Headphones Mouse Keyboard Monitor Camera Tablet Phone Laptop Backpack Mug Lamp Pillow Sneaker Watch Drone Vacuum Toaster Blender Bookcase]
stores     = store_urls.keys

now = Time.current
product_rows = Array.new(PAGINATION_PRODUCTS) do |i|
  brand     = adjectives.sample
  product   = nouns.sample
  model_num = format("%04d", i + 1)
  name      = "#{brand} #{product} #{model_num}"
  {
    user_id:     pagination_user.id,
    name:        name,
    category:    categories.sample,
    description: "Auto-generated demo product ##{model_num} for pagination/perf testing.",
    source_url:  "https://example.com/products/#{model_num}",
    created_at:  now - rand(1..400).days,
    updated_at:  now
  }
end

print "  inserting #{PAGINATION_PRODUCTS} products... "
Product.insert_all(product_rows)
puts "done."

product_ids = Product.where(user_id: pagination_user.id).pluck(:id)

print "  generating price records... "
record_rows = []
product_ids.each do |pid|
  base_price = rand(20..500) + rand(0..99) / 100.0
  rand(PAGINATION_RECS_MIN..PAGINATION_RECS_MAX).times do |j|
    record_rows << {
      product_id:  pid,
      price:       (base_price * (1 + rand(-15..15) / 100.0)).round(2),
      store_name:  stores.sample,
      url:         nil,
      recorded_at: now - (j * 14 + rand(1..13)).days,
      notes:       (notes_options.sample if rand < 0.4),
      source:      [ "manual", "scraped" ].sample,
      created_at:  now,
      updated_at:  now
    }
  end
end

# Bulk insert in chunks to keep memory + SQL string size sane.
record_rows.each_slice(1_000) { |chunk| PriceRecord.insert_all(chunk) }
puts "done — #{record_rows.size} records across #{product_ids.size} products."

PriceRecord.alerter_callback_enabled = true

puts ""
puts "✅ Seed complete."
puts "   Demo:       demo@example.com / Demo1234!  (#{demo_user.products.count} products)"
puts "   Pagination: paginationtest@example.com / Pagy123!  (#{pagination_user.products.count} products, #{PriceRecord.where(product_id: product_ids).count} records)"
