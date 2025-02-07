require 'singleton'

module Meilisearch
  module Rails
    class NullObject
      include Singleton

      def map
        []
      end

      def nil?
        true
      end

      def method_missing(_method, *_args, &_block)
        self
      end

      def respond_to_missing?(_method_name, _include_private = false)
        false
      end
    end
  end
end
