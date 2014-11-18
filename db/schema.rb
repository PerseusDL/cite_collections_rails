# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140507182422) do

  create_table "authors", force: true do |t|
    t.string   "urn"
    t.string   "authority_name"
    t.string   "canonical_id"
    t.string   "mads_file"
    t.string   "alt_ids"
    t.text     "related_works"
    t.string   "urn_status"
    t.string   "redirect_to"
    t.string   "created_by"
    t.string   "edited_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "textgroups", force: true do |t|
    t.string   "urn"
    t.string   "textgroup"
    t.string   "groupname_eng"
    t.string   "has_mads"
    t.string   "mads_possible"
    t.text     "notes"
    t.string   "urn_status"
    t.string   "redirect_to"
    t.string   "created_by"
    t.string   "edited_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "versions", force: true do |t|
    t.string   "urn"
    t.string   "version"
    t.text     "label_eng"
    t.text     "desc_eng"
    t.string   "ver_type"
    t.string   "has_mods"
    t.string   "urn_status"
    t.string   "redirect_to"
    t.string   "member_of"
    t.string   "created_by"
    t.string   "edited_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "works", force: true do |t|
    t.string   "urn"
    t.string   "work"
    t.text     "title_eng"
    t.string   "orig_lang"
    t.text     "notes"
    t.string   "urn_status"
    t.string   "redirect_to"
    t.string   "created_by"
    t.string   "edited_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
