require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

OLD_RAILS = Gem.loaded_specs['rails'].version < Gem::Version.new('4.0')
NEW_RAILS = Gem.loaded_specs['rails'].version >= Gem::Version.new('6.0')

require 'active_record'
unless OLD_RAILS || NEW_RAILS
  require 'active_job/test_helper'
  ActiveJob::Base.queue_adapter = :test
end
require 'sqlite3' unless defined?(JRUBY_VERSION)
require 'logger'
require 'sequel'
require 'active_model_serializers'
require 'byebug'

MeiliSearch::Rails.configuration = {
  meilisearch_host: ENV.fetch('MEILISEARCH_HOST', 'http://127.0.0.1:7700'),
  meilisearch_api_key: ENV.fetch('MEILISEARCH_API_KEY', 'masterKey'),
  per_environment: true
}

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

SEQUEL_DB = Sequel.connect(if defined?(JRUBY_VERSION)
                             'jdbc:sqlite:sequel_data.sqlite3'
                           else
                             { 'adapter' => 'sqlite',
                               'database' => 'sequel_data.sqlite3' }
                           end)

unless SEQUEL_DB.table_exists?(:sequel_books)
  SEQUEL_DB.create_table(:sequel_books) do
    primary_key :id
    String :name
    String :author
    FalseClass :released
    FalseClass :premium
  end
end

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
  create_table :nullable_ids do |t|
  end
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
  create_table :encoded_strings do |t|
  end
  unless OLD_RAILS
    create_table :enqueued_documents do |t|
      t.string :name
    end
    create_table :disabled_enqueued_documents do |t|
      t.string :name
    end
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
               apple: ['pomme'],
               samsung: ['galaxy']
             })
  end

  def published?
    release_date.blank? || release_date <= Time.now
  end
end

class Camera < Product
end

class Restaurant < ActiveRecord::Base
  include MeiliSearch::Rails
  meilisearch index_uid: safe_index_uid('Restaurant') do
    attributes_to_crop [:description]
    crop_length 10
  end
end

class Movies < ActiveRecord::Base
  include MeiliSearch::Rails
  meilisearch index_uid: safe_index_uid('Movies') do
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

  meilisearch index_uid: safe_index_uid('animals'), synchronous: true, primary_key: :ms_id do
  end

  private

  def ms_id
    "cat_#{id}"
  end
end

class Dog < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch index_uid: safe_index_uid('animals'), synchronous: true, primary_key: :ms_id do
  end

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

  meilisearch synchronous: true, disable_indexing: true, index_uid: safe_index_uid('DisabledBoolean') do
  end
end

class DisabledProc < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, disable_indexing: proc { true }, index_uid: safe_index_uid('DisabledProc') do
  end
end

class DisabledSymbol < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, disable_indexing: :truth, index_uid: safe_index_uid('DisabledSymbol') do
  end

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

  meilisearch synchronous: true, index_uid: safe_index_uid('UniqUser'), primary_key: :name do
  end
end

class NullableId < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('NullableId'), primary_key: :custom_id,
              if: :never do
  end

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

  meilisearch synchronous: true do
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

  meilisearch synchronous: true, index_uid: safe_index_uid('Task') do
  end
end

class SequelBook < Sequel::Model(SEQUEL_DB)
  plugin :active_model

  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('SequelBook'), sanitize: true do
    add_attribute :test
    add_attribute :test2

    searchable_attributes [:name]
  end

  def after_create
    SequelBook.new
  end

  def test
    'test'
  end

  def test2
    'test2'
  end

  private

  def public?
    released && !premium
  end
end

describe 'SequelBook' do
  before(:all) do
    SequelBook.clear_index!(true)
  end

  it 'indexes the book' do
    steve_jobs = SequelBook.create name: 'Steve Jobs', author: 'Walter Isaacson', premium: true, released: true
    results = SequelBook.search('steve')

    expect(results.size).to eq(1)
    expect(results[0].id).to eq(steve_jobs.id)
  end

  it 'does not override after hooks' do
    expect(SequelBook).to receive(:new).twice.and_call_original
    SequelBook.create name: 'Steve Jobs', author: 'Walter Isaacson', premium: true, released: true
  end
end

class MongoDocument < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch index_uid: safe_index_uid('MongoDocument') do
  end

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

    meilisearch enqueue: proc { |record| raise "enqueued #{record.id}" },
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

if defined?(ActiveModel::Serializer)
  describe 'SerializedDocument' do
    before(:all) do
      SerializedDocument.clear_index!(true)
    end

    it 'pushes the name but not the other attribute' do
      o = SerializedDocument.new name: 'test', skip: 'skip me'
      attributes = SerializedDocument.meilisearch_settings.get_attributes(o)
      expect(attributes).to eq({ name: 'test' })
    end
  end
end

describe 'Encoding' do
  before(:all) do
    EncodedString.clear_index!(true)
  end

  it 'converts to utf-8' do
    EncodedString.create!
    results = EncodedString.raw_search ''
    expect(results['hits'].size).to eq(1)
    expect(results['hits'].first['value']).to eq("\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('utf-8'))
  end
end

describe 'Settings change detection' do
  it 'detects settings changes' do
    expect(Color.send(:meilisearch_settings_changed?, nil, {})).to be(true)
    expect(Color.send(:meilisearch_settings_changed?, {}, { 'searchableAttributes' => ['name'] })).to be(true)
    expect(Color.send(:meilisearch_settings_changed?, { 'searchableAttributes' => ['name'] },
                      { 'searchableAttributes' => %w[name hex] })).to be(true)
    expect(Color.send(:meilisearch_settings_changed?, { 'searchableAttributes' => ['name'] },
                      { 'rankingRules' => ['words', 'typo', 'proximity', 'attribute', 'sort', 'exactness', 'hex:asc'] })).to be(true)
  end

  it 'does not detect settings changes' do
    expect(Color.send(:meilisearch_settings_changed?, {}, {})).to be(false)
    expect(Color.send(:meilisearch_settings_changed?, { 'searchableAttributes' => ['name'] },
                      { searchableAttributes: ['name'] })).to be(false)
    expect(Color.send(:meilisearch_settings_changed?,
                      { 'searchableAttributes' => ['name'], 'rankingRules' => ['words', 'typo', 'proximity', 'attribute', 'sort', 'exactness', 'hex:asc'] }, { 'rankingRules' => ['words', 'typo', 'proximity', 'attribute', 'sort', 'exactness', 'hex:asc'] })).to be(false)
  end
end

describe 'Attributes change detection' do
  it 'detects attribute changes' do
    color = Color.new name: 'dark-blue', short_name: 'blue'

    expect(Color.ms_must_reindex?(color)).to be(true)
    color.save
    expect(Color.ms_must_reindex?(color)).to be(false)

    color.hex = 123_456
    expect(Color.ms_must_reindex?(color)).to be(false)

    color.not_indexed = 'strstr'
    expect(Color.ms_must_reindex?(color)).to be(false)
    color.name = 'red'
    expect(Color.ms_must_reindex?(color)).to be(true)
    color.delete
  end

  it 'detects attribute changes even in a transaction' do
    color = Color.new name: 'dark-blue', short_name: 'blue'
    color.save
    expect(color.instance_variable_get('@ms_must_reindex')).to be_nil
    Color.transaction do
      color.name = 'red'
      color.save
      color.not_indexed = 'strstr'
      color.save
      expect(color.instance_variable_get('@ms_must_reindex')).to be(true)
    end
    expect(color.instance_variable_get('@ms_must_reindex')).to be_nil
    color.delete
  end

  it 'detects change with ms_dirty? method' do
    ebook = Ebook.new name: 'My life', author: 'Myself', premium: false, released: true
    expect(Ebook.ms_must_reindex?(ebook)).to be(true) # Because it's defined in ms_dirty? method
    ebook.current_time = 10
    ebook.published_at = 8
    expect(Ebook.ms_must_reindex?(ebook)).to be(true)
    ebook.published_at = 12
    expect(Ebook.ms_must_reindex?(ebook)).to be(false)
  end
end

describe 'Namespaced::Model' do
  before(:all) do
    Namespaced::Model.index.delete_all_documents!
  end

  it 'has an index name without :: hierarchy' do
    expect(Namespaced::Model.index_uid.include?('Namespaced_Model')).to be(true)
  end

  it 'uses the block to determine attribute\'s value' do
    m = Namespaced::Model.new(another_private_value: 2)
    attributes = Namespaced::Model.meilisearch_settings.get_attributes(m)
    expect(attributes['customAttr']).to eq(42)
    expect(attributes['myid']).to eq(m.id)
  end

  it 'always updates when there is no custom _changed? function' do
    m = Namespaced::Model.new(another_private_value: 2)
    m.save
    results = Namespaced::Model.search('42')
    expect(results.size).to eq(1)
    expect(results[0].id).to eq(m.id)

    m.another_private_value = 5
    m.save

    results = Namespaced::Model.search('42')
    expect(results.size).to eq(0)

    results = Namespaced::Model.search('45')
    expect(results.size).to eq(1)
    expect(results[0].id).to eq(m.id)
  end
end

# describe 'UniqUsers' do
#   before(:all) do
#     UniqUser.clear_index!(true)
#   end

#   it 'should not use the id field' do
#     UniqUser.create name: 'fooBar'
#     results = UniqUser.search('foo')
#     expect(results.size).to eq(1)
#   end
# end

describe 'NestedItem' do
  before(:all) do
    NestedItem.clear_index!(true)
  rescue StandardError
    # not fatal
  end

  it 'fetches attributes unscoped' do
    i1 = NestedItem.create hidden: false
    i2 = NestedItem.create hidden: true

    i1.children << NestedItem.create(hidden: true) << NestedItem.create(hidden: true)
    NestedItem.where(id: [i1.id, i2.id]).reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)

    result = NestedItem.index.get_document(i1.id)
    expect(result['nb_children']).to eq(2)

    result = NestedItem.raw_search('')
    expect(result['hits'].size).to eq(1)

    if i2.respond_to? :update_attributes
      i2.update_attributes hidden: false # rubocop:disable Rails/ActiveRecordAliases
    else
      i2.update hidden: false
    end

    result = NestedItem.raw_search('')
    expect(result['hits'].size).to eq(2)
  end
end

describe 'Posts' do
  before(:all) do
    Post.clear_index!(true)
  end

  it 'eagerly loads associations' do
    post1 = Post.new(title: 'foo')
    post1.comments << Comment.new(body: 'one')
    post1.comments << Comment.new(body: 'two')
    post1.save!

    post2 = Post.new(title: 'bar')
    post2.comments << Comment.new(body: 'three')
    post2.comments << Comment.new(body: 'four')
    post2.save!

    assert_queries(2) do
      Post.reindex!
    end
  end
end

describe 'Colors' do
  before(:all) do
    Color.clear_index!(true)
  end

  it 'is synchronous' do
    c = Color.new
    c.valid?
    expect(c.send(:ms_synchronous?)).to be(true)
  end

  it 'auto indexes' do
    blue = Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
    results = Color.search('blue')
    expect(results.size).to eq(1)
    expect(results).to include(blue)
  end

  it 'returns facets distribution' do
    results = Color.search('', { facets: ['short_name'] })
    expect(results.raw_answer).not_to be_nil
    expect(results.facets_distribution).not_to be_nil
    expect(results.facets_distribution.size).to eq(1)
    expect(results.facets_distribution['short_name']['b']).to eq(1)
  end

  it 'is raw searchable' do
    results = Color.raw_search('blue')
    expect(results['hits'].size).to eq(1)
    expect(results['estimatedTotalHits']).to eq(1)
  end

  it 'is able to temporarily disable auto-indexing' do
    Color.without_auto_index do
      Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
    end
    expect(Color.search('blue').size).to eq(1)
    Color.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(Color.search('blue').size).to eq(2)
  end

  it 'is not searchable with non-searchable fields' do
    Color.create!(name: 'blue', short_name: 'x', hex: 0xFF0000)
    results = Color.search('x')
    expect(results.size).to eq(0)
  end

  it 'ranks with custom hex' do
    Color.create!(name: 'red', short_name: 'r3', hex: 3)
    Color.create!(name: 'red', short_name: 'r1', hex: 1)
    Color.create!(name: 'red', short_name: 'r2', hex: 2)
    results = Color.search('red')
    expect(results.size).to eq(3)
    expect(results[0].hex).to eq(1)
    expect(results[1].hex).to eq(2)
    expect(results[2].hex).to eq(3)
  end

  it 'updates the index if the attribute changed' do
    purple = Color.create!(name: 'purple', short_name: 'p')
    expect(Color.search('purple').size).to eq(1)
    expect(Color.search('pink').size).to eq(0)
    purple.name = 'pink'
    purple.save
    expect(Color.search('purple').size).to eq(0)
    expect(Color.search('pink').size).to eq(1)
  end

  it 'uses the specified scope' do
    Color.clear_index!(true)
    Color.where(name: 'red').reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(Color.search('').size).to eq(3)
    Color.clear_index!(true)
    Color.where(id: Color.first.id).reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(Color.search('').size).to eq(1)
  end

  it 'has a Rails env-based index name' do
    expect(Color.index_uid).to eq(safe_index_uid('Color') + "_#{Rails.env}")
  end

  it 'includes _formatted object' do
    Color.create!(name: 'green', short_name: 'b', hex: 0xFF0000)
    results = Color.search('gre')
    expect(results.size).to eq(1)
    expect(results[0].formatted).not_to be_nil
  end

  it 'indexes an array of documents' do
    json = Color.raw_search('')
    Color.index_documents Color.limit(1), true # reindex last color, `limit` is incompatible with the reindex! method
    expect(json['hits'].count).to eq(Color.raw_search('')['hits'].count)
  end

  it 'does not index non-saved document' do
    expect { Color.new(name: 'purple').index!(true) }.to raise_error(ArgumentError)
    expect { Color.new(name: 'purple').remove_from_index!(true) }.to raise_error(ArgumentError)
  end

  it 'searches with filter' do
    Color.create!(name: 'blue', short_name: 'blu', hex: 0x0000FF)
    black = Color.create!(name: 'black', short_name: 'bla', hex: 0x000000)
    Color.create!(name: 'green', short_name: 'gre', hex: 0x00FF00)
    facets = Color.search('bl', { filter: ['short_name = bla'] })
    expect(facets.size).to eq(1)
    expect(facets).to include(black)
  end

  it 'searches with sorting' do
    Color.delete_all

    blue = Color.create!(name: 'blue', short_name: 'blu', hex: 0x0000FF)
    black = Color.create!(name: 'black', short_name: 'bla', hex: 0x000000)
    green = Color.create!(name: 'green', short_name: 'gre', hex: 0x00FF00)

    facets = Color.search('*', { sort: ['name:asc'] })

    expect(facets).to eq([black, blue, green])
  end
end

describe 'An imaginary store' do
  before(:all) do
    Product.clear_index!(true)

    # Google products
    @blackberry = Product.create!(name: 'blackberry', href: 'google', tags: ['decent', 'businessmen love it'])
    @nokia = Product.create!(name: 'nokia', href: 'google', tags: ['decent'])

    # Amazon products
    @android = Product.create!(name: 'android', href: 'amazon', tags: ['awesome'])
    @samsung = Product.create!(name: 'samsung', href: 'amazon', tags: ['decent'])
    @motorola = Product.create!(name: 'motorola', href: 'amazon', tags: ['decent'],
                                description: 'Not sure about features since I\'ve never owned one.')

    # Ebay products
    @palmpre = Product.create!(name: 'palmpre', href: 'ebay', tags: ['discontinued', 'worst phone ever'])
    @palm_pixi_plus = Product.create!(name: 'palm pixi plus', href: 'ebay', tags: ['terrible'])
    @lg_vortex = Product.create!(name: 'lg vortex', href: 'ebay', tags: ['decent'])
    @t_mobile = Product.create!(name: 't mobile', href: 'ebay', tags: ['terrible'])

    # Yahoo products
    @htc = Product.create!(name: 'htc', href: 'yahoo', tags: ['decent'])
    @htc_evo = Product.create!(name: 'htc evo', href: 'yahoo', tags: ['decent'])
    @ericson = Product.create!(name: 'ericson', href: 'yahoo', tags: ['decent'])

    # Apple products
    @iphone = Product.create!(name: 'iphone', href: 'apple', tags: ['awesome', 'poor reception'],
                              description: 'Puts even more features at your fingertips')

    # Unindexed products
    @sekrit = Product.create!(name: 'super sekrit', href: 'amazon', release_date: Time.now + 1.day)
    @no_href = Product.create!(name: 'super sekrit too; missing href')

    # Subproducts
    @camera = Camera.create!(name: 'canon eos rebel t3', href: 'canon')

    100.times { Product.create!(name: 'crapoola', href: 'crappy', tags: ['crappy']) }

    @products_in_database = Product.all

    Product.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    sleep 5
  end

  it 'is not synchronous' do
    p = Product.new
    p.valid?

    expect(p).not_to be_ms_synchronous
  end

  it 'is able to reindex manually' do
    results_before_clearing = Product.raw_search('')
    expect(results_before_clearing['hits'].size).not_to be(0)
    Product.clear_index!(true)
    results = Product.raw_search('')
    expect(results['hits'].size).to be(0)
    Product.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    results_after_reindexing = Product.raw_search('')
    expect(results_after_reindexing['hits'].size).not_to be(0)
    expect(results_before_clearing['hits'].size).to be(results_after_reindexing['hits'].size)
  end

  describe 'basic searching' do
    it 'finds the iphone' do
      results = Product.search('iphone')
      expect(results.size).to eq(1)
      expect(results).to include(@iphone)
    end

    it 'searches case insensitively' do
      results = Product.search('IPHONE')
      expect(results.size).to eq(1)
      expect(results).to include(@iphone)
    end

    it 'finds all amazon products' do
      results = Product.search('amazon')
      expect(results.size).to eq(3)
      expect(results).to include(@android, @samsung, @motorola)
    end

    it 'finds all "palm" phones with wildcard word search' do
      results = Product.search('pal')
      expect(results.size).to eq(2)
      expect(results).to include(@palmpre, @palm_pixi_plus)
    end

    it 'searches multiple words from the same field' do
      results = Product.search('palm pixi plus')
      expect(results.size).to eq(1)
      expect(results).to include(@palm_pixi_plus)
    end

    it 'finds using phrase search' do
      results = Product.search('coco "palm"')
      expect(results.size).to eq(1)
      expect(results).to include(@palm_pixi_plus)
    end

    it 'narrows the results by searching across multiple fields' do
      results = Product.search('apple iphone')
      expect(results.size).to eq(1)
      expect(results).to include(@iphone)
    end

    it 'does not search on non-indexed fields' do
      results = Product.search('features')
      expect(results.size).to eq(0)
    end

    it 'deletes the associated record' do
      @iphone.destroy
      results = Product.search('iphone')
      expect(results.size).to eq(0)
    end

    it 'does not throw an exception if a search result isn\'t found locally' do
      Product.without_auto_index { @palmpre.destroy }
      expect { Product.search('pal').to_json }.not_to raise_error
    end

    it 'returns the other results if those are still available locally' do
      Product.without_auto_index { @palmpre.destroy }
      expect(JSON.parse(Product.search('pal').to_json).size).to eq(1)
    end

    it 'does not duplicate an already indexed record' do
      expect(Product.search('nokia').size).to eq(1)
      @nokia.index!
      expect(Product.search('nokia').size).to eq(1)
      @nokia.index!
      @nokia.index!
      expect(Product.search('nokia').size).to eq(1)
    end

    it 'does not return products that are not indexable' do
      @sekrit.index!
      @no_href.index!
      results = Product.search('sekrit')
      expect(results.size).to eq(0)
    end

    it 'includes items belong to subclasses' do
      @camera.index!
      results = Product.search('eos rebel')
      expect(results.size).to eq(1)
      expect(results).to include(@camera)
    end

    it 'deletes a not-anymore-indexable product' do
      results = Product.search('sekrit')
      expect(results.size).to eq(0)

      @sekrit.release_date = Time.now - 1.day
      @sekrit.save!
      @sekrit.index!(true)
      results = Product.search('sekrit')
      expect(results.size).to eq(1)

      @sekrit.release_date = Time.now + 1.day
      @sekrit.save!
      @sekrit.index!(true)
      results = Product.search('sekrit')
      expect(results.size).to eq(0)
    end

    it 'finds using synonyms' do
      expect(Product.search('pomme').size).to eq(Product.search('apple').size)
    end
  end
end

describe 'MongoDocument' do
  it 'does not have method conflicts' do
    expect { MongoDocument.reindex! }.to raise_error(NameError)
    expect { MongoDocument.new.index! }.to raise_error(NameError)
    MongoDocument.ms_reindex!
    MongoDocument.create(name: 'mongo').ms_index!
  end
end

describe 'Book' do
  before(:all) do
    Book.clear_index!(true)
    Book.index(safe_index_uid('BookAuthor')).delete_all_documents
    Book.index(safe_index_uid('Book')).delete_all_documents
  end

  it 'indexes the book in 2 indexes of 3' do
    steve_jobs = Book.create! name: 'Steve Jobs', author: 'Walter Isaacson', premium: true, released: true
    results = Book.search('steve')
    expect(results.size).to eq(1)
    expect(results).to include(steve_jobs)

    index_author = Book.index(safe_index_uid('BookAuthor'))
    expect(index_author).not_to be_nil
    results = index_author.search('steve')
    expect(results['hits'].length).to eq(0)
    results = index_author.search('walter')
    expect(results['hits'].length).to eq(1)

    # premium -> not part of the public index
    index_book = Book.index(safe_index_uid('Book'))
    expect(index_book).not_to be_nil
    results = index_book.search('steve')
    expect(results['hits'].length).to eq(0)
  end

  it 'sanitizes attributes' do
    _hack = Book.create! name: '"><img src=x onerror=alert(1)> hack0r',
                         author: '<script type="text/javascript">alert(1)</script>', premium: true, released: true
    b = Book.raw_search('hack', { attributesToHighlight: ['*'] })
    expect(b['hits'].length).to eq(1)
    begin
      expect(b['hits'][0]['name']).to eq('"> hack0r').and_raise(StandardError)
      expect(b['hits'][0]['author']).to eq('alert(1)')
      expect(b['hits'][0]['_formatted']['name']).to eq('"> <em>hack</em>0r')
    rescue StandardError
      # rails 4.2's sanitizer
      begin
        expect(b['hits'][0]['name']).to eq('&quot;&gt; hack0r').and_raise(StandardError)
        expect(b['hits'][0]['author']).to eq('')
        expect(b['hits'][0]['_formatted']['name']).to eq('&quot;&gt; <em>hack</em>0r')
      rescue StandardError
        # jruby
        expect(b['hits'][0]['name']).to eq('"&gt; hack0r')
        expect(b['hits'][0]['author']).to eq('')
        expect(b['hits'][0]['_formatted']['name']).to eq('"&gt; <em>hack</em>0r')
      end
    end
  end

  it 'handles removal in an extra index' do
    # add a new public book which (not premium but released)
    book = Book.create! name: 'Public book', author: 'me', premium: false, released: true

    # should be searchable in the 'Book' index
    index = Book.index(safe_index_uid('Book'))
    results = index.search('Public book')
    expect(results['hits'].size).to eq(1)

    # update the book and make it non-public anymore (not premium, not released)
    book.update released: false

    # should be removed from the index
    results = index.search('Public book')
    expect(results['hits'].size).to eq(0)
  end

  it 'uses the per_environment option in the additional index as well' do
    index = Book.index(safe_index_uid('Book'))
    expect(index.uid).to eq("#{safe_index_uid('Book')}_#{Rails.env}")
  end
end

describe 'Kaminari' do
  before(:all) do
    require 'kaminari'
    MeiliSearch::Rails.configuration = { meilisearch_host: ENV.fetch('MEILISEARCH_HOST', 'http://127.0.0.1:7700'),
                                         meilisearch_api_key: ENV.fetch('MEILISEARCH_API_KEY', 'masterKey'), pagination_backend: :kaminari }
    Restaurant.clear_index!(true)

    10.times do
      Restaurant.create(
        name: Faker::Restaurant.name,
        kind: Faker::Restaurant.type,
        description: Faker::Restaurant.description
      )
    end

    Restaurant.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    sleep 5
  end

  it 'paginates' do
    hits = Restaurant.search ''
    expect(hits.total_count).to eq(Restaurant.raw_search('')['hits'].size)

    p1 = Restaurant.search '', page: 1, hitsPerPage: 1
    expect(p1.size).to eq(1)
    expect(p1[0]).to eq(hits[0])
    expect(p1.total_count).to eq(Restaurant.raw_search('')['hits'].count)

    p2 = Restaurant.search '', page: 2, hitsPerPage: 1
    expect(p2.size).to eq(1)
    expect(p2[0]).to eq(hits[1])
    expect(p2.total_count).to eq(Restaurant.raw_search('')['hits'].count)
  end

  it 'does not return error if pagination params are strings' do
    p1 = Restaurant.search '', page: '1', hitsPerPage: '1'
    expect(p1.size).to eq(1)
    expect(p1.total_count).to eq(Restaurant.raw_search('')['hits'].count)

    p2 = Restaurant.search '', page: '2', hitsPerPage: '1'
    expect(p2.size).to eq(1)
    expect(p2.total_count).to eq(Restaurant.raw_search('')['hits'].count)
  end
end

describe 'Will_paginate' do
  before(:all) do
    require 'will_paginate'
    MeiliSearch::Rails.configuration = {
      meilisearch_host: ENV.fetch('MEILISEARCH_HOST', 'http://127.0.0.1:7700'),
      meilisearch_api_key: ENV.fetch('MEILISEARCH_API_KEY', 'masterKey'), pagination_backend: :will_paginate
    }
    Movies.clear_index!(true)

    10.times { Movies.create(title: Faker::Movie.title) }

    Movies.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    sleep 5
  end

  it 'paginates' do
    hits = Movies.search '', hitsPerPage: 2
    expect(hits.per_page).to eq(2)
    expect(hits.total_pages).to eq(5)
    expect(hits.total_entries).to eq(Movies.raw_search('')['hits'].count)
  end

  it 'returns most relevant elements in the first page' do
    hits = Movies.search '', hitsPerPage: 2
    raw_hits = Movies.raw_search ''
    expect(hits[0]['id']).to eq(raw_hits['hits'][0]['id'].to_i)

    hits = Movies.search '', hitsPerPage: 2, page: 2
    raw_hits = Movies.raw_search ''
    expect(hits[0]['id']).to eq(raw_hits['hits'][2]['id'].to_i)
  end

  it 'does not return error if pagination params are strings' do
    hits = Movies.search '', hitsPerPage: '5'
    expect(hits.per_page).to eq(5)
    expect(hits.total_pages).to eq(2)
    expect(hits.current_page).to eq(1)

    hits = Movies.search '', hitsPerPage: '5', page: '2'
    expect(hits.current_page).to eq(2)
  end
end

describe 'attributes_to_crop' do
  before(:all) do
    MeiliSearch::Rails.configuration = { meilisearch_host: ENV.fetch('MEILISEARCH_HOST', 'http://127.0.0.1:7700'),
                                         meilisearch_api_key: ENV.fetch('MEILISEARCH_API_KEY', 'masterKey') }
    10.times do
      Restaurant.create(
        name: Faker::Restaurant.name,
        kind: Faker::Restaurant.type,
        description: Faker::Restaurant.description
      )
    end

    Restaurant.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    sleep 5
  end

  it 'includes _formatted object' do
    results = Restaurant.search('')
    raw_search_results = Restaurant.raw_search('')
    expect(results[0].formatted).not_to be_nil
    expect(results[0].formatted).to eq(raw_search_results['hits'].first['_formatted'])
    expect(results.first.formatted['description'].length).to be < results.first['description'].length
    expect(results.first.formatted['description']).to eq(raw_search_results['hits'].first['_formatted']['description'])
    expect(results.first.formatted['description']).not_to eq(results.first['description'])
  end
end

describe 'Disabled' do
  before(:all) do
    DisabledBoolean.index.delete_all_documents!
    DisabledProc.index.delete_all_documents!
    DisabledSymbol.index.delete_all_documents!
  end

  it 'disables the indexing using a boolean' do
    DisabledBoolean.create name: 'foo'
    expect(DisabledBoolean.search('').size).to eq(0)
  end

  it 'disables the indexing using a proc' do
    DisabledProc.create name: 'foo'
    expect(DisabledProc.search('').size).to eq(0)
  end

  it 'disables the indexing using a symbol' do
    DisabledSymbol.create name: 'foo'
    expect(DisabledSymbol.search('').size).to eq(0)
  end
end

unless OLD_RAILS
  describe 'EnqueuedDocument' do
    it 'enqueues a job' do
      expect do
        EnqueuedDocument.create! name: 'test'
      end.to raise_error('enqueued 1')
    end

    it 'does not enqueue a job inside no index block' do
      expect do
        EnqueuedDocument.without_auto_index do
          EnqueuedDocument.create! name: 'test'
        end
      end.not_to raise_error
    end
  end

  describe 'DisabledEnqueuedDocument' do
    it 'does not try to enqueue a job' do
      expect do
        DisabledEnqueuedDocument.create! name: 'test'
      end.not_to raise_error
    end
  end
end

describe 'Misconfigured Block' do
  it 'forces the meilisearch block' do
    expect do
      MisconfiguredBlock.reindex!
    end.to raise_error(ArgumentError)
  end
end

describe 'People' do
  it 'adds custom complex attribute' do
    People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)
    result = People.raw_search('Jane')
    expect(result['hits'][0]['full_name']).to eq('Jane Doe')
  end

  it 'has as uid the custom name specified' do
    expect(People.index.uid).to eq(safe_index_uid('MyCustomPeople'))
  end

  it 'has the chosen field as custom primary key' do
    index = MeiliSearch::Rails.client.fetch_index(safe_index_uid('MyCustomPeople'))
    expect(index.primary_key).to eq('card_number')
  end

  it 'does not call the API if there has been no attribute change' do
    person = People.search('Jane').first

    expect do
      person.update(first_name: 'Jane')
    end.not_to change(People.index.tasks['results'], :size)
  end

  it 'does not auto-remove' do
    People.create(first_name: 'Joanna', last_name: 'Banana', card_number: 75_801_888)
    joanna = People.search('Joanna')[0]
    joanna.destroy
    result = People.raw_search('Joanna')
    expect(result['hits'].size).to eq(1)
  end

  it 'is able to remove manually' do
    bob = People.create(first_name: 'Bob', last_name: 'Sponge', card_number: 75_801_889)
    result = People.raw_search('Bob')
    expect(result['hits'].size).to eq(1)
    bob.remove_from_index!
    result = People.raw_search('Bob')
    expect(result['hits'].size).to eq(0)
  end

  it 'clears index manually' do
    results = People.raw_search('')
    expect(results['hits'].size).not_to eq(0)
    People.clear_index!(true)
    results = People.raw_search('')
    expect(results['hits'].size).to eq(0)
  end
end

describe 'Animals' do
  it 'returns only the requested type' do
    Dog.create!([{ name: 'Toby the Dog' }, { name: 'Felix the Dog' }])
    Cat.create!([{ name: 'Toby the Cat' }, { name: 'Felix the Cat' }, { name: 'roar' }])

    expect(Dog.count).to eq(2)
    expect(Cat.count).to eq(3)

    expect(Cat.search('felix').size).to eq(1)
    expect(Cat.search('felix').first.name).to eq('Felix the Cat')
    expect(Dog.search('toby').size).to eq(1)
    expect(Dog.search('Toby').first.name).to eq('Toby the Dog')
  end

  it 'shares a single index' do
    cat_index = Cat.index.instance_variable_get('@index').uid
    dog_index = Dog.index.instance_variable_get('@index').uid

    expect(cat_index).to eq(dog_index)
  end
end

describe 'Songs' do
  it 'targets multiple indices' do
    Song.create!(name: 'Coconut nut', artist: 'Smokey Mountain', premium: false, released: true) # Only song supposed to be added to Songs index
    Song.create!(name: 'Smoking hot', artist: 'Cigarettes before lunch', premium: true, released: true)
    Song.create!(name: 'Floor is lava', artist: 'Volcano', premium: true, released: false)
    Song.index.wait_for_task(Song.index.tasks['results'].first['uid'])
    MeiliSearch::Rails.client.index(safe_index_uid('PrivateSongs')).wait_for_task(MeiliSearch::Rails.client.index(safe_index_uid('PrivateSongs')).tasks['results'].first['uid'])
    results = Song.search('', index: safe_index_uid('Songs'))
    expect(results.size).to eq(1)
    raw_results = Song.raw_search('', index: safe_index_uid('Songs'))
    expect(raw_results['hits'].size).to eq(1)
    results = Song.search('', index: safe_index_uid('PrivateSongs'))
    expect(results.size).to eq(3)
    raw_results = Song.raw_search('', index: safe_index_uid('PrivateSongs'))
    expect(raw_results['hits'].size).to eq(3)
  end
end

describe 'Raise on failure' do
  before { Vegetable.instance_variable_set('@ms_indexes', nil) }

  it 'raises on failure' do
    expect do
      Fruit.search('', { filter: 'title = Nightshift' })
    end.to raise_error(MeiliSearch::ApiError)
  end

  it 'does not raise on failure' do
    expect do
      Vegetable.search('', { filter: 'title = Kale' })
    end.not_to raise_error
  end

  context 'when Meilisearch server take too long to answer' do
    let(:index_instance) { instance_double(MeiliSearch::Index, settings: nil, update_settings: nil) }
    let(:slow_client) { instance_double(MeiliSearch::Client, index: index_instance) }

    it 'does not raise error timeouts on reindex' do
      allow(index_instance).to receive(:add_documents).and_raise(MeiliSearch::TimeoutError)
      allow(slow_client).to receive(:create_index).and_return(index_instance)

      allow(MeiliSearch::Rails).to receive(:client).and_return(slow_client)

      expect do
        Vegetable.create(name: 'potato')
      end.not_to raise_error
    end

    it 'does not raise error timeouts on data addition' do
      allow(slow_client).to receive(:create_index).and_raise(MeiliSearch::TimeoutError)
      allow(index_instance).to receive(:add_documents).and_return(nil)

      allow(MeiliSearch::Rails).to receive(:client).and_return(slow_client)

      expect do
        Vegetable.ms_reindex!
      end.not_to raise_error
    end
  end
end

context "when have a internal class defined in the app's scope" do
  it 'does not raise NoMethodError' do
    Task.create(title: 'my task #1')

    expect do
      Task.search('task')
    end.not_to raise_error
  end
end
