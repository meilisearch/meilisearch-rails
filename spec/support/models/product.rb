require 'support/active_record_schema'

ar_schema.create_table :products do |t|
  t.string :name
  t.string :href
  t.string :tags
  t.string :type
  t.text :description
  t.datetime :release_date
end

class Product < ActiveRecord::Base
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

class Camera < Product
end
