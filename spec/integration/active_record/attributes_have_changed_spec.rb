require 'support/models/color'
require 'support/models/book'

describe 'When record attributes have changed' do
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
    book = Book.new name: 'My life', author: 'Myself', premium: false, released: true

    allow(book).to receive(:ms_dirty?).and_return(true)
    expect(Book.ms_must_reindex?(book)).to be(true)

    allow(book).to receive(:ms_dirty?).and_return(false)
    expect(Book.ms_must_reindex?(book)).to be(false)

    allow(book).to receive(:ms_dirty?).and_return(true)
    expect(Book.ms_must_reindex?(book)).to be(true)
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

