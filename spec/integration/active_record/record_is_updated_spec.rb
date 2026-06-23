require 'support/models/book'
require 'support/models/color'
require 'support/models/people'
require 'support/models/custom_attribute_builder_models'

describe 'When record is updated' do
  it 'updates the changed attributes on the index' do
    purple = Color.create!(name: 'purple', short_name: 'p')
    expect(Color.search('purple')).to be_one
    expect(Color.search('pink')).to be_empty

    purple.update name: 'pink'
    expect(Color.search('purple')).to be_empty
    expect(Color.search('pink')).to be_one
  end

  it 'automatically removes document from conditional indexes' do
    TestUtil.reset_books!

    # add a new public book which is public (not premium but released)
    book = Book.create! name: 'Public book', author: 'me', premium: false, released: true

    # should be searchable in the 'Book' index
    index = Book.index(safe_index_uid('Book'))
    results = index.search('Public book')
    expect(results['hits']).to be_one

    # update the book and make it non-public anymore (not premium, not released)
    book.update released: false

    # should be removed from the index
    results = index.search('Public book')
    expect(results['hits']).to be_empty
  end

  context 'when attributes have not changed' do
    it 'does not call the API' do
      TestUtil.reset_people!

      jane = People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)

      expect do
        jane.update(first_name: 'Jane')
      end.not_to change(People.index.tasks['results'], :count)
    end
  end

  shared_examples 'custom search blob update behavior' do |model:, reset_method:|
    it 'evaluates custom builders once per indexing event while still updating search' do
      TestUtil.public_send(reset_method)
      record = model.create!(name: 'Jane')

      expect(model.search('Jane')).to be_one
      expect(model.search('Joan')).to be_empty

      evaluations_before = model.search_blob_evaluations

      expect do
        record.update!(name: 'Joan')
      end.to change { model.index.tasks['results'].count }.by(1)

      expect(model.search('Jane')).to be_empty
      expect(model.search('Joan')).to be_one
      expect(model.search_blob_evaluations - evaluations_before).to eq(1)
    end

    it 'does not evaluate custom builders or enqueue indexing on no-op updates' do
      TestUtil.public_send(reset_method)
      record = model.create!(name: 'Jane')

      evaluations_before = model.search_blob_evaluations

      expect do
        record.update!(name: 'Jane')
      end.not_to(change { model.index.tasks['results'].count })

      expect(model.search_blob_evaluations).to eq(evaluations_before)
      expect(model.search('Jane')).to be_one
    end
  end

  context 'with explicit attribute blocks' do
    include_examples 'custom search blob update behavior',
                     model: SearchBlobFromAttributeModel,
                     reset_method: :reset_search_blob_from_attribute_models!
  end

  context 'with add_attribute blocks' do
    include_examples 'custom search blob update behavior',
                     model: SearchBlobFromAddAttributeModel,
                     reset_method: :reset_search_blob_from_add_attribute_models!
  end
end
