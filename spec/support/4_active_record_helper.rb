# This file is responsible for one-time set up of ActiveRecord
# 1 - Set ActiveRecord connection & options
# 2 - Delete existing database
# 3 - Expose "TestModels::ActiveRecord.initialize_model" to allow dynamically creating models
require 'active_record'

ActiveRecord::Base.logger = Logger.new($stdout)
ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.establish_connection(
  'adapter' => defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3',
  'database' => 'data.sqlite3',
  'pool' => 5,
  'timeout' => 5000
)

ActiveRecord::Base.raise_in_transactional_callbacks = true if ActiveRecord::Base.respond_to?(:raise_in_transactional_callbacks)

FileUtils.rm_f('data.sqlite3')

module Models
  module ActiveRecord
    def self.schema
      @schema ||= ::ActiveRecord::Schema.new.tap { |schema| schema.verbose = false }
    end

    def self.initialize_model(specification)
      klass = Class.new(::ActiveRecord::Base) do
        define_singleton_method(:model_name) do
          name = "Models::ActiveRecord::#{specification.name}"
          ActiveModel::Name.new(self, nil, name)
        end
      end

      const_set(specification.name, klass)

      klass.class_eval(&specification.body)

      schema.create_table klass.table_name do |t|
        specification.fields.each do |field|
          t.send(field.type, field.name)
        end
      end
    end
  end
end
