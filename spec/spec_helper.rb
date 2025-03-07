ENV['RAILS_ENV'] ||= 'test'

require 'bundler/setup'

unless ENV.fetch('DISABLE_COVERAGE', false)
  require 'simplecov'

  SimpleCov.start do
    add_filter %r{^/spec/}
    minimum_coverage 86.70

    if ENV['CI']
      require 'simplecov-cobertura'

      formatter SimpleCov::Formatter::CoberturaFormatter
    end
  end
end

require 'timeout'
require 'dotenv/load'
require 'faker'
require 'threads'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'meilisearch-rails'
require 'rspec'
require 'rails/all'
require 'sqlite3' unless defined?(JRUBY_VERSION)
require 'logger'
require 'sequel'
require 'active_model_serializers'
require 'byebug'

# Required for running background jobs on demand (deterministically)
ActiveJob::Base.queue_adapter = :test
# Required for serializing objects similar to production environments
GlobalID.app = 'meilisearch-test'

OLD_RAILS = Gem.loaded_specs['rails'].version < Gem::Version.new('4.0')
NEW_RAILS = Gem.loaded_specs['rails'].version >= Gem::Version.new('6.0')

Dir["#{File.dirname(__FILE__)}/support/*.rb"].each { |file| require file }

RSpec.configure do |c|
  c.mock_with :rspec
  c.filter_run focus: true
  c.run_all_when_everything_filtered = true
  c.formatter = 'documentation'

  c.around do |example|
    Timeout.timeout(120) do
      example.run
    end
  end

  # Remove all indexes setup in this run in local or CI
  c.after(:suite) do
    Meilisearch::Rails.configuration = {
      meilisearch_url: ENV.fetch('MEILISEARCH_HOST', 'http://127.0.0.1:7700'),
      meilisearch_api_key: ENV.fetch('MEILISEARCH_API_KEY', 'masterKey')
    }

    safe_index_list.each do |index|
      Meilisearch::Rails.client.delete_index(index)
    end
  end
end
