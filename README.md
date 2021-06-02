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
- [🔩 Settings](#-settings)
- [🔍 Custom search](#-custom-search)
- [🪛 Options](#-options)
  - [MeiliSearch configuration & environment](#meilisearch-configuration-&-environment)
    - [Custom index_uid](#custom-index_uid)
    - [Per-environment index_uid](#per-environment-index_uid)
  - [Index configuration](#index-configuration)
    - [Custom attribute definition](#custom-attribute-definition)
    - [Custom primary key](#custom-primary-key)
    - [Conditional indexing](#conditional-indexing)
      - [Target multiple indices](#target-multiple-indices)
    - [Share a single index](#share-a-single-index)
    - [Queues & background jobs](#queues-&-background-jobs)
    - [Sanitize attributes](#sanitize-attributes)
    - [UTF-8 encoding](#utf-8-encoding)
  - [Manual operations](#manual-operations)
    - [Indexing & deletion](#indexing-&-deletion)
    - [Access the underlying index object](#access-the-underlying-index-object)
  - [Best practices](#best-practices)
    - [Exceptions](#exceptions)
    - [Testing](#testing)
      - [Synchronous testing](#synchronous-testing)
      - [Disable auto-indexing & auto-removal](#disable-auto-indexing-&-auto-removal)
- [🤖 Compatibility with MeiliSearch](#-compatibility-with-meilisearch)
- [⚙️ Development Workflow and Contributing](#️-development-workflow-and-contributing)
- [👏 Credits](#-credits)

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
    attribute :title, :author # only the attributes 'title', and 'author' will be sent to MeiliSearch
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
 <% @hits.each do |hit| %>
  <%= hit.title %>
  <%= hit.author %>
<% end %>

<%= paginate @hits %> # if using kaminari

<%= will_paginate @hits %> # if using will_paginate
```

The **number of hits per page defaults to 20**, you can customize it by adding the `hitsPerPage` parameter to your search:

```ruby
Book.search('harry potter', hitsPerPage: 10)
```

##  ⚙️ Settings

You can configure the index settings by adding them inside the meilisearch block as shown below:

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
👉 Don't forget that `attributesToHighlight`, `attributesToCrop` and `cropLength` can be set up as settings in the MeiliSearch block of your model.


## 🪛 Options

### MeiliSearch configuration & environment

#### Custom index_uid

By default, the **index_uid** will be the class name, e.g. `Book`. You can customize the index_uid by using the `index_uid` option

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch
  meilisearch :index_uid => 'MyCustomUID' do
  end
end
```

#### Per-environment index_uid

You can suffix the index_uid with the current Rails environment using the following option:

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch
  meilisearch per_environment: true do # index name will be "Book_#{Rails.env}"
  end
end
```

### Index configuration

#### Custom attribute definition

You can add a custom attribute by using the `add_attribute` option or by using a block.

⚠️ When using custom attributes, the gem is not able to detect changes on them. Your record will be pushed to the API even if the custom attribute didn't change. To prevent this behavior, you can create a `will_save_change_to_#{attr_name}?` method.

```ruby
class Author < ApplicationRecord
    include MeiliSearch

    meilisearch do
      attribute :first_name, :last_name
      attribute :full_name do
        '#{first_name} #{last_name}'
      end
      add_attribute :full_name_reversed
    end

    def full_name_reversed
      '#{last_name} #{first_name}'
    end

    def will_save_change_to_full_name?
      will_save_change_to_first_name? || will_save_change_to_last_name?
    end

    def will_save_change_to_full_name_reversed?
      will_save_change_to_first_name? || will_save_change_to_last_name?
    end
end
```

#### Custom primary key
By default, the `primary key` is based on your record's id. You can change this behavior specifying the `:primary_key` option.

Note that the primary key must have a **unique value**.

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch
  meilisearch :primary_key => 'ISBN' do
  end
end
```
#### Conditional indexing

You can control if a record must be indexed by using the :if or :unless options
As soon as you use those constraints, add_documents and delete_dpcuments calls will be performed in order to keep the index synced with the DB. To prevent this behavior, you can create a `will_save_change_to_#{attr_name}?` method.

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch
  meilisearch :if published? :unless premium? do
  end

  def published?
    # [...]
  end

  def premium?
    # [...]
  end

  def will_save_change_to_published?
  # return true only if you know that the 'published' state changed
  end
end
```
  ##### Target multiple indices
  You can index a record in several indexes using the `add_index` option:
  ```ruby
  class Book < ActiveRecord::Base

  include MeiliSearch

  PUBLIC_INDEX_UID = 'Books'
  SECURED_INDEX_UID = 'PrivateBooks'

  # store all books in index 'SECURED_INDEX_UID'
  meilisearch index_uid: SECURED_INDEX_UID do
    searchableAttributes [:title, :author]

    # store all 'public' (released and not premium) books in index 'PUBLIC_INDEX_UID'
    add_index PUBLIC_INDEX_UID, if: :public? do
      searchableAttributes [:title, :author]
    end
  end

  private
  def public?
    released && !premium
  end

end
  ```
#### Share a single index
You may want to share an index between several models. You'll need to ensure you don't have any conflict with the primary_key of the models involved.

```ruby
class Cat < ActiveRecord::Base
  include MeiliSearch

  meilisearch :index_name =>  'Animals', primary_key: :ms_id do
  end

  private
  def ms_id
    "cat_#{primary_key}" # ensure the cats & dogs primary_keys are not conflicting
  end
end

class Dog < ActiveRecord::Base
  include MeiliSearch

  meilisearch :index_name => 'Animals', primary_key: :ms_id do
  end

  private
  def ms_id
    "dog_#{primary_key}" # ensure the cats & dogs primary_keys are not conflicting
  end
end
```
#### Queues & background jobs

You can configure the auto-indexing & auto-removal process to use a queue to perform those operations in background. ActiveJob queues are used by default but you can define your own queuing mechanism:

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch enqueue: true do # ActiveJob will be triggered using a `meilisearch` queue
end
```

#### Nested objects/relations
#### Sanitize attributes

You can strip all HTML tags from your attributes with the `sanitize` option.

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch :sanitize => true do
end
```
#### UTF-8 encoding

You can force the UTF-8 encoding of all your attributes using the `force_utf8_encoding` option.

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch :force_utf8_encoding => true do
end
```

### Manual operations

#### Manual indexing & deleting

You can manually index a record by using the `index!` instance method and remove it by using the `remove_from_index!` instance method

```ruby
  book = Book.create!(title: 'The Little Prince', author: 'Antoine de Saint-Exupéry')
  book.index!
  book.remove_from_index!
  book.destroy!
```

To reindex all your records, use the `reindex!` class method:

```ruby
  Book.reindex!

  # You can also index a subset of your records
  Book.where('updated_at > ?', 10.minutes.ago).reindex!
```

To delete all your records, use the `clear_index!` class method

```ruby
  Book.clear_index!
```

#### Access the underlying index object

To access the index object and use the meilisearch-ruby index methods, call the `ìndex` class method:

```ruby
  index = Book.index
  # index.get_settings, index.number_of_documents
```

### Best practices / Code samples
#### Exceptions

You can disable exceptions that could be raised while trying to reach MeiliSearch's API by using the `raise_on_failure` option:

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  # only raise exceptions in development environment
  meilisearch :raise_on_failure => Rails.env.development? do
end
```

#### Testing
  ##### Synchronous testing
  You can force indexing and removing to be synchronous by setting the following option:

  ```ruby
  class Book < ActiveRecord::Base
    include MeiliSearch

    meilisearch synchronous: true do
  end
  ```
  🚨 This is only recommended for testing purposes, the gem will call the `wait_for_pending_update` method that will stop your code execution until the asynchronous task has been processed by MeilSearch.

  ##### Disable auto-indexing & auto-removal

  You can disable auto-indexing and auto-removing setting the following options:

  ```ruby
  class Book < ActiveRecord::Base
    include MeiliSearch

    meilisearch auto_index: false, auto_remove: false do
  end
  ```

  You can temporarily disable auto-indexing using the without_auto_index scope:

  ```ruby
  Book.without_auto_index do
    1.upto(10000) { Book.create! attributes } # inside this block, auto indexing task will not run.
  end
  ```


## Compatibility with MeiliSearch
## Development workflow & contributing
## Credits
