# frozen_string_literal: true

class CreateHeartbeatLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :heartbeat_logs do |t|
      t.datetime :executed_at, null: false
      t.string :environment, null: false
      t.string :hostname, null: false

      t.timestamps
    end

    add_index :heartbeat_logs, :executed_at
    add_index :heartbeat_logs, [ :environment, :executed_at ]
  end
end
