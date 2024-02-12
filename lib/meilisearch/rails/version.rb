# frozen_string_literal: true

module MeiliSearch
  module Rails
    VERSION = '0.11.0'

    def self.qualified_version
      "Meilisearch Rails (v#{VERSION})"
    end
  end
end
