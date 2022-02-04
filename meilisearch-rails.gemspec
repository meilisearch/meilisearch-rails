require File.join(File.dirname(__FILE__), 'lib', 'meilisearch', 'rails', 'version')

require 'date'

Gem::Specification.new do |s|
  s.name = 'meilisearch-rails'
  s.version = MeiliSearch::Rails::VERSION

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['Meili']
  s.description = 'Meilisearch integration for Ruby on Rails. See https://github.com/meilisearch/meilisearch'
  s.email = 'bonjour@meilisearch.com'
  s.homepage = 'http://github.com/meilisearch/meilisearch-rails'
  s.licenses = ['MIT']
  s.require_paths = ['lib']
  s.summary = 'Meilisearch integration for Ruby on Rails.'

  s.extra_rdoc_files = [
    'LICENSE',
    'README.md'
  ]

  s.files = Dir[
    'lib/**/*',
    '.rspec',
    'meilisearch-rails.gemspec',
    'Gemfile',
    'LICENSE',
    'README.md',
    'Rakefile'
  ]

  s.required_ruby_version = '>= 2.6.0'
  s.add_dependency('json', ['>= 1.5.1'])
  s.add_dependency('meilisearch', ['>= 0.15.4'])
end
