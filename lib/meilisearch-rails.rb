require 'meilisearch'

require 'meilisearch/rails/version'
require 'meilisearch/rails/utilities'
require 'meilisearch/rails/errors'

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
    end

    class IndexSettings
      DEFAULT_BATCH_SIZE = 1000

      DEFAULT_PRIMARY_KEY = 'id'.freeze

      # Meilisearch settings
      OPTIONS = %i[
        searchableAttributes
        filterableAttributes
        sortableAttributes
        displayedAttributes
        distinctAttribute
        synonyms
        stopWords
        rankingRules
        attributesToHighlight
        attributesToCrop
        cropLength
      ].freeze

      OPTIONS.each do |option|
        define_method option do |value|
          instance_variable_set("@#{option}", value)
        end

        underscored_name = option.to_s.gsub(/(.)([A-Z])/, '\1_\2').downcase
        alias_method underscored_name, option if underscored_name != option
      end

      def initialize(options, &block)
        @options = options
        instance_exec(&block) if block_given?
      end

      def use_serializer(serializer)
        @serializer = serializer
        # instance_variable_set("@serializer", serializer)
      end

      def attribute(*names, &block)
        raise ArgumentError, 'Cannot pass multiple attribute names if block given' if block_given? && (names.length > 1)

        @attributes ||= {}
        names.flatten.each do |name|
          @attributes[name.to_s] = block_given? ? proc { |d| d.instance_eval(&block) } : proc { |d| d.send(name) }
        end
      end
      alias attributes attribute

      def add_attribute(*names, &block)
        raise ArgumentError, 'Cannot pass multiple attribute names if block given' if block_given? && (names.length > 1)

        @additional_attributes ||= {}
        names.each do |name|
          @additional_attributes[name.to_s] = block_given? ? proc { |d| d.instance_eval(&block) } : proc { |d| d.send(name) }
        end
      end
      alias add_attributes add_attribute

      def mongoid?(document)
        defined?(::Mongoid::Document) && document.class.include?(::Mongoid::Document)
      end

      def sequel?(document)
        defined?(::Sequel) && document.class < ::Sequel::Model
      end

      def active_record?(document)
        !mongoid?(document) && !sequel?(document)
      end

      def get_default_attributes(document)
        if mongoid?(document)
          # work-around mongoid 2.4's unscoped method, not accepting a block
          document.attributes
        elsif sequel?(document)
          document.to_hash
        else
          document.class.unscoped do
            document.attributes
          end
        end
      end

      def get_attribute_names(document)
        get_attributes(document).keys
      end

      def attributes_to_hash(attributes, document)
        if attributes
          attributes.to_h { |name, value| [name.to_s, value.call(document)] }
        else
          {}
        end
      end

      def get_attributes(document)
        # If a serializer is set, we ignore attributes
        # everything should be done via the serializer
        if !@serializer.nil?
          attributes = @serializer.new(document).attributes
        elsif @attributes.blank?
          attributes = get_default_attributes(document)
          # no `attribute ...` have been configured, use the default attributes of the model
        elsif active_record?(document)
          # at least 1 `attribute ...` has been configured, therefore use ONLY the one configured
          document.class.unscoped do
            attributes = attributes_to_hash(@attributes, document)
          end
        else
          attributes = attributes_to_hash(@attributes, document)
        end

        attributes.merge!(attributes_to_hash(@additional_attributes, document)) if @additional_attributes

        if @options[:sanitize]
          attributes = sanitize_attributes(attributes)
        end

        attributes = encode_attributes(attributes) if @options[:force_utf8_encoding]

        attributes
      end

      def sanitize_attributes(value)
        case value
        when String
          ActionView::Base.full_sanitizer.sanitize(value)
        when Hash
          value.each { |key, val| value[key] = sanitize_attributes(val) }
        when Array
          value.map { |item| sanitize_attributes(item) }
        else
          value
        end
      end

      def encode_attributes(value)
        case value
        when String
          value.force_encoding('utf-8')
        when Hash
          value.each { |key, val| value[key] = encode_attributes(val) }
        when Array
          value.map { |x| encode_attributes(x) }
        else
          value
        end
      end

      def get_setting(name)
        instance_variable_get("@#{name}")
      end

      def to_settings
        settings = {}
        OPTIONS.each do |k|
          v = get_setting(k)
          settings[k] = v unless v.nil?
        end
        settings
      end

      def add_index(index_uid, options = {}, &block)
        raise ArgumentError, 'No block given' unless block_given?
        if options[:auto_index] || options[:auto_remove]
          raise ArgumentError, 'Options auto_index and auto_remove cannot be set on nested indexes'
        end

        @additional_indexes ||= {}
        options[:index_uid] = index_uid
        @additional_indexes[options] = IndexSettings.new(options, &block)
      end

      def additional_indexes
        @additional_indexes || {}
      end
    end

    # Default queueing system
    if defined?(::ActiveJob::Base)
      # lazy load the ActiveJob class to ensure the
      # queue is initialized before using it
      autoload :MSJob, 'meilisearch/ms_job'
    end

    # this class wraps an MeiliSearch::Index document ensuring all raised exceptions
    # are correctly logged or thrown depending on the `raise_on_failure` option
    class SafeIndex
      def initialize(index_uid, raise_on_failure, options)
        client = MeiliSearch::Rails.client
        primary_key = options[:primary_key] || MeiliSearch::Rails::IndexSettings::DEFAULT_PRIMARY_KEY
        client.create_index(index_uid, { primaryKey: primary_key })
        @index = client.index(index_uid)
        @raise_on_failure = raise_on_failure.nil? || raise_on_failure
      end

      ::MeiliSearch::Index.instance_methods(false).each do |m|
        define_method(m) do |*args, &block|
          if m == :update_settings
            args[0].delete(:attributesToHighlight) if args[0][:attributesToHighlight]
            args[0].delete(:attributesToCrop) if args[0][:attributesToCrop]
            args[0].delete(:cropLength) if args[0][:cropLength]
          end
          SafeIndex.log_or_throw(m, @raise_on_failure) do
            @index.send(m, *args, &block)
          end
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
          return {} if e.code == 404 # not fatal

          raise e
        end
      end

      def self.log_or_throw(method, raise_on_failure, &block)
        yield
      rescue ::MeiliSearch::ApiError => e
        raise e if raise_on_failure

        # log the error
        (::Rails.logger || Logger.new($stdout)).error("[meilisearch-rails] #{e.message}")
        # return something
        case method.to_s
        when 'search'
          # some attributes are required
          { 'hits' => [], 'hitsPerPage' => 0, 'page' => 0, 'facetsDistribution' => {}, 'error' => e }
        else
          # empty answer
          { 'error' => e }
        end
      end
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

        base.cattr_accessor :meilisearch_options, :meilisearch_settings
      end

      def meilisearch(options = {}, &block)
        self.meilisearch_settings = IndexSettings.new(options, &block)
        self.meilisearch_options = {
          type: model_name.to_s.constantize,
          per_page: meilisearch_settings.get_setting(:hitsPerPage) || 20, page: 1
        }.merge(options)

        attr_accessor :formatted

        if options[:synchronous] == true
          if defined?(::Sequel) && self < Sequel::Model
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
          raise ArgumentError, 'Cannot use a enqueue if the `synchronous` option if set' if options[:synchronous]

          proc = if options[:enqueue] == true
                   proc do |record, remove|
                     MSJob.perform_later(record, remove ? 'ms_remove_from_index!' : 'ms_index!')
                   end
                 elsif options[:enqueue].respond_to?(:call)
                   options[:enqueue]
                 elsif options[:enqueue].is_a?(Symbol)
                   proc { |record, remove| send(options[:enqueue], record, remove) }
                 else
                   raise ArgumentError, "Invalid `enqueue` option: #{options[:enqueue]}"
                 end
          meilisearch_options[:enqueue] = proc do |record, remove|
            proc.call(record, remove) unless ms_without_auto_index_scope
          end
        end
        unless options[:auto_index] == false
          if defined?(::Sequel) && self < Sequel::Model
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
          if defined?(::Sequel) && self < Sequel::Model
            class_eval do
              copy_after_destroy = instance_method(:after_destroy)

              define_method(:after_destroy) do |*args|
                copy_after_destroy.bind(self).call
                ms_enqueue_remove_from_index!(ms_synchronous?)
                super(*args)
              end
            end
          elsif respond_to?(:after_destroy)
            after_destroy { |searchable| searchable.ms_enqueue_remove_from_index!(ms_synchronous?) }
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
              ids = group.select { |d| !ms_indexable?(d, options) }.map { |d| ms_primary_key_of(d, options) }
              index.delete_documents(ids.select(&:present?))
              # select only indexable documents
              group = group.select { |d| ms_indexable?(d, options) }
            end
            documents = group.map do |d|
              attributes = settings.get_attributes(d)
              attributes = attributes.to_hash unless attributes.instance_of?(Hash)
              attributes.merge ms_pk(options) => ms_primary_key_of(d, options)
            end
            last_task = index.add_documents(documents)
          end
          index.wait_for_task(last_task['uid']) if last_task && (synchronous || options[:synchronous])
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
          index.wait_for_task(task['uid']) if synchronous
        end
      end

      def ms_index_documents(documents, synchronous = false)
        ms_configurations.each do |options, settings|
          next if ms_indexing_disabled?(options)

          index = ms_ensure_init(options, settings)
          task = index.add_documents(documents.map { |d| settings.get_attributes(d).merge ms_pk(options) => ms_primary_key_of(d, options) })
          index.wait_for_task(task['uid']) if synchronous || options[:synchronous]
        end
      end

      def ms_index!(document, synchronous = false)
        return if ms_without_auto_index_scope

        ms_configurations.each do |options, settings|
          next if ms_indexing_disabled?(options)

          primary_key = ms_primary_key_of(document, options)
          index = ms_ensure_init(options, settings)
          if ms_indexable?(document, options)
            raise ArgumentError, 'Cannot index a record without a primary key' if primary_key.blank?

            doc = settings.get_attributes(document)
            doc = doc.merge ms_pk(options) => primary_key

            if synchronous || options[:synchronous]
              index.add_documents!(doc)
            else
              index.add_documents(doc)
            end
          elsif ms_conditional_index?(options) && primary_key.present?
            # remove non-indexable documents
            if synchronous || options[:synchronous]
              index.delete_document!(primary_key)
            else
              index.delete_document(primary_key)
            end
          end
        end
        nil
      end

      def ms_remove_from_index!(document, synchronous = false)
        return if ms_without_auto_index_scope

        primary_key = ms_primary_key_of(document)
        raise ArgumentError, 'Cannot index a record without a primary key' if primary_key.blank?

        ms_configurations.each do |options, settings|
          next if ms_indexing_disabled?(options)

          index = ms_ensure_init(options, settings)
          if synchronous || options[:synchronous]
            index.delete_document!(primary_key)
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
          synchronous || options[:synchronous] ? index.delete_all_documents! : index.delete_all_documents
          @ms_indexes[settings] = nil
        end
        nil
      end

      def ms_raw_search(q, params = {})
        index_uid = params.delete(:index) || params.delete('index')

        unless meilisearch_settings.get_setting(:attributesToHighlight).nil?
          params[:attributesToHighlight] = meilisearch_settings.get_setting(:attributesToHighlight)
        end

        unless meilisearch_settings.get_setting(:attributesToCrop).nil?
          params[:attributesToCrop] = meilisearch_settings.get_setting(:attributesToCrop)

          unless meilisearch_settings.get_setting(:cropLength).nil?
            params[:cropLength] = meilisearch_settings.get_setting(:cropLength)
          end
        end

        index = ms_index(index_uid)
        index.search(q, params.to_h { |k, v| [k, v] })
      end

      module AdditionalMethods
        def self.extended(base)
          class << base
            alias_method :raw_answer, :ms_raw_answer unless method_defined? :raw_answer
            alias_method :facets_distribution, :ms_facets_distribution unless method_defined? :facets_distribution
          end
        end

        def ms_raw_answer
          @ms_json
        end

        def ms_facets_distribution
          @ms_json['facetsDistribution']
        end

        private

        def ms_init_raw_answer(json)
          @ms_json = json
        end
      end

      def ms_search(query, params = {})
        if MeiliSearch::Rails.configuration[:pagination_backend]

          page = params[:page].nil? ? params[:page] : params[:page].to_i
          hits_per_page = params[:hitsPerPage].nil? ? params[:hitsPerPage] : params[:hitsPerPage].to_i

          params.delete(:page)
          params.delete(:hitsPerPage)
          params[:limit] = 200
        end

        # Returns raw json hits as follows:
        # {"hits"=>[{"id"=>"13", "href"=>"apple", "name"=>"iphone"}], "offset"=>0, "limit"=>|| 20, "nbHits"=>1,
        #  "exhaustiveNbHits"=>false, "processingTimeMs"=>0, "query"=>"iphone"}
        json = ms_raw_search(query, params)

        # Returns the ids of the hits: 13
        hit_ids = json['hits'].map { |hit| hit[ms_pk(meilisearch_options).to_s] }

        # condition_key gets the primary key of the document; looks for "id" on the options
        condition_key = if defined?(::Mongoid::Document) && include?(::Mongoid::Document)
                          ms_primary_key_method.in
                        else
                          ms_primary_key_method
                        end

        # meilisearch_options[:type] refers to the Model name (e.g. Product)
        # results_by_id creates a hash with the primaryKey of the document (id) as the key and doc itself as the value
        # {"13"=>#<Product id: 13, name: "iphone", href: "apple", tags: nil, type: nil,
        # description: "Puts even more features at your fingertips", release_date: nil>}
        results_by_id = meilisearch_options[:type].where(condition_key => hit_ids).index_by do |hit|
          ms_primary_key_of(hit)
        end

        results = json['hits'].map do |hit|
          o = results_by_id[hit[ms_pk(meilisearch_options).to_s].to_s]
          if o
            o.formatted = hit['_formatted']
            o
          end
        end.compact

        total_hits = json['hits'].length
        hits_per_page ||= 20
        page ||= 1

        res = MeiliSearch::Rails::Pagination.create(results, total_hits, meilisearch_options.merge(page: page, per_page: hits_per_page))
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
        name = options[:index_uid] || model_name.to_s.gsub('::', '_')
        name = "#{name}_#{::Rails.env}" if options[:per_environment]
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

      protected

      def ms_ensure_init(options = nil, settings = nil, index_settings = nil)
        raise ArgumentError, 'No `meilisearch` block found in your model.' if meilisearch_settings.nil?

        @ms_indexes ||= {}

        options ||= meilisearch_options
        settings ||= meilisearch_settings

        return @ms_indexes[settings] if @ms_indexes[settings]

        @ms_indexes[settings] = SafeIndex.new(ms_index_uid(options), meilisearch_options[:raise_on_failure], meilisearch_options)

        current_settings = @ms_indexes[settings].settings(getVersion: 1) rescue nil # if the index doesn't exist

        index_settings ||= settings.to_settings
        index_settings = options[:primary_settings].to_settings.merge(index_settings) if options[:inherit]

        options[:check_settings] = true if options[:check_settings].nil?

        if !ms_indexing_disabled?(options) && options[:check_settings] && meilisearch_settings_changed?(current_settings, index_settings)
          @ms_indexes[settings].update_settings(index_settings)
        end

        @ms_indexes[settings]
      end

      private

      def ms_configurations
        raise ArgumentError, 'No `meilisearch` block found in your model.' if meilisearch_settings.nil?

        if @configurations.nil?
          @configurations = {}
          @configurations[meilisearch_options] = meilisearch_settings
          meilisearch_settings.additional_indexes.each do |k, v|
            @configurations[k] = v

            next unless v.additional_indexes.any?

            v.additional_indexes.each do |options, index|
              @configurations[options] = index
            end
          end
        end
        @configurations
      end

      def ms_primary_key_method(options = nil)
        options ||= meilisearch_options
        options[:primary_key] || options[:id] || :id
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

      def meilisearch_settings_changed?(prev, current)
        return true if prev.nil?

        current.each do |k, v|
          prev_v = prev[k.to_s]
          if v.is_a?(Array) && prev_v.is_a?(Array)
            # compare array of strings, avoiding symbols VS strings comparison
            return true if v.map(&:to_s) != prev_v.map(&:to_s)
          elsif prev_v != v
            return true
          end
        end
        false
      end

      def ms_conditional_index?(options = nil)
        options ||= meilisearch_options
        options[:if].present? || options[:unless].present?
      end

      def ms_indexable?(document, options = nil)
        options ||= meilisearch_options
        if_passes = options[:if].blank? || ms_constraint_passes?(document, options[:if])
        unless_passes = options[:unless].blank? || !ms_constraint_passes?(document, options[:unless])
        if_passes && unless_passes
      end

      def ms_constraint_passes?(document, constraint)
        case constraint
        when Symbol
          document.send(constraint)
        when String
          document.send(constraint.to_sym)
        when Enumerable
          # All constraints must pass
          constraint.all? { |inner_constraint| ms_constraint_passes?(document, inner_constraint) }
        else
          unless constraint.respond_to?(:call)
            raise ArgumentError, "Unknown constraint type: #{constraint} (#{constraint.class})"
          end

          constraint.call(document)
        end
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
        if (defined?(::ActiveRecord) && ancestors.include?(::ActiveRecord::Base)) || respond_to?(:find_in_batches)
          find_in_batches(batch_size: batch_size, &block)
        elsif defined?(::Sequel) && self < Sequel::Model
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
        if meilisearch_options[:enqueue]
          unless self.class.send(:ms_indexing_disabled?, meilisearch_options)
            meilisearch_options[:enqueue].call(self, false)
          end
        else
          ms_index!(synchronous)
        end
      end

      def ms_synchronous?
        @ms_synchronous
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
          if defined?(::Sequel) && is_a?(Sequel::Model)
            new? || self.class.ms_must_reindex?(self)
          else
            new_record? || self.class.ms_must_reindex?(self)
          end
        true
      end

      def ms_perform_index_tasks
        return if !@ms_auto_indexing || @ms_must_reindex == false

        ms_enqueue_index!(ms_synchronous?)
        remove_instance_variable(:@ms_auto_indexing) if instance_variable_defined?(:@ms_auto_indexing)
        remove_instance_variable(:@ms_synchronous) if instance_variable_defined?(:@ms_synchronous)
        remove_instance_variable(:@ms_must_reindex) if instance_variable_defined?(:@ms_must_reindex)
      end
    end
  end
end
