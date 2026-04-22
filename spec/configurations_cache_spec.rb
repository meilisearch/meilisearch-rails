require 'support/models/color'

describe 'Configuration cache' do
  def capture_ivars(klass, *ivars)
    ivars.index_with do |ivar|
      [klass.instance_variable_defined?(ivar), klass.instance_variable_get(ivar)]
    end
  end

  def restore_ivars(klass, captured)
    captured.each do |ivar, (defined, value)|
      if defined
        klass.instance_variable_set(ivar, value)
      elsif klass.instance_variable_defined?(ivar)
        klass.remove_instance_variable(ivar)
      end
    end
  end

  around do |example|
    ivars = %i[@meilisearch_configurations @configurations]
    captured = capture_ivars(Color, *ivars)

    begin
      example.run
    ensure
      restore_ivars(Color, captured)
    end
  end

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
