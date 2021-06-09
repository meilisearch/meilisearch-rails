# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), 'lib', 'meilisearch', 'version')

require 'date'

Gem::Specification.new do |s|
  s.name = "meilisearch-rails"
  s.version = MeiliSearch::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Meili"]
  s.date = Date.today
  s.description = "MeiliSearch integration for Ruby on Rails. See https://github.com/meilisearch/MeiliSearch"
  s.email = "bonjour@meilisearch.com"
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md"
  ]
  s.files = [
    ".rspec",
    "Gemfile",
    "LICENSE",
    "README.md",
    "Rakefile",
    "meilisearch-rails.gemspec",
    "lib/meilisearch-rails.rb",
    "lib/meilisearch/ms_job.rb",
    "lib/meilisearch/configuration.rb",
    "lib/meilisearch/pagination.rb",
    "lib/meilisearch/pagination/kaminari.rb",
    "lib/meilisearch/pagination/will_paginate.rb",
    "lib/meilisearch/railtie.rb",
    "lib/meilisearch/tasks/meilisearch.rake",
    "lib/meilisearch/utilities.rb",
    "lib/meilisearch/version.rb",
    "spec/spec_helper.rb",
    "spec/utilities_spec.rb"
  ]
  s.homepage = "http://github.com/meilisearch/meilisearch-rails"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.summary = "MeiliSearch integration for Ruby on Rails."
  s.add_dependency(%q<json>, [">= 1.5.1"])
  s.add_dependency(%q<meilisearch>, [">= 0.15.3"])
end
