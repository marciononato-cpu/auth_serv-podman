class AddBackupEmailToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :backup_email, :string, default: nil, index: true
  end
end
