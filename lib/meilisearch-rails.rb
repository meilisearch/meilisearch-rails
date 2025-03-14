require 'meilisearch'
require 'meilisearch/rails/null_object'
require 'meilisearch/rails/version'
require 'meilisearch/rails/utilities'
require 'meilisearch/rails/errors'
require 'meilisearch/rails/multi_search'
require 'meilisearch/rails/index_settings'
require 'meilisearch/rails/safe_index'
require 'meilisearch/rails/model_configuration'

if defined? Rails
  begin
    require 'meilisearch/rails/railtie'
  rescue LoadError
  end
end

begin
  require 'active_job'
rescue LoadError
  # no queue support, fine
end

require 'logger'

module MeiliSearch
  module Rails
    autoload :Configuration, 'meilisearch/rails/configuration'
    extend Configuration

    autoload :Pagination, 'meilisearch/rails/pagination'

    class << self
      attr_reader :included_in

      def included(klass)
        @included_in ||= []
        @included_in << klass
        @included_in.uniq!

        klass.class_eval do
          extend ClassMethods
          include InstanceMethods
        end
      end

      def logger
        @logger ||= (::Rails.logger || Logger.new($stdout))
      end
    end

    # Default queueing system
    if defined?(::ActiveJob::Base)
      # lazy load the ActiveJob class to ensure the
      # queue is initialized before using it
      autoload :MSJob, 'meilisearch/rails/ms_job'
      autoload :MSCleanUpJob, 'meilisearch/rails/ms_clean_up_job'
    end

    # these are the class methods added when MeiliSearch is included
    module ClassMethods
      def self.extended(base)
        class << base
          alias_method :without_auto_index, :ms_without_auto_index unless method_defined? :without_auto_index
          alias_method :reindex!, :ms_reindex! unless method_defined? :reindex!
          alias_method :index_documents, :ms_index_documents unless method_defined? :index_documents
          alias_method :index!, :ms_index! unless method_defined? :index!
          alias_method :remove_from_index!, :ms_remove_from_index! unless method_defined? :remove_from_index!
          alias_method :clear_index!, :ms_clear_index! unless method_defined? :clear_index!
          alias_method :search, :ms_search unless method_defined? :search
          alias_method :raw_search, :ms_raw_search unless method_defined? :raw_search
          alias_method :index, :ms_index unless method_defined? :index
          alias_method :index_uid, :ms_index_uid unless method_defined? :index_uid
          alias_method :must_reindex?, :ms_must_reindex? unless method_defined? :must_reindex?
        end

        base.cattr_accessor :meilisearch_options, :ms_index_settings, :ms_config
      end

      def meilisearch(options = {}, &block)
        self.ms_index_settings = IndexSettings.new(options, &block)
        self.meilisearch_options = {
          per_page: ms_index_settings.get_setting(:hitsPerPage) || 20, page: 1
        }.merge(options)

        self.ms_config = ModelConfiguration.new(model_name.to_s.constantize, options)

        attr_accessor :formatted

        if options[:synchronous] == true
          if ms_config.sequel_model?
            class_eval do
              copy_after_validation = instance_method(:after_validation)
              define_method(:after_validation) do |*args|
                super(*args)
                copy_after_validation.bind(self).call
                ms_mark_synchronous
              end
            end
          elsif respond_to?(:after_validation)
            after_validation :ms_mark_synchronous
          end
        end
        if options[:enqueue]
          proc = if options[:enqueue] == true
                   proc do |record, remove|
                     if remove
                       MSCleanUpJob.perform_later(record.ms_entries)
                     else
                       MSJob.perform_later(record, 'ms_index!')
                     end
                   end
                 elsif options[:enqueue].respond_to?(:call)
                   options[:enqueue]
                 elsif options[:enqueue].is_a?(Symbol)
                   proc { |record, remove| send(options[:enqueue], record, remove) }
                 else
                   raise ArgumentError, "Invalid `enqueue` option: #{options[:enqueue]}"
                 end
          meilisearch_options[:enqueue] = proc do |record, remove|
            proc.call(record, remove) if ::MeiliSearch::Rails.active? && !ms_without_auto_index_scope
          end
        end
        unless options[:auto_index] == false
          if ms_config.sequel_model?
            class_eval do
              copy_after_validation = instance_method(:after_validation)
              copy_before_save = instance_method(:before_save)

              define_method(:after_validation) do |*args|
                super(*args)
                copy_after_validation.bind(self).call
                ms_mark_must_reindex
              end

              define_method(:before_save) do |*args|
                copy_before_save.bind(self).call
                ms_mark_for_auto_indexing
                super(*args)
              end

              sequel_version = Gem::Version.new(Sequel.version)
              if sequel_version >= Gem::Version.new('4.0.0') && sequel_version < Gem::Version.new('5.0.0')
                copy_after_commit = instance_method(:after_commit)
                define_method(:after_commit) do |*args|
                  super(*args)
                  copy_after_commit.bind(self).call
                  ms_perform_index_tasks
                end
              else
                copy_after_save = instance_method(:after_save)
                define_method(:after_save) do |*args|
                  super(*args)
                  copy_after_save.bind(self).call
                  db.after_commit do
                    ms_perform_index_tasks
                  end
                end
              end
            end
          else
            after_validation :ms_mark_must_reindex if respond_to?(:after_validation)
            before_save :ms_mark_for_auto_indexing if respond_to?(:before_save)
            if respond_to?(:after_commit)
              after_commit :ms_perform_index_tasks
            elsif respond_to?(:after_save)
              after_save :ms_perform_index_tasks
            end
          end
        end
        unless options[:auto_remove] == false
          if ms_config.sequel_model?
            class_eval do
              copy_after_destroy = instance_method(:after_destroy)

              define_method(:after_destroy) do |*args|
                copy_after_destroy.bind(self).call
                ms_enqueue_remove_from_index!(ms_synchronous?)
                super(*args)
              end
            end
          elsif respond_to?(:after_destroy)
            after_destroy_commit { |searchable| searchable.ms_enqueue_remove_from_index!(ms_synchronous?) }
          end
        end
      end

      def ms_without_auto_index(&block)
        self.ms_without_auto_index_scope = true
        begin
          yield
        ensure
          self.ms_without_auto_index_scope = false
        end
      end

      def ms_without_auto_index_scope=(value)
        Thread.current["ms_without_auto_index_scope_for_#{model_name}"] = value
      end

      def ms_without_auto_index_scope
        Thread.current["ms_without_auto_index_scope_for_#{model_name}"]
      end

      def ms_reindex!(batch_size = MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, synchronous = false)
        return if ms_without_auto_index_scope

        ms_configurations.each do |options, settings|
          next if ms_indexing_disabled?(options)

          index = ms_ensure_init(options, settings)
          last_task = nil

          ms_find_in_batches(batch_size) do |group|
            if ms_conditional_index?(options)
              # delete non-indexable documents
              ids = group.select { |d| !Utilities.indexable?(d, options) }.map { |d| ms_primary_key_of(d, options) }
              index.delete_documents(ids.select(&:present?))
              # select only indexable documents
              group = group.select { |d| Utilities.indexable?(d, options) }
            end
            documents = group.map do |d|
              attributes = settings.get_attributes(d)
              attributes = attributes.to_hash unless attributes.instance_of?(Hash)
              attributes.merge ms_pk(options) => ms_primary_key_of(d, options)
            end
            last_task = index.add_documents(documents)
          end
          index.wait_for_task(last_task['taskUid']) if last_task && (synchronous || options[:synchronous])
        end
        nil
      end

      def ms_set_settings(synchronous = false)
        ms_configurations.each do |options, settings|
          if options[:primary_settings] && options[:inherit]
            primary = options[:primary_settings].to_settings
            final_settings = primary.merge(settings.to_settings)
          else
            final_settings = settings.to_settings
          end

          index = SafeIndex.new(ms_index_uid(options), true, options)
          task = index.update_settings(final_settings)
          index.wait_for_task(task['taskUid']) if synchronous
        end
      end

      def ms_index_documents(documents, synchronous = false)
        ms_configurations.each do |options, settings|
          next if ms_indexing_disabled?(options)

          index = ms_ensure_init(options, settings)
          task = index.add_documents(documents.map { |d| settings.get_attributes(d).merge ms_pk(options) => ms_primary_key_of(d, options) })
          index.wait_for_task(task['taskUid']) if synchronous || options[:synchronous]
        end
      end

      def ms_index!(document, synchronous = false)
        return if ms_without_auto_index_scope

        # MS tasks to be returned
        ms_configurations.map do |options, settings|
          next if ms_indexing_disabled?(options)

          primary_key = ms_primary_key_of(document, options)
          index = ms_ensure_init(options, settings)
          if Utilities.indexable?(document, options)
            raise ArgumentError, 'Cannot index a record without a primary key' if primary_key.blank?

            doc = settings.get_attributes(document)
            doc = doc.merge ms_pk(options) => primary_key

            if synchronous || options[:synchronous]
              index.add_documents(doc).await
            else
              index.add_documents(doc)
            end
          elsif ms_conditional_index?(options) && primary_key.present?
            # remove non-indexable documents
            if synchronous || options[:synchronous]
              index.delete_document(primary_key).await
            else
              index.delete_document(primary_key)
            end
          end
        end.compact
      end

      def ms_entries_for(document:, synchronous:)
        primary_key = ms_primary_key_of(document)
        raise ArgumentError, 'Cannot index a record without a primary key' if primary_key.blank?

        ms_configurations.filter_map do |options, settings|
          {
            synchronous: synchronous || options[:synchronous],
            index_uid: ms_index_uid(options),
            primary_key: primary_key
          }.with_indifferent_access unless ms_indexing_disabled?(options)
        end
      end

      def ms_remove_from_index!(document, synchronous = false)
        return if ms_without_auto_index_scope

        primary_key = ms_primary_key_of(document)
        raise ArgumentError, 'Cannot index a record without a primary key' if primary_key.blank?

        ms_configurations.each do |options, settings|
          next if ms_indexing_disabled?(options)

          index = ms_ensure_init(options, settings)
          if synchronous || options[:synchronous]
            index.delete_document(primary_key).await
          else
            index.delete_document(primary_key)
          end
        end
        nil
      end

      def ms_clear_index!(synchronous = false)
        ms_configurations.each do |options, settings|
          next if ms_indexing_disabled?(options)

          index = ms_ensure_init(options, settings)
          synchronous || options[:synchronous] ? index.delete_all_documents.await : index.delete_all_documents
          @ms_indexes[MeiliSearch::Rails.active?][settings] = nil
        end
        nil
      end

      def ms_raw_search(q, params = {})
        index_uid = params.delete(:index) || params.delete('index')

        unless ms_index_settings.get_setting(:attributes_to_highlight).nil?
          params[:attributes_to_highlight] = ms_index_settings.get_setting(:attributes_to_highlight)
        end

        unless ms_index_settings.get_setting(:attributes_to_crop).nil?
          params[:attributes_to_crop] = ms_index_settings.get_setting(:attributes_to_crop)

          unless ms_index_settings.get_setting(:crop_length).nil?
            params[:crop_length] = ms_index_settings.get_setting(:crop_length)
          end
        end

        index = ms_index(index_uid)
        index.search(q, params.to_h { |k, v| [k, v] })
      end

      module AdditionalMethods
        def ms_raw_answer
          @ms_json
        end

        def ms_facets_distribution
          @ms_json['facetDistribution']
        end

        alias raw_answer ms_raw_answer unless method_defined? :raw_answer
        alias facets_distribution ms_facets_distribution unless method_defined? :facets_distribution

        private

        def ms_init_raw_answer(json)
          @ms_json = json
        end
      end

      def ms_search(query, params = {})
        if MeiliSearch::Rails.configuration[:pagination_backend]
          %i[page hitsPerPage hits_per_page].each do |key|
            params[key.to_s.underscore.to_sym] = params[key].to_i if params.key?(key)
          end

          # It is required to activate the finite pagination in Meilisearch v0.30 (or newer),
          # to have at least `hits_per_page` defined or `page` in the search request.
          params[:page] ||= 1
        end

        json = ms_raw_search(query, params)

        # condition_key gets the primary key of the document; looks for "id" on the options
        condition_key = if defined?(::Mongoid::Document) && include?(::Mongoid::Document)
                          ms_primary_key_method.in
                        else
                          ms_primary_key_method
                        end

        # The condition_key must be a valid column otherwise, the `.where` below will not work
        # Since we provide a way to customize the primary_key value, `ms_pk(meilisearch_options)` may not
        # respond with a valid database column. The blocks below prevent that from happening.
        has_virtual_column_as_pk = if ms_config.sequel_model?
                                     columns.map(&:to_s).exclude?(condition_key.to_s)
                                   else
                                     columns.map(&:name).map(&:to_s).exclude?(condition_key.to_s)
                                   end

        condition_key = primary_key if has_virtual_column_as_pk

        hit_ids = if has_virtual_column_as_pk
                    json['hits'].map { |hit| hit[condition_key] }
                  else
                    json['hits'].map { |hit| hit[ms_pk(meilisearch_options).to_s] }
                  end

        # meilisearch_options[:type] refers to the Model name (e.g. Product)
        # results_by_id creates a hash with the primaryKey of the document (id) as the key and doc itself as the value
        # {"13"=>#<Product id: 13, name: "iphone", href: "apple", tags: nil, type: nil,
        # description: "Puts even more features at your fingertips", release_date: nil>}
        results_by_id = where(condition_key => hit_ids).index_by do |hit|
          ms_primary_key_of(hit)
        end

        results = json['hits'].map do |hit|
          o = results_by_id[hit[ms_pk(meilisearch_options).to_s].to_s]
          if o
            o.formatted = hit['_formatted']
            o
          end
        end.compact

        res = Pagination.create(results, json['totalHits'], meilisearch_options.merge(page: json['page'], per_page: json['hitsPerPage']))
        res.extend(AdditionalMethods)
        res.send(:ms_init_raw_answer, json)
        res
      end

      def ms_index(name = nil)
        if name
          ms_configurations.each do |o, s|
            return ms_ensure_init(o, s) if o[:index_uid].to_s == name.to_s
          end
          raise ArgumentError, "Invalid index name: #{name}"
        end
        ms_ensure_init
      end

      def ms_index_uid(options = nil)
        options ||= meilisearch_options
        global_options ||= MeiliSearch::Rails.configuration

        name = options[:index_uid] || model_name.to_s.gsub('::', '_')
        name = "#{name}_#{::Rails.env}" if global_options[:per_environment]

        name
      end

      def ms_must_reindex?(document)
        # use +ms_dirty?+ method if implemented
        return document.send(:ms_dirty?) if document.respond_to?(:ms_dirty?)

        # Loop over each index to see if a attribute used in records has changed
        ms_configurations.each do |options, settings|
          next if ms_indexing_disabled?(options)
          return true if ms_primary_key_changed?(document, options)

          settings.get_attribute_names(document).each do |k|
            return true if ms_attribute_changed?(document, k)
            # return true if !document.respond_to?(changed_method) || document.send(changed_method)
          end
          [options[:if], options[:unless]].each do |condition|
            case condition
            when nil
              return false
            when String, Symbol
              return true if ms_attribute_changed?(document, condition)
            else
              # if the :if, :unless condition is a anything else,
              # we have no idea whether we should reindex or not
              # let's always reindex then
              return true
            end
          end
        end

        # By default, we don't reindex
        false
      end

      def ms_primary_key_method(options = nil)
        options ||= meilisearch_options
        options[:primary_key] || options[:id] || :id
      end

      protected

      def ms_ensure_init(options = meilisearch_options, settings = ms_index_settings, user_configuration = settings.to_settings)
        raise ArgumentError, 'No `meilisearch` block found in your model.' if ms_index_settings.nil?

        @ms_indexes ||= { true => {}, false => {} }

        @ms_indexes[MeiliSearch::Rails.active?][settings] ||= SafeIndex.new(ms_index_uid(options), meilisearch_options[:raise_on_failure], meilisearch_options)

        update_settings_if_changed(@ms_indexes[MeiliSearch::Rails.active?][settings], options, user_configuration)

        @ms_indexes[MeiliSearch::Rails.active?][settings]
      end

      private

      def update_settings_if_changed(index, options, user_configuration)
        server_state = index.settings
        user_configuration = options[:primary_settings].to_settings.merge(user_configuration) if options[:inherit]

        config = user_configuration.except(:attributes_to_highlight, :attributes_to_crop, :crop_length)

        if !skip_checking_settings?(options) && ms_index_settings_changed?(server_state, config)
          index.update_settings(user_configuration)
        end
      end

      def skip_checking_settings?(options)
        ms_indexing_disabled?(options) || ms_checking_disabled?(options)
      end

      def ms_checking_disabled?(options)
        options[:check_settings] == false
      end

      def ms_configurations
        raise ArgumentError, 'No `meilisearch` block found in your model.' if ms_index_settings.nil?

        if @configurations.nil?
          @configurations = {}
          @configurations[meilisearch_options] = ms_index_settings
          ms_index_settings.additional_indexes.each do |k, v|
            @configurations[k] = v

            next unless v.additional_indexes.any?

            v.additional_indexes.each do |options, index|
              @configurations[options] = index
            end
          end
        end
        @configurations
      end

      def ms_primary_key_of(doc, options = nil)
        doc.send(ms_primary_key_method(options)).to_s
      end

      def ms_primary_key_changed?(doc, options = nil)
        changed = ms_attribute_changed?(doc, ms_primary_key_method(options))
        changed.nil? ? false : changed
      end

      def ms_pk(options = nil)
        options[:primary_key] || MeiliSearch::Rails::IndexSettings::DEFAULT_PRIMARY_KEY
      end

      def ms_index_settings_changed?(server_state, user_configuration)
        return true if server_state.nil?

        user_configuration.transform_keys! { |key| key.to_s.camelize(:lower) }

        user_configuration.any? do |key, user|
          server = server_state[key]

          if user.is_a?(Hash) && server.is_a?(Hash)
            ms_index_settings_changed?(server, user)
          elsif user.is_a?(Array) && server.is_a?(Array)
            user.map(&:to_s).sort! != server.map(&:to_s).sort!
          else
            user.to_s != server.to_s
          end
        end
      end

      def ms_conditional_index?(options = nil)
        options ||= meilisearch_options
        options[:if].present? || options[:unless].present?
      end

      def ms_indexing_disabled?(options = nil)
        options ||= meilisearch_options
        constraint = options[:disable_indexing] || options['disable_indexing']
        case constraint
        when nil
          return false
        when true, false
          return constraint
        when String, Symbol
          return send(constraint)
        else
          return constraint.call if constraint.respond_to?(:call) # Proc
        end
        raise ArgumentError, "Unknown constraint type: #{constraint} (#{constraint.class})"
      end

      def ms_find_in_batches(batch_size, &block)
        if ms_config.active_record_model? || respond_to?(:find_in_batches)
          scope = respond_to?(:meilisearch_import) ? meilisearch_import : all
          scope.find_in_batches(batch_size: batch_size, &block)
        elsif ms_config.sequel_model?
          dataset.extension(:pagination).each_page(batch_size, &block)
        else
          # don't worry, mongoid has its own underlying cursor/streaming mechanism
          items = []
          all.each do |item|
            items << item
            if (items.length % batch_size).zero?
              yield items
              items = []
            end
          end
          yield items unless items.empty?
        end
      end

      def ms_attribute_changed?(document, attr_name)
        if document.respond_to?("will_save_change_to_#{attr_name}?")
          return document.send("will_save_change_to_#{attr_name}?")
        end

        # We don't know if the attribute has changed, so conservatively assume it has
        true
      end
    end

    # these are the instance methods included
    module InstanceMethods

      def self.included(base)
        base.instance_eval do
          alias_method :index!, :ms_index! unless method_defined? :index!
          alias_method :remove_from_index!, :ms_remove_from_index! unless method_defined? :remove_from_index!
        end
      end

      def ms_index!(synchronous = false)
        self.class.ms_index!(self, synchronous || ms_synchronous?)
      end

      def ms_remove_from_index!(synchronous = false)
        self.class.ms_remove_from_index!(self, synchronous || ms_synchronous?)
      end

      def ms_enqueue_remove_from_index!(synchronous)
        if meilisearch_options[:enqueue]
          unless self.class.send(:ms_indexing_disabled?, meilisearch_options)
            meilisearch_options[:enqueue].call(self, true)
          end
        else
          ms_remove_from_index!(synchronous || ms_synchronous?)
        end
      end

      def ms_enqueue_index!(synchronous)
        return unless Utilities.indexable?(self, meilisearch_options)

        if meilisearch_options[:enqueue]
          unless self.class.send(:ms_indexing_disabled?, meilisearch_options)
            meilisearch_options[:enqueue].call(self, false)
          end
        else
          ms_index!(synchronous)
        end
      end

      def ms_synchronous?
        !!@ms_synchronous
      end

      def ms_entries(synchronous = false)
        self.class.ms_entries_for(document: self, synchronous: synchronous || ms_synchronous?)
      end

      private

      def ms_mark_synchronous
        @ms_synchronous = true
      end

      def ms_mark_for_auto_indexing
        @ms_auto_indexing = true
      end

      def ms_mark_must_reindex
        # ms_must_reindex flag is reset after every commit as part. If we must reindex at any point in
        # a transaction, keep flag set until it is explicitly unset
        @ms_must_reindex ||=
          if self.class.ms_config.sequel_model?
            new? || self.class.ms_must_reindex?(self)
          else
            new_record? || self.class.ms_must_reindex?(self)
          end
        true
      end

      def ms_perform_index_tasks
        return unless @ms_auto_indexing && @ms_must_reindex

        ms_enqueue_index!(ms_synchronous?)

        @ms_must_reindex = nil
        @ms_auto_indexing = nil
        @ms_synchronous = nil
      end
    end
  end
end
