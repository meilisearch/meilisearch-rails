lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'meilisearch/rails/version'

Gem::Specification.new do |s|
  s.name = 'meilisearch-rails'
  s.version = Meilisearch::Rails::VERSION

  s.authors = ['Meili']
  s.email = 'bonjour@meilisearch.com'

  s.description = 'Meilisearch integration for Ruby on Rails. See https://github.com/meilisearch/meilisearch'
  s.homepage = 'https://github.com/meilisearch/meilisearch-rails'
  s.summary = 'Meilisearch integration for Ruby on Rails.'
  s.licenses = 'MIT'

  s.require_paths = ['lib']

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

  s.required_ruby_version = '>= 3.0.0'

  s.add_dependency 'meilisearch', '~> 0.30'
  s.add_dependency 'mutex_m', '~> 0.2'
end
