require 'support/active_record_schema'

ar_schema.create_table :posts do |t|
  t.string :title
end

ar_schema.create_table :comments do |t|
  t.integer :post_id
  t.string :body
end

class Post < ActiveRecord::Base
  has_many :comments

  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('Post'), synchronous: true do
    attribute :comments do
      comments.map(&:body)
    end
  end

  scope :meilisearch_import, -> { includes(:comments) }
end

class Comment < ActiveRecord::Base
  belongs_to :post

  include Meilisearch::Rails

  meilisearch
end
