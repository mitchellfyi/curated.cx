# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_27_172112) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.boolean "allow_paths", default: true, null: false
    t.jsonb "shown_fields", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "key"], name: "index_categories_on_tenant_id_and_key", unique: true
    t.index ["tenant_id", "name"], name: "index_categories_on_tenant_name"
    t.index ["tenant_id"], name: "index_categories_on_tenant_id"
  end

  create_table "listings", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "category_id", null: false
    t.text "url_raw", null: false
    t.text "url_canonical", null: false
    t.string "domain"
    t.string "title"
    t.text "description"
    t.text "image_url"
    t.string "site_name"
    t.datetime "published_at"
    t.text "body_html"
    t.text "body_text"
    t.jsonb "ai_summaries", default: {}, null: false
    t.jsonb "ai_tags", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "published_at"], name: "index_listings_on_category_published"
    t.index ["category_id"], name: "index_listings_on_category_id"
    t.index ["domain"], name: "index_listings_on_domain"
    t.index ["published_at"], name: "index_listings_on_published_at"
    t.index ["tenant_id", "category_id"], name: "index_listings_on_tenant_id_and_category_id"
    t.index ["tenant_id", "domain", "published_at"], name: "index_listings_on_tenant_domain_published"
    t.index ["tenant_id", "published_at", "created_at"], name: "index_listings_on_tenant_published_created"
    t.index ["tenant_id", "title"], name: "index_listings_on_tenant_title"
    t.index ["tenant_id", "url_canonical"], name: "index_listings_on_tenant_and_url_canonical", unique: true
    t.index ["tenant_id"], name: "index_listings_on_tenant_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.string "resource_type"
    t.bigint "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "hostname", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.text "description"
    t.string "logo_url"
    t.jsonb "settings", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hostname"], name: "index_tenants_on_hostname", unique: true
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
    t.index ["status", "hostname"], name: "index_tenants_on_status_hostname"
    t.index ["status"], name: "index_tenants_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "role_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  add_foreign_key "categories", "tenants"
  add_foreign_key "listings", "categories"
  add_foreign_key "listings", "tenants"
end
