require 'support/active_record_schema'
Dir["#{File.dirname(__FILE__)}/models/*.rb"].sort.each { |file| require file }

