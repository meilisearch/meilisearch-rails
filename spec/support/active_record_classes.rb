# This file setup all the fake classes used in the test suite.
# 1 - establish the connection between the test database
# 2 - define the database schema
# 3 - create the classes with Meilisearch configuration

require 'active_record'

unless OLD_RAILS || NEW_RAILS
  require 'active_job/test_helper'

  ActiveJob::Base.queue_adapter = :test
end

FileUtils.rm('data.sqlite3') if File.exist?('data.sqlite3')

ActiveRecord::Base.logger = Logger.new($stdout)
ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.establish_connection(
  'adapter' => defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3',
  'database' => 'data.sqlite3',
  'pool' => 5,
  'timeout' => 5000
)

ActiveRecord::Base.raise_in_transactional_callbacks = true if ActiveRecord::Base.respond_to?(:raise_in_transactional_callbacks)

ActiveRecord::Schema.define do
  create_table :fruits do |t|
    t.string :name
  end
  create_table :tasks do |t|
    t.string :title
  end
  create_table :vegetables do |t|
    t.string :name
  end
  create_table :songs do |t|
    t.string :name
    t.string :artist
    t.boolean :released
    t.boolean :premium
  end
  create_table :cats do |t|
    t.string :name
  end
  create_table :dogs do |t|
    t.string :name
  end
  create_table :people do |t|
    t.string :first_name
    t.string :last_name
    t.integer :card_number
  end
  create_table :movies do |t|
    t.string :title
  end
  create_table :restaurants do |t|
    t.string :name
    t.string :kind
    t.text :description
  end
  create_table :products do |t|
    t.string :name
    t.string :href
    t.string :tags
    t.string :type
    t.text :description
    t.datetime :release_date
  end
  create_table :colors do |t|
    t.string :name
    t.string :short_name
    t.integer :hex
  end
  create_table :namespaced_models do |t|
    t.string :name
    t.integer :another_private_value
  end
  create_table :uniq_users, id: false do |t|
    t.string :name
  end
  create_table :nullable_ids
  create_table :nested_items do |t|
    t.integer :parent_id
    t.boolean :hidden
  end
  create_table :posts do |t|
    t.string :title
  end
  create_table :comments do |t|
    t.integer :post_id
    t.string :body
  end
  create_table :mongo_documents do |t|
    t.string :name
  end
  create_table :books do |t|
    t.string :name
    t.string :author
    t.boolean :premium
    t.boolean :released
    t.string :genre
  end
  create_table :ebooks do |t|
    t.string :name
    t.string :author
    t.boolean :premium
    t.boolean :released
  end
  create_table :disabled_booleans do |t|
    t.string :name
  end
  create_table :disabled_procs do |t|
    t.string :name
  end
  create_table :disabled_symbols do |t|
    t.string :name
  end
  create_table :encoded_strings
  unless OLD_RAILS
    create_table :enqueued_documents do |t|
      t.string :name
    end
    create_table :disabled_enqueued_documents do |t|
      t.string :name
    end
  end
  create_table :conditionally_enqueued_documents do |t|
    t.string :name
    t.boolean :is_public
  end
  create_table :misconfigured_blocks do |t|
    t.string :name
  end
  if defined?(ActiveModel::Serializer)
    create_table :serialized_documents do |t|
      t.string :name
      t.string :skip
    end
  end
end

class Product < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch auto_index: false,
              if: :published?, unless: ->(o) { o.href.blank? },
              index_uid: safe_index_uid('my_products_index') do
    attribute :href, :name

    synonyms({
               iphone: %w[applephone iBidule],
               pomme: ['apple'],
               samsung: ['galaxy'],
               m_b_p: ['macbookpro']
             })
  end

  def published?
    release_date.blank? || release_date <= Time.now
  end
end

class Camera < Product
end

class Restaurant < ActiveRecord::Base
  include GlobalID::Identification
  include MeiliSearch::Rails

  meilisearch index_uid: safe_index_uid('Restaurant') do
    attributes_to_crop [:description]
    crop_length 10
    pagination max_total_hits: 5
  end
end

class Movie < ActiveRecord::Base
  include MeiliSearch::Rails
  meilisearch index_uid: safe_index_uid('Movie') do
    pagination max_total_hits: 5
    typo_tolerance enabled: false
  end
end

class People < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('MyCustomPeople'), primary_key: :card_number,
              auto_remove: false do
    add_attribute :full_name
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def will_save_change_to_full_name?
    will_save_change_to_first_name? || will_save_change_to_last_name?
  end
end

class Cat < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch index_uid: safe_index_uid('animals'), synchronous: true, primary_key: :ms_id

  private

  def ms_id
    "cat_#{id}"
  end
end

class Dog < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch index_uid: safe_index_uid('animals'), synchronous: true, primary_key: :ms_id

  private

  def ms_id
    "dog_#{id}"
  end
end

class Song < ActiveRecord::Base
  include MeiliSearch::Rails

  PUBLIC_INDEX_UID  = safe_index_uid('Songs')
  SECURED_INDEX_UID = safe_index_uid('PrivateSongs')

  meilisearch index_uid: SECURED_INDEX_UID do
    searchable_attributes %i[name artist]

    add_index PUBLIC_INDEX_UID, if: :public? do
      searchable_attributes %i[name artist]
    end
  end

  private

  def public?
    released && !premium
  end
end

class Fruit < ActiveRecord::Base
  include MeiliSearch::Rails

  # only raise exceptions in development env
  meilisearch raise_on_failure: true, index_uid: safe_index_uid('Fruit') do
    attribute :name
  end
end

class Vegetable < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch raise_on_failure: false, index_uid: safe_index_uid('Fruit') do
    attribute :name
  end
end

class Color < ActiveRecord::Base
  include MeiliSearch::Rails
  attr_accessor :not_indexed

  meilisearch synchronous: true, index_uid: safe_index_uid('Color') do
    searchable_attributes [:name]
    filterable_attributes ['short_name']
    sortable_attributes [:name]
    ranking_rules [
      'words',
      'typo',
      'proximity',
      'attribute',
      'sort',
      'exactness',
      'hex:asc'
    ]
    attributes_to_highlight [:name]
    faceting max_values_per_facet: 20
  end

  def will_save_change_to_hex?
    false
  end

  def will_save_change_to_short_name?
    false
  end
end

class DisabledBoolean < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, disable_indexing: true, index_uid: safe_index_uid('DisabledBoolean')
end

class DisabledProc < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, disable_indexing: proc { true }, index_uid: safe_index_uid('DisabledProc')
end

class DisabledSymbol < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, disable_indexing: :truth, index_uid: safe_index_uid('DisabledSymbol')

  def self.truth
    true
  end
end

module Namespaced
  def self.table_name_prefix
    'namespaced_'
  end
end

module Namespaced
  class Model < ActiveRecord::Base
    include MeiliSearch::Rails

    meilisearch synchronous: true, index_uid: safe_index_uid(ms_index_uid({})) do
      attribute :customAttr do
        40 + another_private_value
      end
      attribute :myid do
        id
      end
      searchable_attributes ['customAttr']
    end
  end
end

class UniqUser < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('UniqUser'), primary_key: :name
end

class NullableId < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('NullableId'), primary_key: :custom_id,
              if: :never

  def custom_id
    nil
  end

  def never
    false
  end
end

class NestedItem < ActiveRecord::Base
  has_many :children, class_name: 'NestedItem', foreign_key: 'parent_id'

  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('NestedItem'), unless: :hidden do
    attribute :nb_children
  end

  def nb_children
    children.count
  end
end

class Post < ActiveRecord::Base
  has_many :comments

  include MeiliSearch::Rails

  meilisearch index_uid: safe_index_uid('Post'), synchronous: true do
    attribute :comments do
      comments.map(&:body)
    end
  end

  scope :meilisearch_import, -> { includes(:comments) }
end

class Comment < ActiveRecord::Base
end

class Task < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('Task')
end

class MongoDocument < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch index_uid: safe_index_uid('MongoDocument')

  def self.reindex!
    raise NameError, 'never reached'
  end

  def index!
    raise NameError, 'never reached'
  end
end

class Book < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('SecuredBook'), sanitize: true do
    searchable_attributes [:name]
    typo_tolerance min_word_size_for_typos: { one_typo: 5, twoTypos: 8 }
    filterable_attributes %i[genre author]
    faceting max_values_per_facet: 3

    add_index safe_index_uid('BookAuthor') do
      searchable_attributes [:author]
    end

    add_index safe_index_uid('Book'), if: :public? do
      searchable_attributes [:name]
    end
  end

  private

  def public?
    released && !premium
  end
end

class Ebook < ActiveRecord::Base
  include MeiliSearch::Rails
  attr_accessor :current_time, :published_at

  meilisearch synchronous: true, index_uid: safe_index_uid('eBooks') do
    searchable_attributes [:name]
  end

  def ms_dirty?
    return true if published_at.nil? || current_time.nil?

    # Consider dirty if published date is in the past
    # This doesn't make so much business sense but it's easy to test.
    published_at < current_time
  end
end

class EncodedString < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, force_utf8_encoding: true, index_uid: safe_index_uid('EncodedString') do
    attribute :value do
      "\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('ascii-8bit')
    end
  end
end

unless OLD_RAILS
  class EnqueuedDocument < ActiveRecord::Base
    include MeiliSearch::Rails

    include GlobalID::Identification

    def id
      read_attribute(:id)
    end

    def self.find(_id)
      EnqueuedDocument.first
    end

    meilisearch enqueue: proc { |record| raise "enqueued #{record.name}" },
                index_uid: safe_index_uid('EnqueuedDocument') do
      attributes [:name]
    end
  end

  class DisabledEnqueuedDocument < ActiveRecord::Base
    include MeiliSearch::Rails

    meilisearch(enqueue: proc { |_record| raise 'enqueued' },
                index_uid: safe_index_uid('EnqueuedDocument'),
                disable_indexing: true) do
      attributes [:name]
    end
  end

  class ConditionallyEnqueuedDocument < ActiveRecord::Base
    include MeiliSearch::Rails

    meilisearch(enqueue: true,
                index_uid: safe_index_uid('ConditionallyEnqueuedDocument'),
                if: :should_index?) do
      attributes %i[name is_public]
    end

    def should_index?
      is_public
    end
  end
end

class MisconfiguredBlock < ActiveRecord::Base
  include MeiliSearch::Rails
end

if defined?(ActiveModel::Serializer)
  class SerializedDocumentSerializer < ActiveModel::Serializer
    attributes :name
  end

  class SerializedDocument < ActiveRecord::Base
    include MeiliSearch::Rails

    meilisearch index_uid: safe_index_uid('SerializedDocument') do
      use_serializer SerializedDocumentSerializer
    end
  end
end
