# frozen_string_literal: true

module Meilisearch
  module Rails
    VERSION = '0.14.3'

    def self.qualified_version
      "Meilisearch Rails (v#{VERSION})"
    end
  end
end
