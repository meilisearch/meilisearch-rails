# A unique prefix for your test run in local or CI
SAFE_INDEX_PREFIX = "rails_#{SecureRandom.hex(8)}".freeze

def _indexes
  @indexes ||= {}
end

# avoid concurrent access to the same index in local or CI
def safe_index_uid(name)
  _indexes[name] ||= "#{SAFE_INDEX_PREFIX}_#{name}"
end

# get a list of safe indexes in local or CI
def safe_index_list
  _indexes.values.flat_map { |safe_idx| [safe_idx, "#{safe_idx}_test"] }
end
