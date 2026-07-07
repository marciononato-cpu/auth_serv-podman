class AddAdminResetFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin_reset_code1, :string
    add_column :users, :admin_reset_code2, :string
    add_column :users, :admin_reset_sent_at, :datetime
  end
end
