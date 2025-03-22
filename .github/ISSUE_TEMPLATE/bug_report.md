---
name: Bug Report 🐞
about: Create a report to help us improve.
title: ''
labels: ["bug"]
assignees: ''
---

<!-- This is not an exhaustive model but a help. No step is mandatory. -->

### Description
<!-- Description of what the bug is about. -->

### Expected behavior
<!-- What you expected to happen. -->

### Current behavior
<!-- What happened. -->

### Screenshots or logs
<!-- If applicable, add screenshots or logs to help explain your problem. -->

### Environment
**Operating System** [e.g. Debian GNU/Linux] (`cat /etc/*-release | head -n1`):

**Meilisearch version** (`./meilisearch --version`):

**meilisearch-rails version** (`bundle info meilisearch-rails`):

**rails version** (`bundle info rails`):

### Reproduction script:

<!-- Write a script that reproduces your issue. Feel free to get started with the example below -->

<!--
```ruby
require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  ruby '3.3.7'

  gem 'minitest', '~> 5.25', '>= 5.25.4'
  gem 'rails', '~> 8.0', '>= 8.0.2'
  gem 'sqlite3', '~> 2', platform: %i[rbx ruby]
  gem 'jdbc-sqlite3', platform: :jruby

  gem 'meilisearch-rails', ENV["MEILISEARCH_RAILS_VERSION"] || "~> 0.14.2"
  # If you want to test against changes that have been not released yet
  # gem "meilisearch-rails", github: "meilisearch/meilisearch-rails", branch: 'main'

  # Use MongoDB
  # gem 'mongoid', '~> 9.0', '>= 9.0.6' 

  # Use Sequel
  # gem 'sequel', '~> 5.90'

  # Open a debugging session with the `debugger` method
  # gem 'debug'
end

require 'minitest/autorun'

MeiliSearch::Rails.configuration = {
  meilisearch_url: ENV.fetch('MEILISEARCH_HOST', 'http://127.0.0.1:7700'),
  meilisearch_api_key: ENV.fetch('MEILISEARCH_API_KEY', 'masterKey'),
  per_environment: true
}

###############################
# ActiveRecord database setup #
###############################
# require 'active_record'
#
# ar_db_file = Tempfile.new
# ActiveRecord::Base.establish_connection(
#   'adapter' => defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3',
#   'database' => ar_db_file.path,
#   'pool' => 5,
#   'timeout' => 5000
# )
#
# ActiveRecord::Schema[8.0].define do
#   create_table "ar_books", force: :cascade do |t|
#     t.string "title"
#     t.string "author"
#     t.datetime "created_at", null: false
#     t.datetime "updated_at", null: false
#   end
# end
#
# class ArBook < ActiveRecord::Base
#   include MeiliSearch::Rails
#
#   meilisearch
# end

#########################
# Sequel database setup #
#########################
# require 'sequel'
#
# def sequel_db
#   @sequel_db_file ||= Tempfile.new
#   @sequel_db ||= Sequel.connect(if defined?(JRUBY_VERSION)
#                                   "jdbc:sqlite:#{@sequel_db_file.path}"
#                                 else
#                                   { 'adapter' => 'sqlite',
#                                     'database' => @sequel_db_file.path }
#                                 end)
# end
#
# sequel_db.create_table(:sequel_books) do
#   primary_key :id
#   String :title
#   String :author
# end
#
# class SequelBook < Sequel::Model(sequel_db)
#   plugin :active_model
#   include MeiliSearch::Rails
#
#   meilisearch
# end

##########################
# Mongoid database setup #
##########################
# Mongoid.load_configuration({
#   clients: {
#     default: {
#       database: "bug_report_#{SecureRandom.hex(8)}",
#       hosts: ['localhost:27017'],
#       options: {
#         read: { mode: :primary },
#         max_pool_size: 1
#       }
#     }
#   }
# })
#
# class MongoBook
#   include Mongoid::Document
#   include Mongoid::Timestamps
#
#   field :title, type: String
#   field :price_cents, type: Integer
#
#   include MeiliSearch::Rails
#
#   meilisearch
# end

# Run this method before searching to make sure Meilisearch is up to date
def await_last_task
  task = MeiliSearch::Rails.client.tasks['results'].first
  MeiliSearch::Rails.client.wait_for_task task['uid']
end

class BugTest < Minitest::Test
  def test_my_bug
    # your code here
  end
end
```
-->
