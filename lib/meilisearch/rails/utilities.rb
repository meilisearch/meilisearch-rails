module MeiliSearch
  module Rails
    module Utilities
      class << self
        def get_model_classes
          if ::Rails.application && defined?(::Rails.autoloaders) && ::Rails.autoloaders.zeitwerk_enabled?
            Zeitwerk::Loader.eager_load_all
          elsif ::Rails.application
            ::Rails.application.eager_load!
          end
          klasses = MeiliSearch::Rails.instance_variable_get(:@included_in)
          (klasses + klasses.map(&:descendants).flatten).uniq
        end

        def clear_all_indexes
          get_model_classes.each(&:clear_index!)
        end

        def reindex_all_models
          klasses = get_model_classes

          ::Rails.logger.info "\n\nReindexing #{klasses.count} models: #{klasses.to_sentence}.\n"

          klasses.each do |klass|
            ::Rails.logger.info klass
            ::Rails.logger.info "Reindexing #{klass.count} records..."

            klass.ms_reindex!
          end
        end

        def set_settings_all_models
          klasses = get_model_classes

          ::Rails.logger.info "\n\nPushing settings for #{klasses.count} models: #{klasses.to_sentence}.\n"

          klasses.each do |klass|
            ::Rails.logger.info "Pushing #{klass} settings..."

            klass.ms_set_settings
          end
        end
      end
    end
  end
end
