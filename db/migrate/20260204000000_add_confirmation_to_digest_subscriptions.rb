# frozen_string_literal: true

class AddConfirmationToDigestSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :digest_subscriptions, :confirmation_token, :string
    add_column :digest_subscriptions, :confirmed_at, :datetime
    add_column :digest_subscriptions, :confirmation_sent_at, :datetime

    add_index :digest_subscriptions, :confirmation_token, unique: true

    # Existing subscriptions are considered confirmed
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE digest_subscriptions
          SET confirmed_at = created_at
          WHERE confirmed_at IS NULL
        SQL
      end
    end
  end
end
