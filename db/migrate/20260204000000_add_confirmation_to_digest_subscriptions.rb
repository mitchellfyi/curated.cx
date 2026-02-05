# frozen_string_literal: true

class AddConfirmationToDigestSubscriptions < ActiveRecord::Migration[8.0]
  def change
    # Make idempotent - only add columns if they don't exist
    unless column_exists?(:digest_subscriptions, :confirmation_token)
      add_column :digest_subscriptions, :confirmation_token, :string
    end
    unless column_exists?(:digest_subscriptions, :confirmed_at)
      add_column :digest_subscriptions, :confirmed_at, :datetime
    end
    unless column_exists?(:digest_subscriptions, :confirmation_sent_at)
      add_column :digest_subscriptions, :confirmation_sent_at, :datetime
    end

    unless index_exists?(:digest_subscriptions, :confirmation_token)
      add_index :digest_subscriptions, :confirmation_token, unique: true
    end

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
