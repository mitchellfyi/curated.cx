class CreateTenantInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :tenant_invitations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :role, null: false, default: "viewer"
      t.string :token, null: false
      t.datetime :accepted_at
      t.datetime :expires_at, null: false

      t.timestamps
    end
    add_index :tenant_invitations, :token, unique: true
    add_index :tenant_invitations, [ :tenant_id, :email ], unique: true, where: "accepted_at IS NULL"
  end
end
