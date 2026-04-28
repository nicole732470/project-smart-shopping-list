class AddScrapingFieldsToProductsAndPriceRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :source_url,       :string
    add_column :products, :last_fetched_at,  :datetime
    add_column :products, :last_fetch_error, :string
    add_index  :products, :source_url

    add_column :price_records, :source, :string, default: "manual", null: false
    add_index  :price_records, :source
  end
end
