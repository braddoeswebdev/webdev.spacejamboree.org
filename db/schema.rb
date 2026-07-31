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

ActiveRecord::Schema[8.1].define(version: 2026_07_31_185058) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "badges", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "completions", force: :cascade do |t|
    t.boolean "complete", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "participation_id", null: false
    t.integer "requirement_id", null: false
    t.datetime "updated_at", null: false
    t.index ["participation_id"], name: "index_completions_on_participation_id"
    t.index ["requirement_id", "participation_id"], name: "index_completions_on_requirement_id_and_participation_id", unique: true
    t.index ["requirement_id"], name: "index_completions_on_requirement_id"
  end

  create_table "internet_maps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "workshop_id", null: false
    t.index ["workshop_id"], name: "index_internet_maps_on_workshop_id"
  end

  create_table "network_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "end_node_id", null: false
    t.integer "hop_number"
    t.text "rtt_samples"
    t.boolean "spans_gap", default: false
    t.integer "start_node_id", null: false
    t.boolean "timed_out", default: false
    t.integer "traceroute_id", null: false
    t.datetime "updated_at", null: false
    t.index ["end_node_id"], name: "index_network_links_on_end_node_id"
    t.index ["start_node_id"], name: "index_network_links_on_start_node_id"
    t.index ["traceroute_id"], name: "index_network_links_on_traceroute_id"
  end

  create_table "network_nodes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "dedupe_key", null: false
    t.string "hostname"
    t.integer "internet_map_id", null: false
    t.string "ip_address"
    t.boolean "is_private", default: false
    t.integer "organization_id"
    t.integer "traceroute_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.float "x"
    t.float "y"
    t.index ["dedupe_key"], name: "index_network_nodes_on_dedupe_key", unique: true
    t.index ["internet_map_id"], name: "index_network_nodes_on_internet_map_id"
    t.index ["organization_id"], name: "index_network_nodes_on_organization_id"
    t.index ["traceroute_id"], name: "index_network_nodes_on_traceroute_id"
    t.index ["user_id"], name: "index_network_nodes_on_user_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.integer "resource_owner_id", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in"
    t.string "previous_refresh_token", default: "", null: false
    t.string "refresh_token"
    t.integer "resource_owner_id"
    t.datetime "revoked_at"
    t.string "scopes"
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "owner_id"
    t.string "owner_type"
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.string "secret", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_oauth_applications_on_owner"
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "oauth_openid_requests", force: :cascade do |t|
    t.integer "access_grant_id", null: false
    t.string "nonce", null: false
    t.index ["access_grant_id"], name: "index_oauth_openid_requests_on_access_grant_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.integer "asn"
    t.string "color"
    t.datetime "created_at", null: false
    t.string "name"
    t.string "org_domain"
    t.boolean "seeded", default: false
    t.datetime "updated_at", null: false
    t.index ["asn"], name: "index_organizations_on_asn", unique: true
  end

  create_table "participations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "workshop_id", null: false
    t.index ["user_id"], name: "index_participations_on_user_id"
    t.index ["workshop_id"], name: "index_participations_on_workshop_id"
  end

  create_table "requirements", force: :cascade do |t|
    t.integer "badge_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["badge_id"], name: "index_requirements_on_badge_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "impersonator_id"
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["impersonator_id"], name: "index_sessions_on_impersonator_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "traceroutes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "internet_map_id", null: false
    t.text "raw_output"
    t.integer "status", default: 0
    t.string "target_domain"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["internet_map_id"], name: "index_traceroutes_on_internet_map_id"
    t.index ["status"], name: "index_traceroutes_on_status"
    t.index ["user_id"], name: "index_traceroutes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "workshops", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "instructor_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["instructor_id"], name: "index_workshops_on_instructor_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "completions", "participations"
  add_foreign_key "completions", "requirements"
  add_foreign_key "internet_maps", "workshops"
  add_foreign_key "network_links", "network_nodes", column: "end_node_id"
  add_foreign_key "network_links", "network_nodes", column: "start_node_id"
  add_foreign_key "network_links", "traceroutes"
  add_foreign_key "network_nodes", "internet_maps"
  add_foreign_key "network_nodes", "organizations"
  add_foreign_key "network_nodes", "traceroutes"
  add_foreign_key "network_nodes", "users"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_grants", "users", column: "resource_owner_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "users", column: "resource_owner_id"
  add_foreign_key "oauth_openid_requests", "oauth_access_grants", column: "access_grant_id", on_delete: :cascade
  add_foreign_key "participations", "users"
  add_foreign_key "participations", "workshops"
  add_foreign_key "requirements", "badges"
  add_foreign_key "sessions", "sessions", column: "impersonator_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "traceroutes", "internet_maps"
  add_foreign_key "traceroutes", "users"
  add_foreign_key "workshops", "users", column: "instructor_id"
end
