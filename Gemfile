source 'https://rubygems.org'

# gem 'meilisearch', path: '../meilisearch-ruby'

gemspec

gem 'rubysl', '~> 2.0', platform: :rbx if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'

group :development do
  gem 'rubocop', '1.27.0'
  gem 'rubocop-rails', '2.13.2'
  gem 'rubocop-rspec', '2.9.0'
end

group :test do
  rails_version = ENV['RAILS_VERSION'] || '6.1'
  sequel_version = ENV['SEQUEL_VERSION'] ? "~> #{ENV['SEQUEL_VERSION']}" : '>= 4.0'

  gem 'active_model_serializers'
  gem 'rails', "~> #{rails_version}"
  gem 'sequel', sequel_version

  gem 'sqlite3', '~> 2', platform: %i[rbx ruby]

  gem 'activerecord-jdbc-adapter', platform: :jruby
  gem 'activerecord-jdbcsqlite3-adapter', platform: :jruby
  gem 'jdbc-sqlite3', platform: :jruby
  gem 'rspec', '~> 3.0'
  gem 'simplecov', require: 'false'
  gem 'simplecov-cobertura', require: 'false'
  gem 'threads'

  gem 'byebug'
  gem 'dotenv', '~> 2.7', '>= 2.7.6'
  gem 'faker', '~> 2.17'
  gem 'kaminari'
  gem 'will_paginate', '>= 2.3.15'
end
