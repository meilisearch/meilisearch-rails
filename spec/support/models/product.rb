products_specification = Models::ModelSpecification.new(
  'Product',
  fields: [
    %i[name string],
    %i[href string],
    %i[tags string],
    %i[type string],
    %i[description text],
    %i[release_date datetime]
  ]
) do
  include Meilisearch::Rails

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

Models::ActiveRecord.initialize_model(products_specification)

module Models
  module ActiveRecord
    class Camera < Product
    end
  end
end
