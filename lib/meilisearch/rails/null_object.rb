require 'singleton'

module MeiliSearch
  module Rails
    class NullObject
      include Singleton

      def map; []; end

      def nil?
        true
      end

      def method_missing(_m, *_args, &_block)
        self
      end
    end
  end
end
