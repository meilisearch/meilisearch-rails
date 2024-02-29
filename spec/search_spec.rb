require 'support/models/color'

describe 'Search' do
  before do
    Color.clear_index!(true)
    Color.delete_all
  end

  it 'respects non-searchable attributes' do
    Color.create!(name: 'blue', short_name: 'x', hex: 0xFF0000)
    expect(Color.search('x')).to be_empty
  end

  it 'respects ranking rules' do
    third = Color.create!(hex: 3)
    first = Color.create!(hex: 1)
    second = Color.create!(hex: 2)

    expect(Color.search('')).to eq([first, second, third])
  end

  it 'applies filter' do
    _blue = Color.create!(name: 'blue', short_name: 'blu', hex: 0x0000FF)
    black = Color.create!(name: 'black', short_name: 'bla', hex: 0x000000)
    _green = Color.create!(name: 'green', short_name: 'gre', hex: 0x00FF00)

    results = Color.search('bl', { filter: ['short_name = bla'] })
    expect(results).to contain_exactly(black)
  end

  it 'applies sorting' do
    blue = Color.create!(name: 'blue', short_name: 'blu', hex: 0x0000FF)
    black = Color.create!(name: 'black', short_name: 'bla', hex: 0x000000)
    green = Color.create!(name: 'green', short_name: 'gre', hex: 0x00FF00)

    results = Color.search('*', { sort: ['name:asc'] })

    expect(results).to eq([black, blue, green])
  end

  it 'makes facets distribution accessible' do
    Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
    results = Color.search('', { facets: ['short_name'] })

    expect(results.facets_distribution).to match(
      { 'short_name' => { 'b' => 1 } }
    )
  end


  it 'results include #formatted object' do
    Color.create!(name: 'green', short_name: 'b', hex: 0xFF0000)
    results = Color.search('gre')
    expect(results[0].formatted).to include('name' => '<em>gre</em>en')
  end
end

describe '#raw_search' do
  it 'allows for access to meilisearch-ruby search' do
    Color.clear_index!(true)
    Color.delete_all
    Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)

    raw_results = Color.raw_search('blue')
    ms_ruby_results = Color.index.search('blue')

    expect(raw_results.keys).to match ms_ruby_results.keys
  end
end
