class AddAdvisorCacheToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :advisor_summary,      :text
    add_column :products, :advisor_source,       :string
    add_column :products, :advisor_generated_at, :datetime
  end
end
