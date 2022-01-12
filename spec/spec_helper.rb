require 'simplecov'
SimpleCov.start do
  add_filter %r{^/spec/}
  minimum_coverage 86.80
end

require 'rubygems'
require 'bundler'
require 'timeout'
require 'dotenv/load'
require 'faker'
Bundler.setup :test

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'meilisearch-rails'
require 'rspec'
require 'rails/all'

require 'support/dummy_classes'

Thread.current[:meilisearch_hosts] = nil

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
    MeiliSearch.configuration = {
      meilisearch_host: ENV.fetch('MEILISEARCH_HOST', 'http://127.0.0.1:7700'),
      meilisearch_api_key: ENV.fetch('MEILISEARCH_API_KEY', 'masterKey')
    }

    safe_index_list.each do |index|
      MeiliSearch.client.delete_index(index.uid)
    end
  end
end

# A unique prefix for your test run in local or CI
SAFE_INDEX_PREFIX = "rails_#{SecureRandom.hex(8)}".freeze

# avoid concurrent access to the same index in local or CI
def safe_index_uid(name)
  "#{SAFE_INDEX_PREFIX}_#{name}"
end

# get a list of safe indexes in local or CI
def safe_index_list
  list = MeiliSearch.client.indexes
  list = list.select { |index| index.uid.include?(SAFE_INDEX_PREFIX) }
  list.sort_by { |index| index.primary_key || '' }
end
