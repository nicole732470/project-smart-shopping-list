module SupportedRetailersHelper
  RetailerEntry = Data.define(:name, :domain, :hint)

  AUTO_RETAILERS = [
    RetailerEntry.new("Best Buy", "bestbuy.com", "Electronics & appliances"),
    RetailerEntry.new("Walmart", "walmart.com", "General merchandise"),
    RetailerEntry.new("Apple Store", "apple.com", "Apple hardware & accessories"),
    RetailerEntry.new("Newegg", "newegg.com", "PC parts & tech"),
    RetailerEntry.new("Nike", "nike.com", "Athletic wear & shoes"),
    RetailerEntry.new("Adidas", "adidas.com", "Athletic wear & shoes"),
    RetailerEntry.new("Lululemon", "shop.lululemon.com", "Athletic apparel"),
    RetailerEntry.new("Costco", "costco.com", "Warehouse club"),
    RetailerEntry.new("Home Depot", "homedepot.com", "Home improvement"),
    RetailerEntry.new("Lowe's", "lowes.com", "Home improvement"),
    RetailerEntry.new("B&H Photo", "bhphotovideo.com", "Cameras & pro gear"),
    RetailerEntry.new("Etsy", "etsy.com", "Marketplace & handmade"),
    RetailerEntry.new("IKEA", "ikea.com", "Furniture & home"),
    RetailerEntry.new("Macy's", "macys.com", "Department store"),
    RetailerEntry.new("REI", "rei.com", "Outdoor gear")
  ].freeze

  def auto_fetch_retailers
    AUTO_RETAILERS
  end
end
