require 'json'
require 'net/http'
require 'uri'

module LegacySearchHelper
  LEGACY_SEARCH_ENDPOINT = '/experimental-features'.freeze
  private_constant :LEGACY_SEARCH_ENDPOINT

  def enable_meilisearch_legacy_search!
    config = Meilisearch::Rails.configuration
    host = config.fetch(:meilisearch_url)
    api_key = config[:meilisearch_api_key]

    uri = URI.parse("#{host.chomp('/')}#{LEGACY_SEARCH_ENDPOINT}")
    request = Net::HTTP::Patch.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{api_key}" if api_key.present?
    request.body = { legacySearch: true }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    return if response.is_a?(Net::HTTPSuccess)

    raise 'Failed to enable Meilisearch legacy search in tests: ' \
          "HTTP #{response.code} #{response.message}. Response body: #{response.body}"
  rescue KeyError => e
    raise "Missing Meilisearch test configuration: #{e.message}"
  rescue StandardError => e
    raise if e.message.start_with?('Failed to enable Meilisearch legacy search in tests:')

    raise "Failed to enable Meilisearch legacy search in tests: #{e.class}: #{e.message}"
  end
end
