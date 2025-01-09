module MeiliSearch
  module Rails
    class ModelConfiguration
      attr_reader :model

      def initialize(model, options = {})
        @model = model
        parse_options(options)
      end

      def sequel_model?
        defined?(::Sequel::Model) && model < Sequel::Model
      end

      def active_record_model?
        defined?(::ActiveRecord) && model.ancestors.include?(::ActiveRecord::Base)
      end

      private

      def parse_options(options)
        refute_global_options(options, [:per_environment])
        mutually_exclusive_options(options, [:enqueue, :synchronous])
      end

      def refute_global_options(options, misapplied_global_opts)
        misapplied_global_opts.each do |opt|
          if options[opt]
            raise BadConfiguration, ":#{opt} option should be defined globally on MeiliSearch::Rails.configuration block."
          end
        end
      end

      def mutually_exclusive_options(options, exclusives)
        first, second = exclusives.select { |opt| options[opt] }

        raise ArgumentError, "Cannot use :#{first} if the :#{second} option is set" if second
      end
    end
  end
end
