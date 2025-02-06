module MeiliSearch
  module Rails
    # this class wraps an MeiliSearch::Index document ensuring all raised exceptions
    # are correctly logged or thrown depending on the `raise_on_failure` option
    class SafeIndex
      def initialize(index_uid, raise_on_failure, options)
        client = MeiliSearch::Rails.client
        primary_key = options[:primary_key] || MeiliSearch::Rails::IndexSettings::DEFAULT_PRIMARY_KEY
        @raise_on_failure = raise_on_failure.nil? || raise_on_failure

        SafeIndex.log_or_throw(nil, @raise_on_failure) do
          client.create_index(index_uid, { primary_key: primary_key })
        end

        @index = client.index(index_uid)
      end

      ::MeiliSearch::Index.instance_methods(false).each do |m|
        define_method(m) do |*args, &block|
          if m == :update_settings
            args[0].delete(:attributes_to_highlight) if args[0][:attributes_to_highlight]
            args[0].delete(:attributes_to_crop) if args[0][:attributes_to_crop]
            args[0].delete(:crop_length) if args[0][:crop_length]
          end

          SafeIndex.log_or_throw(m, @raise_on_failure) do
            return MeiliSearch::Rails.black_hole unless MeiliSearch::Rails.active?

            @index.send(m, *args, &block)
          end
        end
      end

      # Maually define facet_search due to complications with **opts in ruby 2.*
      def facet_search(*args, **opts)
        SafeIndex.log_or_throw(:facet_search, @raise_on_failure) do
          return MeiliSearch::Rails.black_hole unless MeiliSearch::Rails.active?

          @index.facet_search(*args, **opts)
        end
      end

      # special handling of wait_for_task to handle null task_id
      def wait_for_task(task_uid)
        return if task_uid.nil? && !@raise_on_failure # ok

        SafeIndex.log_or_throw(:wait_for_task, @raise_on_failure) do
          @index.wait_for_task(task_uid)
        end
      end

      # special handling of settings to avoid raising errors on 404
      def settings(*args)
        SafeIndex.log_or_throw(:settings, @raise_on_failure) do
          @index.settings(*args)
        rescue ::MeiliSearch::ApiError => e
          return {} if e.code == 'index_not_found' # not fatal

          raise e
        end
      end

      def self.log_or_throw(method, raise_on_failure, &block)
        yield
      rescue ::MeiliSearch::TimeoutError, ::MeiliSearch::ApiError => e
        raise e if raise_on_failure

        # log the error
        MeiliSearch::Rails.logger.info("[meilisearch-rails] #{e.message}")
        # return something
        case method.to_s
        when 'search'
          # some attributes are required
          { 'hits' => [], 'hitsPerPage' => 0, 'page' => 0, 'facetDistribution' => {}, 'error' => e }
        else
          # empty answer
          { 'error' => e }
        end
      end
    end
  end
end
