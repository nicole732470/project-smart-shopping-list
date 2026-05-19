# Real product detail page URLs for seeds and load-test accounts.
# Prefer short canonical links (Amazon /dp/ASIN, retailer PDP paths).
# Avoid /search? URLs — those are not scrapeable product pages.
#
# Used by db/seeds.rb and lib/tasks/paginationtest.rake.

module RealProductCatalog
  Entry = Data.define(:name, :category, :source_url, :store_name, :price_low, :price_high)

  ENTRIES = [
    Entry.new("Amazon eero 6+ mesh Wi-Fi router", "Electronics",
              "https://www.amazon.com/dp/B091G65HH6", "Amazon", 89, 129),
    Entry.new("Owala FreeSip 32oz water bottle", "Sports & Outdoors",
              "https://www.amazon.com/dp/B0FJZ73FSD", "Amazon", 28, 38),
    Entry.new("Kindle Paperwhite (16 GB)", "Electronics",
              "https://www.amazon.com/dp/B0CFPJNBXV", "Amazon", 119, 149),
    Entry.new("Apple AirPods Pro (2nd generation)", "Electronics",
              "https://www.amazon.com/dp/B0CHWRXH8B", "Amazon", 189, 249),
    Entry.new("Atomic Habits", "Books",
              "https://www.amazon.com/dp/0735211292", "Amazon", 12, 20),
    Entry.new("Instant Pot Duo 7-in-1", "Appliances",
              "https://www.amazon.com/dp/B00FLYWNYQ", "Amazon", 59, 99),
    Entry.new("Sony WH-1000XM5 headphones", "Electronics",
              "https://www.amazon.com/dp/B09XS7JWHH", "Amazon", 278, 399),
    Entry.new("Nintendo Switch OLED", "Gaming",
              "https://www.amazon.com/dp/B098RKWHHZ", "Amazon", 299, 349),
    Entry.new("Charmin Ultra Soft toilet paper 24 mega rolls", "Other",
              "https://www.amazon.com/dp/B079VP6DH5", "Amazon", 28, 38),
    Entry.new("Dyson V15 Detect vacuum", "Appliances",
              "https://www.amazon.com/dp/B08TWTKGBQ", "Amazon", 599, 749),

    Entry.new("Curved-Hem Cropped Bomber", "Clothing & Shoes",
              "https://shop.lululemon.com/p/curved-hem-cropped-bomber/fsnb7nysj0", "Lululemon", 98, 128),
    Entry.new("Define Oversized Jacket Mesh", "Clothing & Shoes",
              "https://shop.lululemon.com/p/define-oversized-jacket-mesh/m5feallqal", "Lululemon", 98, 128),
    Entry.new("Ultralight WovenAir Jacket", "Clothing & Shoes",
              "https://shop.lululemon.com/p/ultralight-wovenair-jacket/dsn0kocspb", "Lululemon", 118, 148),
    Entry.new("Align High-Rise Pant 25\"", "Clothing & Shoes",
              "https://shop.lululemon.com/p/align-high-rise-pant-25/L7B5A6S", "Lululemon", 88, 108),
    Entry.new("Everywhere Belt Bag 1L", "Clothing & Shoes",
              "https://shop.lululemon.com/p/everywhere-belt-bag-1L/LU9CBHS", "Lululemon", 28, 38),

    Entry.new("Apple MacBook Air 13\" M3", "Computers & Laptops",
              "https://www.bestbuy.com/site/apple-macbook-air-13-inch-laptop-apple-m3-chip-8gb-memory-256gb-ssd-midnight/6534600.p", "Best Buy", 899, 1099),
    Entry.new("LG 65\" Class C4 OLED TV", "TVs & Home Theater",
              "https://www.bestbuy.com/site/lg-65-class-c4-series-oled-4k-uhd-smart-webos-tv-2024/6577687.p", "Best Buy", 1299, 1799),
    Entry.new("Samsung Galaxy Buds2 Pro", "Electronics",
              "https://www.bestbuy.com/site/samsung-galaxy-buds2-pro-true-wireless-earbud-headphones-graphite/6510533.p", "Best Buy", 149, 229),
    Entry.new("PlayStation 5 Console", "Gaming",
              "https://www.bestbuy.com/site/sony-playstation-5-slim-console-marvels-spider-man-2-bundle/6566039.p", "Best Buy", 449, 549),
    Entry.new("Bose QuietComfort Ultra headphones", "Electronics",
              "https://www.bestbuy.com/site/bose-quietcomfort-ultra-wireless-noise-cancelling-over-the-ear-headphones-black/6554465.p", "Best Buy", 349, 429),

    Entry.new("Apple iPad (10th generation)", "Electronics",
              "https://www.walmart.com/ip/Apple-10-9-inch-iPad-Wi-Fi-64GB-Silver-10th-Generation/1752657021", "Walmart", 299, 349),
    Entry.new("Great Value whole vitamin D milk gallon", "Other",
              "https://www.walmart.com/ip/Great-Value-Whole-Vitamin-D-Milk-Gallon-128-fl-oz/10450114", "Walmart", 3, 5),
    Entry.new("Mainstays memory foam bath mat", "Other",
              "https://www.walmart.com/ip/Mainstays-Memory-Foam-Bath-Mat-17-x-24-Grey/55163566", "Walmart", 8, 14),
    Entry.new("Onn. Google TV Full HD streaming device", "Electronics",
              "https://www.walmart.com/ip/onn-Google-TV-Full-HD-Streaming-Device-New/5013940405", "Walmart", 15, 25),
    Entry.new("Hyper Tough 20V drill driver kit", "Other",
              "https://www.walmart.com/ip/Hyper-Tough-20V-Max-Cordless-Drill-Driver-Kit-1-5Ah-Battery-Charger/416498468", "Walmart", 39, 59),

    Entry.new("Apple AirTag 4 pack", "Electronics",
              "https://www.apple.com/shop/product/MX542AM/A/airtag-4-pack", "Apple Store", 79, 99),
    Entry.new("Apple Magic Keyboard", "Computers & Laptops",
              "https://www.apple.com/shop/product/MK2A3LL/A/magic-keyboard", "Apple Store", 89, 99),
    Entry.new("Apple 20W USB-C power adapter", "Electronics",
              "https://www.apple.com/shop/product/MHJA3AM/A/20w-usb-c-power-adapter", "Apple Store", 15, 19),

    Entry.new("Samsung 990 Pro 2TB NVMe SSD", "Computers & Laptops",
              "https://www.newegg.com/samsung-990-pro-2tb/p/N82E16820238180", "Newegg", 149, 199),
    Entry.new("CORSAIR RM750e power supply", "Computers & Laptops",
              "https://www.newegg.com/corsair-rm750e-2023-750-watt/p/N82E16817139267", "Newegg", 89, 119),

    Entry.new("Nike Air Force 1 '07", "Clothing & Shoes",
              "https://www.nike.com/t/air-force-1-07-mens-shoes-5QFp5Z/CW2288-111", "Nike", 90, 120),
    Entry.new("Adidas Ultraboost light running shoes", "Clothing & Shoes",
              "https://www.adidas.com/us/ultraboost-light-shoes/HP9212.html", "Adidas", 120, 190),

    Entry.new("GoPro HERO12 Black", "Cameras",
              "https://www.bestbuy.com/site/gopro-hero12-black-action-camera/6550606.p", "Best Buy", 299, 399),
    Entry.new("KitchenAid artisan stand mixer", "Appliances",
              "https://www.bestbuy.com/site/kitchenaid-artisan-series-5-quart-tilt-head-stand-mixer-with-pouring-shield-ksm150ps/9739841.p", "Best Buy", 349, 449),
    Entry.new("Ninja Foodi 8qt dual zone air fryer", "Appliances",
              "https://www.bestbuy.com/site/ninja-foodi-8-qt-2-basket-air-fryer-with-dualzone-technology/6440437.p", "Best Buy", 149, 199),
    Entry.new("Keurig K-Elite coffee maker", "Appliances",
              "https://www.bestbuy.com/site/keurig-k-elite-single-serve-k-cup-pod-coffee-maker-brushed-slate/6258027.p", "Best Buy", 129, 169),
    Entry.new("Fitbit Charge 6", "Electronics",
              "https://www.bestbuy.com/site/fitbit-charge-6-advanced-fitness-health-tracker-obsidian/6559712.p", "Best Buy", 119, 159),
    Entry.new("Ring Video Doorbell Wired", "Electronics",
              "https://www.bestbuy.com/site/ring-video-doorbell-wired-2022-release/6510699.p", "Best Buy", 49, 69),
    Entry.new("Roku Streaming Stick 4K", "Electronics",
              "https://www.bestbuy.com/site/roku-streaming-stick-4k-2021-streaming-device-4k-hdr-with-voice-remote/6470977.p", "Best Buy", 29, 49),
    Entry.new("SanDisk Extreme 1TB portable SSD", "Electronics",
              "https://www.bestbuy.com/site/sandisk-extreme-1tb-external-usb-3-2-gen-2-portable-ssd/6487629.p", "Best Buy", 89, 129),
    Entry.new("Logitech MX Master 3S mouse", "Computers & Laptops",
              "https://www.bestbuy.com/site/logitech-mx-master-3s-performance-wireless-mouse-pale-gray/6509659.p", "Best Buy", 79, 99),
    Entry.new("Anker 737 Power Bank 24000mAh", "Electronics",
              "https://www.amazon.com/dp/B0B45K6N4K", "Amazon", 109, 149),
    Entry.new("Stanley Quencher H2.0 40oz tumbler", "Sports & Outdoors",
              "https://www.amazon.com/dp/B0CJZMP8F2", "Amazon", 35, 45),
    Entry.new("Coleman Sundome 4-person tent", "Sports & Outdoors",
              "https://www.amazon.com/dp/B00437V8MK", "Amazon", 49, 79),
    Entry.new("YETI Rambler 26oz bottle", "Sports & Outdoors",
              "https://www.amazon.com/dp/B07DRCDTBM", "Amazon", 29, 40),
    Entry.new("The Midnight Library", "Books",
              "https://www.amazon.com/dp/0525559477", "Amazon", 10, 18),
    Entry.new("Fourth Wing", "Books",
              "https://www.amazon.com/dp/1649374046", "Amazon", 12, 20),
    Entry.new("CeraVe moisturizing cream", "Beauty",
              "https://www.amazon.com/dp/B00TTD9BRC", "Amazon", 14, 20),
    Entry.new("Olaplex No.3 hair perfector", "Beauty",
              "https://www.amazon.com/dp/B00SNM5US4", "Amazon", 24, 30)
  ].freeze

  def self.sample
    ENTRIES.sample
  end

  def self.at(index)
    ENTRIES[index % ENTRIES.size]
  end

  def self.size
    ENTRIES.size
  end
end
