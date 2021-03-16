require 'meilisearch'

require 'meilisearch/version'
require 'meilisearch/utilities'

if defined? Rails
  begin
    require 'meilisearch/railtie'
  rescue LoadError
  end
end

begin
  require 'active_job'
rescue LoadError
  # no queue support, fine
end

require 'logger'

::MeiliSearch::Index.class_eval do
  def add_documents_sync(documents, primary_key = nil)
    update = add_documents(documents, primary_key)
    wait_for_pending_update(update['updateId'])      
  end

  def delete_all_documents_sync 
    update = delete_all_documents
    wait_for_pending_update(update['updateId']) 
  end

  def delete_document_sync(documentId)
    update = delete_document(documentId)
    wait_for_pending_update(update['updateId'])
  end
end

module MeiliSearch

  class NotConfigured < StandardError; end
  class BadConfiguration < StandardError; end
  class NoBlockGiven < StandardError; end
  class MixedSlavesAndReplicas < StandardError; end

  autoload :Configuration, 'meilisearch/configuration'
  extend Configuration

  autoload :Pagination, 'meilisearch/pagination'

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

    # MeiliSearch settings
    OPTIONS = [
      # Attributes
      :searchableAttributes, :attributesForFaceting, :unretrievableAttributes, :attributesToRetrieve,
      :attributesToIndex, #Legacy name of searchableAttributes
      # Ranking
      :ranking, :customRanking, # Replicas are handled via `add_replica`
      # Faceting
      :maxValuesPerFacet, :sortFacetValuesBy,
      # Highlighting / Snippeting
      :attributesToHighlight, :attributesToSnippet, :highlightPreTag, :highlightPostTag,
      :snippetEllipsisText, :restrictHighlightAndSnippetArrays,
      # Pagination
      :hitsPerPage, :paginationLimitedTo,
      # Typo
      :minWordSizefor1Typo, :minWordSizefor2Typos, :typoTolerance, :allowTyposOnNumericTokens,
      :disableTypoToleranceOnAttributes, :disableTypoToleranceOnWords, :separatorsToIndex,
      # Language
      :ignorePlurals, :removeStopWords, :camelCaseAttributes, :decompoundedAttributes,
      :keepDiacriticsOnCharacters, :queryLanguages, :indexLanguages,
      # Query Rules
      :enableRules,
      # Query Strategy
      :queryType, :removeWordsIfNoResults, :advancedSyntax, :optionalWords,
      :disablePrefixOnAttributes, :disableExactOnAttributes, :exactOnSingleWordQuery, :alternativesAsExact,
      # Performance
      :numericAttributesForFiltering, :allowCompressionOfIntegerArray,
      :numericAttributesToIndex, # Legacy name of numericAttributesForFiltering
      # Advanced
      :attributeForDistinct, :distinct, :replaceSynonymsInHighlight, :minProximity, :responseFields,
      :maxFacetHits,

      # Rails-specific
      :synonyms, :placeholders, :altCorrections,
    ]
    OPTIONS.each do |k|
      define_method k do |v|
        instance_variable_set("@#{k}", v)
      end
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
      raise ArgumentError.new('Cannot pass multiple attribute names if block given') if block_given? and names.length > 1
      raise ArgumentError.new('Cannot specify additional attributes on a replica index') if @options[:slave] || @options[:replica]
      @attributes ||= {}
      names.flatten.each do |name|
        @attributes[name.to_s] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end
    alias :attributes :attribute

    def add_attribute(*names, &block)
      raise ArgumentError.new('Cannot pass multiple attribute names if block given') if block_given? and names.length > 1
      raise ArgumentError.new('Cannot specify additional attributes on a replica index') if @options[:slave] || @options[:replica]
      @additional_attributes ||= {}
      names.each do |name|
        @additional_attributes[name.to_s] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end
    alias :add_attributes :add_attribute

    def is_mongoid?(object)
      defined?(::Mongoid::Document) && object.class.include?(::Mongoid::Document)
    end

    def is_sequel?(object)
      defined?(::Sequel) && object.class < ::Sequel::Model
    end

    def is_active_record?(object)
      !is_mongoid?(object) && !is_sequel?(object)
    end

    def get_default_attributes(object)
      if is_mongoid?(object)
        # work-around mongoid 2.4's unscoped method, not accepting a block
        object.attributes
      elsif is_sequel?(object)
        object.to_hash
      else
        object.class.unscoped do
          object.attributes
        end
      end
    end

    def get_attribute_names(object)
      get_attributes(object).keys
    end

    def attributes_to_hash(attributes, object)
      if attributes
        Hash[attributes.map { |name, value| [name.to_s, value.call(object) ] }]
      else
        {}
      end
    end

    def get_attributes(object)
      # If a serializer is set, we ignore attributes
      # everything should be done via the serializer
      if not @serializer.nil?
        attributes = @serializer.new(object).attributes
      else
        if @attributes.nil? || @attributes.length == 0
          # no `attribute ...` have been configured, use the default attributes of the model
          attributes = get_default_attributes(object)
        else
          # at least 1 `attribute ...` has been configured, therefore use ONLY the one configured
          if is_active_record?(object)
            object.class.unscoped do
              attributes = attributes_to_hash(@attributes, object)
            end
          else
            attributes = attributes_to_hash(@attributes, object)
          end
        end
      end

      attributes.merge!(attributes_to_hash(@additional_attributes, object)) if @additional_attributes

      if @options[:sanitize]
        sanitizer = begin
          ::HTML::FullSanitizer.new
        rescue NameError
          # from rails 4.2
          ::Rails::Html::FullSanitizer.new
        end
        attributes = sanitize_attributes(attributes, sanitizer)
      end

      if @options[:force_utf8_encoding] && Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f > 1.8
        attributes = encode_attributes(attributes)
      end

      attributes
    end

    def sanitize_attributes(v, sanitizer)
      case v
      when String
        sanitizer.sanitize(v)
      when Hash
        v.each { |key, value| v[key] = sanitize_attributes(value, sanitizer) }
      when Array
        v.map { |x| sanitize_attributes(x, sanitizer) }
      else
        v
      end
    end

    def encode_attributes(v)
      case v
      when String
        v.force_encoding('utf-8')
      when Hash
        v.each { |key, value| v[key] = encode_attributes(value) }
      when Array
        v.map { |x| encode_attributes(x) }
      else
        v
      end
    end

    def geoloc(lat_attr = nil, lng_attr = nil, &block)
      raise ArgumentError.new('Cannot specify additional attributes on a replica index') if @options[:slave] || @options[:replica]
      add_attribute :_geoloc do |o|
        block_given? ? o.instance_eval(&block) : { :lat => o.send(lat_attr).to_f, :lng => o.send(lng_attr).to_f }
      end
    end

    def tags(*args, &block)
      raise ArgumentError.new('Cannot specify additional attributes on a replica index') if @options[:slave] || @options[:replica]
      add_attribute :_tags do |o|
        v = block_given? ? o.instance_eval(&block) : args
        v.is_a?(Array) ? v : [v]
      end
    end

    def get_setting(name)
      instance_variable_get("@#{name}")
    end

    def to_settings
      settings = {}
      OPTIONS.each do |k|
        v = get_setting(k)
        settings[k] = v if !v.nil?
      end
      if !@options[:slave] && !@options[:replica]
        settings[:slaves] = additional_indexes.select { |opts, s| opts[:slave] }.map do |opts, s|
          name = opts[:index_name]
          name = "#{name}_#{Rails.env.to_s}" if opts[:per_environment]
          name
        end
        settings.delete(:slaves) if settings[:slaves].empty?
        settings[:replicas] = additional_indexes.select { |opts, s| opts[:replica] }.map do |opts, s|
          name = opts[:index_name]
          name = "#{name}_#{Rails.env.to_s}" if opts[:per_environment]
          name
        end
        settings.delete(:replicas) if settings[:replicas].empty?
      end
      settings
    end

    def add_index(index_name, options = {}, &block)
      raise ArgumentError.new('Cannot specify additional index on a replica index') if @options[:slave] || @options[:replica]
      raise ArgumentError.new('No block given') if !block_given?
      raise ArgumentError.new('Options auto_index and auto_remove cannot be set on nested indexes') if options[:auto_index] || options[:auto_remove]
      @additional_indexes ||= {}
      raise MixedSlavesAndReplicas.new('Cannot mix slaves and replicas in the same configuration (add_slave is deprecated)') if (options[:slave] && @additional_indexes.any? { |opts, _| opts[:replica] }) || (options[:replica] && @additional_indexes.any? { |opts, _| opts[:slave] })
      options[:index_name] = index_name
      @additional_indexes[options] = IndexSettings.new(options, &block)
    end

    def add_replica(index_name, options = {}, &block)
      raise ArgumentError.new('Cannot specify additional replicas on a replica index') if @options[:slave] || @options[:replica]
      raise ArgumentError.new('No block given') if !block_given?
      add_index(index_name, options.merge({ :replica => true, :primary_settings => self }), &block)
    end

    def add_slave(index_name, options = {}, &block)
      raise ArgumentError.new('Cannot specify additional slaves on a slave index') if @options[:slave] || @options[:replica]
      raise ArgumentError.new('No block given') if !block_given?
      add_index(index_name, options.merge({ :slave => true, :primary_settings => self }), &block)
    end

    def additional_indexes
      @additional_indexes || {}
    end
  end

  # Default queueing system
  if defined?(::ActiveJob::Base)
    # lazy load the ActiveJob class to ensure the
    # queue is initialized before using it
    # see https://github.com/algolia/algoliasearch-rails/issues/69
    autoload :MSJob, 'meilisearch/ms_job'
  end

  # this class wraps an Algolia::Index object ensuring all raised exceptions
  # are correctly logged or thrown depending on the `raise_on_failure` option
  class SafeIndex
    def initialize(index_uid, raise_on_failure)
      client = MeiliSearch.client
      @index = client.get_or_create_index(index_uid)
      @raise_on_failure = raise_on_failure.nil? || raise_on_failure
    end

    ::MeiliSearch::Index.instance_methods(false).each do |m|
      define_method(m) do |*args, &block|
        SafeIndex.log_or_throw(m, @raise_on_failure) do
          @index.send(m, *args, &block)
        end
      end
    end

    # special handling of wait_for_pending_update to handle null task_id
    def wait_for_pending_update(task_id)
      return if task_id.nil? && !@raise_on_failure # ok
      SafeIndex.log_or_throw(:wait_for_pending_update, @raise_on_failure) do
        @index.wait_for_pending_update(task_id)
      end
    end

    # special handling of settings to avoid raising errors on 404
    def settings(*args)
      SafeIndex.log_or_throw(:settings, @raise_on_failure) do
        begin
          @index.settings(*args)
        rescue ::MeiliSearch::ApiError => e
          return {} if e.code == 404 # not fatal
          raise e
        end
      end
    end

    # expose move as well
    # def self.move_index(old_name, new_name)
    #   SafeIndex.log_or_throw(:move_index, true) do
    #     ::Algolia.move_index(old_name, new_name)
    #   end
    # end

    private
    def self.log_or_throw(method, raise_on_failure, &block)
      begin
        yield
      rescue ::MeiliSearch::ApiError => e
        raise e if raise_on_failure
        # log the error
        (Rails.logger || Logger.new(STDOUT)).error("[meilisearch-rails] #{e.message}")
        # return something
        case method.to_s
        when 'search'
          # some attributes are required
          { 'hits' => [], 'hitsPerPage' => 0, 'page' => 0, 'facets' => {}, 'error' => e }
        else
          # empty answer
          { 'error' => e }
        end
      end
    end
  end

  # these are the class methods added when MeiliSearch is included
  module ClassMethods

    def self.extended(base)
      class <<base
        alias_method :without_auto_index, :ms_without_auto_index unless method_defined? :without_auto_index
        alias_method :reindex!, :ms_reindex! unless method_defined? :reindex!
        alias_method :reindex, :ms_reindex unless method_defined? :reindex
        alias_method :index_objects, :ms_index_objects unless method_defined? :index_objects
        alias_method :index!, :ms_index! unless method_defined? :index!
        alias_method :remove_from_index!, :ms_remove_from_index! unless method_defined? :remove_from_index!
        alias_method :clear_index!, :ms_clear_index! unless method_defined? :clear_index!
        alias_method :search, :ms_search unless method_defined? :search
        alias_method :raw_search, :ms_raw_search unless method_defined? :raw_search
        alias_method :search_facet, :ms_search_facet unless method_defined? :search_facet
        alias_method :search_for_facet_values, :ms_search_for_facet_values unless method_defined? :search_for_facet_values
        alias_method :index, :ms_index unless method_defined? :index
        alias_method :index_name, :ms_index_name unless method_defined? :index_name
        alias_method :must_reindex?, :ms_must_reindex? unless method_defined? :must_reindex?
      end

      base.cattr_accessor :meilisearch_options, :meilisearch_settings
    end

    def meilisearch(options = {}, &block)
      self.meilisearch_settings = IndexSettings.new(options, &block)
      self.meilisearch_options = { :type => ms_full_const_get(model_name.to_s), :per_page => meilisearch_settings.get_setting(:hitsPerPage) || 10, :page => 1 }.merge(options)

      attr_accessor :highlight_result, :snippet_result

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
        else
          after_validation :ms_mark_synchronous if respond_to?(:after_validation)
        end
      end
      if options[:enqueue]
        raise ArgumentError.new("Cannot use a enqueue if the `synchronous` option if set") if options[:synchronous]
        proc = if options[:enqueue] == true
          Proc.new do |record, remove|
          MSJob.perform_later(record, remove ? 'ms_remove_from_index!' : 'ms_index!')
          end
        elsif options[:enqueue].respond_to?(:call)
          options[:enqueue]
        elsif options[:enqueue].is_a?(Symbol)
          Proc.new { |record, remove| self.send(options[:enqueue], record, remove) }
        else
          raise ArgumentError.new("Invalid `enqueue` option: #{options[:enqueue]}")
        end
        meilisearch_options[:enqueue] = Proc.new do |record, remove|
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
                self.db.after_commit do
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
        else
          after_destroy { |searchable| searchable.ms_enqueue_remove_from_index!(ms_synchronous?) } if respond_to?(:after_destroy)
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
      Thread.current["ms_without_auto_index_scope_for_#{self.model_name}"] = value
    end

    def ms_without_auto_index_scope
      Thread.current["ms_without_auto_index_scope_for_#{self.model_name}"]
    end

    def ms_reindex!(batch_size = MeiliSearch::IndexSettings::DEFAULT_BATCH_SIZE, synchronous = false)
      return if ms_without_auto_index_scope
      ms_configurations.each do |options, settings|
        next if ms_indexing_disabled?(options)
        index = ms_ensure_init(options, settings)
        next if options[:slave] || options[:replica]
        last_task = nil

        ms_find_in_batches(batch_size) do |group|
          if ms_conditional_index?(options)
            # delete non-indexable objects
            ids = group.select { |o| !ms_indexable?(o, options) }.map { |o| ms_object_id_of(o, options) }
            index.delete_objects(ids.select { |id| !id.blank? })
            # select only indexable objects
            group = group.select { |o| ms_indexable?(o, options) }
          end
          objects = group.map do |o|
            attributes = settings.get_attributes(o)
            unless attributes.class == Hash
              attributes = attributes.to_hash
            end
            attributes.merge 'objectID' => ms_object_id_of(o, options)
          end
          last_task = index.add_documents(objects)
        end
        index.wait_for_pending_update(last_task["taskID"]) if last_task and (synchronous || options[:synchronous])
      end
      nil
    end

    # reindex whole database using a extra temporary index + move operation
    def ms_reindex(batch_size = MeiliSearch::IndexSettings::DEFAULT_BATCH_SIZE, synchronous = false)
      return if ms_without_auto_index_scope
      ms_configurations.each do |options, settings|
        next if ms_indexing_disabled?(options)
        next if options[:slave] || options[:replica]

        # fetch the master settings
        master_index = ms_ensure_init(options, settings)
        master_settings = master_index.settings rescue {} # if master doesn't exist yet
        master_settings.merge!(JSON.parse(settings.to_settings.to_json)) # convert symbols to strings

        # remove the replicas of the temporary index
        master_settings.delete :slaves
        master_settings.delete 'slaves'
        master_settings.delete :replicas
        master_settings.delete 'replicas'

        # init temporary index
        src_index_name = ms_index_name(options)
        tmp_index_name = "#{src_index_name}.tmp"
        tmp_options = options.merge({ :index_name => tmp_index_name })
        tmp_options.delete(:per_environment) # already included in the temporary index_name
        tmp_settings = settings.dup

        if options[:check_settings] == false
          ::Algolia::copy_index!(src_index_name, tmp_index_name, %w(settings synonyms rules))
          tmp_index = SafeIndex.new(tmp_index_name, !!options[:raise_on_failure])
        else
          tmp_index = ms_ensure_init(tmp_options, tmp_settings, master_settings)
        end

          ms_find_in_batches(batch_size) do |group|
          if ms_conditional_index?(options)
            # select only indexable objects
            group = group.select { |o| ms_indexable?(o, tmp_options) }
          end
          objects = group.map { |o| tmp_settings.get_attributes(o).merge 'objectID' => ms_object_id_of(o, tmp_options) }
          tmp_index.add_documents(objects)
        end

        move_task = SafeIndex.move_index(tmp_index.name, src_index_name)
        master_index.wait_for_pending_update(move_task["taskID"]) if synchronous || options[:synchronous]
      end
      nil
    end

    def ms_set_settings(synchronous = false)
      ms_configurations.each do |options, settings|
        if options[:primary_settings] && options[:inherit]
          primary = options[:primary_settings].to_settings
          primary.delete :slaves
          primary.delete 'slaves'
          primary.delete :replicas
          primary.delete 'replicas'
          final_settings = primary.merge(settings.to_settings)
        else
          final_settings = settings.to_settings
        end

        index = SafeIndex.new(ms_index_name(options), true)
        task = index.update_settings(final_settings)
        index.wait_for_pending_update(task["taskID"]) if synchronous
      end
    end

    def ms_index_objects(objects, synchronous = false)
      ms_configurations.each do |options, settings|
        next if ms_indexing_disabled?(options)
        index = ms_ensure_init(options, settings)
        next if options[:slave] || options[:replica]
        task = index.add_documents(objects.map { |o| settings.get_attributes(o).merge 'objectID' => ms_object_id_of(o, options) })
        index.wait_for_pending_update(task["taskID"]) if synchronous || options[:synchronous]
      end
    end

    def ms_index!(object, synchronous = false)
      return if ms_without_auto_index_scope
      ms_configurations.each do |options, settings|
        next if ms_indexing_disabled?(options)
        object_id = ms_object_id_of(object, options)
        index = ms_ensure_init(options, settings)
        next if options[:slave] || options[:replica]
        if ms_indexable?(object, options)
          raise ArgumentError.new("Cannot index a record with a blank objectID") if object_id.blank?
          if synchronous || options[:synchronous]
            index.add_documents_sync(settings.get_attributes(object))
          else
            index.add_documents(settings.get_attributes(object))
          end
        elsif ms_conditional_index?(options) && !object_id.blank?
          # remove non-indexable objects
          if synchronous || options[:synchronous]
            index.delete_document_sync(object_id)
          else
            index.delete_document(object_id)
          end
        end
      end
      nil
    end

    def ms_remove_from_index!(object, synchronous = false)
      return if ms_without_auto_index_scope
      object_id = ms_object_id_of(object)
      raise ArgumentError.new("Cannot index a record with a blank objectID") if object_id.blank?
      ms_configurations.each do |options, settings|
        next if ms_indexing_disabled?(options)
        index = ms_ensure_init(options, settings)
        next if options[:slave] || options[:replica]
        if synchronous || options[:synchronous]
          index.delete_document_sync(object_id)
        else
          index.delete_document(object_id)
        end
      end
      nil
    end

    def ms_clear_index!(synchronous = false)
      ms_configurations.each do |options, settings|
        next if ms_indexing_disabled?(options)
        index = ms_ensure_init(options, settings)
        next if options[:slave] || options[:replica]
        synchronous || options[:synchronous] ? index.delete_all_documents_sync : index.delete_all_documents
        @ms_indexes[settings] = nil
      end
      nil
    end

    def ms_raw_search(q, params = {})
      index_name = params.delete(:index) ||
                   params.delete('index') ||
                   params.delete(:slave) ||
                   params.delete('slave') ||
                   params.delete(:replica) ||
                   params.delete('replica')
      index = ms_index(index_name)
      index.search(q, Hash[params.map { |k,v| [k.to_s, v.to_s] }])
    end

    module AdditionalMethods
      def self.extended(base)
        class <<base
          alias_method :raw_answer, :ms_raw_answer unless method_defined? :raw_answer
          alias_method :facets, :ms_facets unless method_defined? :facets
        end
      end

      def ms_raw_answer
        @ms_json
      end

      def ms_facets
        @ms_json['facets']
      end

      private
      def ms_init_raw_answer(json)
        @ms_json = json
      end
    end

    def ms_search(q, params = {})
      if MeiliSearch.configuration[:pagination_backend]
        # kaminari and will_paginate start pagination at 1, Algolia starts at 0
        params[:page] = (params.delete('page') || params.delete(:page)).to_i
        params[:page] -= 1 if params[:page].to_i > 0
      end
      json = ms_raw_search(q, params)
      hit_ids = json['hits'].map { |hit| hit['objectID'] }
      if defined?(::Mongoid::Document) && self.include?(::Mongoid::Document)
        condition_key = ms_object_id_method.in
      else
        condition_key = ms_object_id_method
      end
      results_by_id = meilisearch_options[:type].where(condition_key => hit_ids).index_by do |hit|
        ms_object_id_of(hit)
      end
      results = json['hits'].map do |hit|
        o = results_by_id[hit['objectID'].to_s]
        if o
          o.highlight_result = hit['_highlightResult']
          o.snippet_result = hit['_snippetResult']
          o
        end
      end.compact
      # Algolia has a default limit of 1000 retrievable hits
      total_hits = json['nbHits'].to_i < json['nbPages'].to_i * json['hitsPerPage'].to_i ?
        json['nbHits'].to_i: json['nbPages'].to_i * json['hitsPerPage'].to_i
      res = MeiliSearch::Pagination.create(results, total_hits, meilisearch_options.merge({ :page => json['page'].to_i + 1, :per_page => json['hitsPerPage'] }))
      res.extend(AdditionalMethods)
      res.send(:ms_init_raw_answer, json)
      res
    end

    def ms_search_for_facet_values(facet, text, params = {})
      index_name = params.delete(:index) ||
                   params.delete('index') ||
                   params.delete(:slave) ||
                   params.delete('slave') ||
                   params.delete(:replica) ||
                   params.delete('replicas')
      index = ms_index(index_name)
      query = Hash[params.map { |k, v| [k.to_s, v.to_s] }]
      index.search_facet(facet, text, query)['facetHits']
    end

    # deprecated (renaming)
    alias :ms_search_facet :ms_search_for_facet_values

    def ms_index(name = nil)
      if name
        ms_configurations.each do |o, s|
          return ms_ensure_init(o, s) if o[:index_name].to_s == name.to_s
        end
        raise ArgumentError.new("Invalid index/replica name: #{name}")
      end
      ms_ensure_init
    end

    def ms_index_name(options = nil)
      options ||= meilisearch_options
      name = options[:index_name] || model_name.to_s.gsub('::', '_')
      name = "#{name}_#{Rails.env.to_s}" if options[:per_environment]
      name
    end

    def ms_must_reindex?(object)
      # use +ms_dirty?+ method if implemented
      return object.send(:ms_dirty?) if (object.respond_to?(:ms_dirty?))
      # Loop over each index to see if a attribute used in records has changed
      ms_configurations.each do |options, settings|
        next if ms_indexing_disabled?(options)
        next if options[:slave] || options[:replica]
        return true if ms_object_id_changed?(object, options)
        settings.get_attribute_names(object).each do |k|
          return true if ms_attribute_changed?(object, k)
          # return true if !object.respond_to?(changed_method) || object.send(changed_method)
        end
        [options[:if], options[:unless]].each do |condition|
          case condition
          when nil
          when String, Symbol
            return true if ms_attribute_changed?(object, condition)
          else
            # if the :if, :unless condition is a anything else,
            # we have no idea whether we should reindex or not
            # let's always reindex then
            return true
          end
        end
      end
      # By default, we don't reindex
      return false
    end

    protected

    def ms_ensure_init(options = nil, settings = nil, index_settings = nil)
      raise ArgumentError.new('No `meilisearch` block found in your model.') if meilisearch_settings.nil?

      @ms_indexes ||= {}

      options ||= meilisearch_options
      settings ||= meilisearch_settings

      return @ms_indexes[settings] if @ms_indexes[settings]

      @ms_indexes[settings] = SafeIndex.new(ms_index_name(options), meilisearch_options[:raise_on_failure])

      current_settings = @ms_indexes[settings].settings(:getVersion => 1) rescue nil # if the index doesn't exist

      index_settings ||= settings.to_settings
      index_settings = options[:primary_settings].to_settings.merge(index_settings) if options[:inherit]

      options[:check_settings] = true if options[:check_settings].nil?

      if !ms_indexing_disabled?(options) && options[:check_settings] && meilisearch_settings_changed?(current_settings, index_settings)
        used_slaves = !current_settings.nil? && !current_settings['slaves'].nil?
        replicas = index_settings.delete(:replicas) ||
                   index_settings.delete('replicas') ||
                   index_settings.delete(:slaves) ||
                   index_settings.delete('slaves')
        index_settings[used_slaves ? :slaves : :replicas] = replicas unless replicas.nil? || options[:inherit]
        @ms_indexes[settings].update_settings(index_settings)
      end

      @ms_indexes[settings]
    end

    private

    def ms_configurations
      raise ArgumentError.new('No `meilisearch` block found in your model.') if meilisearch_settings.nil?
      if @configurations.nil?
        @configurations = {}
        @configurations[meilisearch_options] = meilisearch_settings
        meilisearch_settings.additional_indexes.each do |k,v|
          @configurations[k] = v

          if v.additional_indexes.any?
            v.additional_indexes.each do |options, index|
              @configurations[options] = index
            end
          end
        end
      end
      @configurations
    end

    def ms_object_id_method(options = nil)
      options ||= meilisearch_options
      options[:id] || options[:object_id] || :id
    end

    def ms_object_id_of(o, options = nil)
      o.send(ms_object_id_method(options)).to_s
    end

    def ms_object_id_changed?(o, options = nil)
      changed = ms_attribute_changed?(o, ms_object_id_method(options))
      changed.nil? ? false : changed
    end

    def meilisearch_settings_changed?(prev, current)
      return true if prev.nil?
      current.each do |k, v|
        prev_v = prev[k.to_s]
        if v.is_a?(Array) and prev_v.is_a?(Array)
          # compare array of strings, avoiding symbols VS strings comparison
          return true if v.map { |x| x.to_s } != prev_v.map { |x| x.to_s }
        else
          return true if prev_v != v
        end
      end
      false
    end

    def ms_full_const_get(name)
      list = name.split('::')
      list.shift if list.first.blank?
      obj = Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f < 1.9 ? Object : self
      list.each do |x|
        # This is required because const_get tries to look for constants in the
        # ancestor chain, but we only want constants that are HERE
        obj = obj.const_defined?(x) ? obj.const_get(x) : obj.const_missing(x)
      end
      obj
    end

    def ms_conditional_index?(options = nil)
      options ||= meilisearch_options
      options[:if].present? || options[:unless].present?
    end

    def ms_indexable?(object, options = nil)
      options ||= meilisearch_options
      if_passes = options[:if].blank? || ms_constraint_passes?(object, options[:if])
      unless_passes = options[:unless].blank? || !ms_constraint_passes?(object, options[:unless])
      if_passes && unless_passes
    end

    def ms_constraint_passes?(object, constraint)
      case constraint
      when Symbol
        object.send(constraint)
      when String
        object.send(constraint.to_sym)
      when Enumerable
        # All constraints must pass
        constraint.all? { |inner_constraint| ms_constraint_passes?(object, inner_constraint) }
      else
        if constraint.respond_to?(:call) # Proc
          constraint.call(object)
        else
          raise ArgumentError, "Unknown constraint type: #{constraint} (#{constraint.class})"
        end
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
        find_in_batches(:batch_size => batch_size, &block)
      elsif defined?(::Sequel) && self < Sequel::Model
        dataset.extension(:pagination).each_page(batch_size, &block)
      else
        # don't worry, mongoid has its own underlying cursor/streaming mechanism
        items = []
        all.each do |item|
          items << item
          if items.length % batch_size == 0
            yield items
            items = []
          end
        end
        yield items unless items.empty?
      end
    end

    def ms_attribute_changed?(object, attr_name)
      # if one of two method is implemented, we return its result
      # true/false means whether it has changed or not
      # +#{attr_name}_changed?+ always defined for automatic attributes but deprecated after Rails 5.2
      # +will_save_change_to_#{attr_name}?+ should be use instead for Rails 5.2+, also defined for automatic attributes.
      # If none of the method are defined, it's a dynamic attribute

      method_name = "#{attr_name}_changed?"
      if object.respond_to?(method_name)
        # If +#{attr_name}_changed?+ respond we want to see if the method is user defined or if it's automatically
        # defined by Rails.
        # If it's user-defined, we call it.
        # If it's automatic we check ActiveRecord version to see if this method is deprecated
        # and try to call +will_save_change_to_#{attr_name}?+ instead.
        # See: https://github.com/algolia/algoliasearch-rails/pull/338
        # This feature is not compatible with Ruby 1.8
        # In this case, we always call #{attr_name}_changed?
        if Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f < 1.9
          return object.send(method_name)
        end
        unless automatic_changed_method?(object, method_name) && automatic_changed_method_deprecated?
          return object.send(method_name)
        end
      end

      if object.respond_to?("will_save_change_to_#{attr_name}?")
        return object.send("will_save_change_to_#{attr_name}?")
      end

      # We don't know if the attribute has changed, so conservatively assume it has
      true
    end

    def automatic_changed_method?(object, method_name)
      raise ArgumentError.new("Method #{method_name} doesn't exist on #{object.class.name}") unless object.respond_to?(method_name)
      file = object.method(method_name).source_location[0]
      file.end_with?("active_model/attribute_methods.rb")
    end

    def automatic_changed_method_deprecated?
      (defined?(::ActiveRecord) && ActiveRecord::VERSION::MAJOR >= 5 && ActiveRecord::VERSION::MINOR >= 1) ||
          (defined?(::ActiveRecord) && ActiveRecord::VERSION::MAJOR > 5)
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
        meilisearch_options[:enqueue].call(self, true) unless self.class.send(:ms_indexing_disabled?, meilisearch_options)
      else
        ms_remove_from_index!(synchronous || ms_synchronous?)
      end
    end

    def ms_enqueue_index!(synchronous)
      if meilisearch_options[:enqueue]
        meilisearch_options[:enqueue].call(self, false) unless self.class.send(:ms_indexing_disabled?, meilisearch_options)
      else
        ms_index!(synchronous)
      end
    end

    private

    def ms_synchronous?
      @ms_synchronous == true
    end

    def ms_mark_synchronous
      @ms_synchronous = true
    end

    def ms_mark_for_auto_indexing
      @ms_auto_indexing = true
    end

    def ms_mark_must_reindex
      # ms_must_reindex flag is reset after every commit as part. If we must reindex at any point in
      # a stransaction, keep flag set until it is explicitly unset
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
