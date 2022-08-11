# A unique prefix for your test run in local or CI
SAFE_INDEX_PREFIX = "rails_#{SecureRandom.hex(8)}".freeze

# avoid concurrent access to the same index in local or CI
def safe_index_uid(name)
  "#{SAFE_INDEX_PREFIX}_#{name}"
end

# get a list of safe indexes in local or CI
def safe_index_list
  list = MeiliSearch::Rails.client.indexes['results']
  list = list.select { |index| index.uid.include?(SAFE_INDEX_PREFIX) }
  list.sort_by { |index| index.primary_key || '' }
end
