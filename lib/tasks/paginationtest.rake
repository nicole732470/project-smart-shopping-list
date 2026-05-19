namespace :paginationtest do
  desc "Replace paginationtest@example.com products with real PDP URLs (does not touch other users)"
  task reseed_real_urls: :environment do
    require Rails.root.join("db/seeds/real_product_catalog")

    user = User.find_by(email_address: "paginationtest@example.com")
    unless user
      abort "paginationtest@example.com not found — nothing to do."
    end

    old_count = user.products.count
    puts "Replacing #{old_count} products for #{user.email_address}..."

    PriceRecord.alerter_callback_enabled = false

    product_ids = user.products.pluck(:id)
    PriceRecord.where(product_id: product_ids).delete_all
    Product.where(id: product_ids).delete_all

    notes_options = [ "Black Friday deal", "Holiday sale", "Regular price", "" ]

    1_250.times do |i|
      entry = RealProductCatalog.at(i)
      starting_price = rand(entry.price_low..entry.price_high) + rand(0..99) / 100.0

      product = user.products.create!(
        name: "#{entry.name} pg-#{i + 1}",
        category: entry.category,
        description: "Pagination stress-test row seeded from a real #{entry.store_name} PDP.",
        source_url: entry.source_url
      )

      rand(4..6).times do |record_index|
        drift = 1.0 + rand(-0.12..0.12)
        price = [ starting_price * drift, 1 ].max.round(2)
        product.price_records.create!(
          price: price,
          store_name: entry.store_name,
          url: entry.source_url,
          recorded_at: (record_index * rand(3..7) + rand(1..3)).days.ago,
          notes: notes_options.sample,
          source: "manual"
        )
      end
    end

    puts "Done. paginationtest now has #{user.products.count} products (#{Product.scrapeable.where(user_id: user.id).count} scrapeable URLs)."
  ensure
    PriceRecord.alerter_callback_enabled = true if defined?(PriceRecord)
  end
end
