require 'support/models/color'

describe 'Configuration cache' do
  it 'does not use a generic @configurations ivar on the model' do
    # Ensure a clean slate even if other specs already touched the model.
    Color.remove_instance_variable(:@meilisearch_configurations) if Color.instance_variable_defined?(:@meilisearch_configurations)
    Color.remove_instance_variable(:@configurations) if Color.instance_variable_defined?(:@configurations)

    # Simulate another gem using the same generic ivar name.
    Color.instance_variable_set(:@configurations, { ranking: ['typo'], indexLanguages: ['ja'] })

    captured_settings = nil
    fake_index = instance_double(Meilisearch::Rails::SafeIndex, update_settings: { 'taskUid' => 0 }, wait_for_task: nil)

    allow(Meilisearch::Rails::SafeIndex).to receive(:new).and_return(fake_index)
    allow(fake_index).to receive(:update_settings) do |settings|
      captured_settings = settings
      { 'taskUid' => 0 }
    end

    expect { Color.ms_set_settings(false) }.not_to raise_error
    expect(captured_settings).to be_a(Hash)

    allowed_keys = Meilisearch::Rails::IndexSettings::OPTIONS
    unexpected_keys = captured_settings.keys.map(&:to_sym) - allowed_keys
    expect(unexpected_keys).to be_empty
  end
end
