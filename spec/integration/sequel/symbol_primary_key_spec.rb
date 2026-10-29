require 'support/sequel_models/person'

describe 'When a sequel model uses a symbol primary_key' do
  let(:person) { SequelPerson.create first_name: 'Jane', card_number: 75_801_887 }
  let(:sent) { [] }

  before do
    SequelPerson.clear_index!(true)
    person
    allow_any_instance_of(Meilisearch::Index).to receive(:add_documents) { |_, docs| sent.concat([docs].flatten) && double(await: nil, '[]': 0) }
    allow_any_instance_of(Meilisearch::Index).to receive(:wait_for_task)
  end

  it 'indexes the record under the primary key' do
    allow_any_instance_of(Meilisearch::Index).to receive(:add_documents).and_call_original

    expect(SequelPerson.index.fetch_info.primary_key).to eq('card_number')
  end

  {
    'ms_index!' => -> { SequelPerson.ms_index!(person) },
    'ms_index_documents' => -> { SequelPerson.ms_index_documents([person]) },
    'ms_reindex!' => -> { SequelPerson.ms_reindex! }
  }.each do |entry_point, call|
    it "sends only string keys from #{entry_point}" do
      instance_exec(&call)

      expect(sent).not_to be_empty
      expect(sent.flat_map(&:keys)).to all(be_a(String))
    end
  end
end
