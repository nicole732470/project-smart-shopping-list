class AddBatchesRunToPriceRefreshRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :price_refresh_runs, :batches_run, :integer, null: false, default: 1
  end
end
