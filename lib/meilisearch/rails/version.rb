# frozen_string_literal: true

module Meilisearch
  module Rails
    VERSION = '0.16.0'

    def self.qualified_version
      "Meilisearch Rails (v#{VERSION})"
    end
  end
end
