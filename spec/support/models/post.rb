posts_specification = Models::ModelSpecification.new(
  'Post',
  fields: [%i[title string]]
) do
  has_many :comments

  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('Post'), synchronous: true do
    attribute :comments do
      comments.map(&:body)
    end
  end

  scope :meilisearch_import, -> { includes(:comments) }
end

Models::ActiveRecord.initialize_model(posts_specification)

comments_specification = Models::ModelSpecification.new(
  'Comment',
  fields: [
    %i[post_id integer],
    %i[body string]
  ]
) do
  belongs_to :post

  include Meilisearch::Rails

  meilisearch
end

Models::ActiveRecord.initialize_model(comments_specification)
