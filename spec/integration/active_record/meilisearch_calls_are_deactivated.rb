require 'support/models/task'

describe 'When meilisearch calls are disabled' do
  it 'does not send requests to meilisearch' do
    Meilisearch::Rails.deactivate!

    expect do
      Task.create(title: 'my task #1')
      Task.search('task')
    end.not_to raise_error

    Meilisearch::Rails.activate!
  end

  context 'with a block' do
    it 'does not interfere with prior requests' do
      Task.destroy_all
      Task.create!(title: 'deactivated #1')

      Meilisearch::Rails.deactivate! do
        # always 0 since the black hole will return the default values
        expect(Task.search('deactivated').size).to eq(0)
      end

      expect(Meilisearch::Rails).to be_active
      expect(Task.search('#1').size).to eq(1)
    end
  end
end
