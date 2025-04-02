# This file is responsible for one-time set up of ActiveRecord
# 1 - Set ActiveRecord connection & options
# 2 - Delete existing database
# 3 - Expose an "ar_schema" for other files to create tables
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

def ar_schema
  @ar_schema ||= ActiveRecord::Schema.new
end

ar_schema.verbose = false
