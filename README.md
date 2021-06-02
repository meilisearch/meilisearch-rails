<p align="center">
  <img src="https://res.cloudinary.com/meilisearch/image/upload/v1587402338/SDKs/meilisearch_rails.svg" alt="MeiliSearch-Rails" width="200" height="200" />
</p>

<h1 align="center">MeiliSearch Rails</h1>

<h4 align="center">
  <a href="https://github.com/meilisearch/MeiliSearch">MeiliSearch</a> |
  <a href="https://docs.meilisearch.com">Documentation</a> |
  <a href="https://slack.meilisearch.com">Slack</a> |
  <a href="https://roadmap.meilisearch.com/tabs/1-under-consideration">Roadmap</a> |
  <a href="https://www.meilisearch.com">Website</a> |
  <a href="https://docs.meilisearch.com/faq">FAQ</a>
</h4>

<p align="center">
  <a href="https://github.com/meilisearch/meilisearch-rails/actions"><img src="https://github.com/meilisearch/meilisearch-rails/workflows/Tests/badge.svg" alt="Test"></a>
  <a href="https://github.com/meilisearch/meilisearch-rails/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-informational" alt="License"></a>
  <a href="https://app.bors.tech/repositories/33032"><img src="https://bors.tech/images/badge_small.svg" alt="Bors enabled"></a>
</p>

<p align="center">⚡ The MeiliSearch integration for Ruby on Rails 💎</p>

**MeiliSearch Rails** is the MeiliSearch integration for Ruby on Rails developers.

**MeiliSearch** is an open-source search engine. [Discover what MeiliSearch is!](https://github.com/meilisearch/MeiliSearch)

## Table of Contents <!-- omit in toc -->

- [📖 Documentation](#-documentation)
- [🔧 Installation](#-installation)
- [🚀 Getting Started](#-getting-started)
- [⚙️ Settings](#-settings)
- [🔍 Custom search](#-custom-search)
- [🪛 Options](#-options)

## 📖 Documentation

See our [Documentation](https://docs.meilisearch.com/learn/tutorials/getting_started.html) or our [API References](https://docs.meilisearch.com/reference/api/).

## 🔧 Installation

This package requires Ruby version 2.6.0 or later and Rails 5.2 or later.

With `gem` in command line:
```bash
gem install meilisearch-rails
```

In your `Gemfile` with [bundler](https://bundler.io/):
```ruby
source 'https://rubygems.org'

gem 'meilisearch-rails'
```

### Run MeiliSearch <!-- omit in toc -->

There are many easy ways to [download and run a MeiliSearch instance](https://docs.meilisearch.com/reference/features/installation.html#download-and-launch).

For example, if you use Docker:

```bash
docker pull getmeili/meilisearch:latest # Fetch the latest version of MeiliSearch image from Docker Hub
docker run -it --rm -p 7700:7700 getmeili/meilisearch:latest ./meilisearch --master-key=masterKey
```

NB: you can also download MeiliSearch from **Homebrew** or **APT**.

## 🚀 Getting Started

#### Configuration <!-- omit in toc -->

Create a new file `config/initializers/meilisearch.rb` to setup your `MEILISEARCH_HOST` and `MEILISEARCH_API_KEY`

```ruby

MeiliSearch.configuration = {
    meilisearch_host: 'YourMeiliSearchHost',
    meilisearch_api_key: 'YourMeiliSearchAPIKey',
}
```

The gem is compatible with [ActiveRecord](https://github.com/rails/rails/tree/master/activerecord), [Mongoid](https://github.com/mongoid/mongoid) and [Sequel](https://github.com/jeremyevans/sequel).


#### Add documents <!-- omit in toc -->

The following code will create a `Book` index and add search capabilities to your `Book` model

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch do
    # all attributes will be sent to MeiliSearch if block is left empty
  end
end
```

#### Basic Backend Search <!-- omit in toc -->

We **strongly recommend the use of front-end search** through our [Javascript API Client](https://github.com/meilisearch/meilisearch-js/) or [Instant Meilisearch plugin](https://github.com/meilisearch/instant-meilisearch)

Search returns ORM-compliant objects reloaded from your database.

```ruby
# MeiliSearch is typo-tolerant:
hits = Book.search('harry pottre')
hits.each do |hit|
  puts hit.title
  puts hit.author
end
```

#### Backend Pagination <!-- omit in toc -->

We support both [kaminari](https://github.com/amatsuda/kaminari) and [will_paginate](https://github.com/mislav/will_paginate).

To use `:kaminari`, specify the `:pagination_backend` in the configuration file:

```ruby
MeiliSearch.configuration = {
    meilisearch_host: 'YourMeiliSearchHost',
    meilisearch_api_key: 'YourMeiliSearchAPIKey',
    pagination_backend: :kaminari
}
```

Then, as soon as you use the `search` method, the returning results will be paginated:

```ruby
# controller
@hits = Book.search('harry potter')


# views
@hits.each do |hit|
  puts hit.title
  puts hit.author
end

<%= paginate @hits %> # if using kaminari

<%= will_paginate @hits %> # if using will_paginate
```

The **number of hits per page defaults to 20**, you can customize it by adding the `hitsPerPage` parameter to your search:

```ruby
Book.search('harry potter', hitsPerPage: 10)
```

##  ⚙️ Settings

You can configure the index settings by adding them inside the meilisearch block as shown bellow:

```ruby
class Book < ApplicationRecord
    include MeiliSearch

    meilisearch do
        searchableAttributes ['title', 'author', 'publisher', 'description']
        attributesForFaceting ['genre']
        rankingRules [
            "proximity",
            "typo",
            "words",
            "attribute",
            "wordsPosition",
            "exactness",
            "desc(publication_year)"
        ]
        attributesToHighlight ['*']
        attributesToCrop ['description']
        cropLength 10
        synonyms got: ['game of thrones']
    end
end
```

Check the dedicated section of the documentation, for more information on the [settings](https://docs.meilisearch.com/reference/features/settings.html).

🎁  We have added the possibility to use the following search parameters `attributesToHighlight`, `attributesToCrop`, `cropLength` as settings (see example above).


## 🔍 Custom search

All the supported options are described in the [search parameters](https://docs.meilisearch.com/reference/features/search_parameters.html) section of the documentation.

```ruby
Book.search('Harry', { filters: 'author = J. K. Rowling' })
```
👉 Don't forget that `attributesToHighlight`, `attributesToCrop`, `cropLength` can be set up as settings in the MeiliSearch block of your model.


## 🪛 Options
