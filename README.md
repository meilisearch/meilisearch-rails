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
- [🤖 Compatibility with MeiliSearch](#-compatibility-with-meilisearch)
- [🚀 Getting Started](#-getting-started)
- [⚙️ Settings](#️-settings)
- [🔍 Custom search](#-custom-search)
- [🪛 Options](#-options)
  - [MeiliSearch configuration & environment](#meilisearch-configuration--environment)
  - [Index configuration](#index-configuration)
    - [Custom attribute definition](#custom-attribute-definition)
    - [Custom primary key](#custom-primary-key)
    - [Conditional indexing](#conditional-indexing)
    - [Share a single index](#share-a-single-index)
    - [Queues & background jobs](#queues--background-jobs)
    - [Relations](#relations)
    - [Sanitize attributes](#sanitize-attributes)
    - [UTF-8 encoding](#utf-8-encoding)
  - [Manual operations](#manual-operations)
    - [Indexing & deletion](#indexing--deletion)
    - [Access the underlying index object](#access-the-underlying-index-object)
  - [Development & testing](#development--testing)
- [⚙️ Development workflow & contributing](#️-development-workflow--contributing)
- [👏  Credits](#--credits)

## 📖 Documentation

The whole usage of this gem is detailed in this README.

To learn more about MeiliSearch, check out our [Documentation](https://docs.meilisearch.com/learn/tutorials/getting_started.html) or our [API References](https://docs.meilisearch.com/reference/api/).

## 🤖 Compatibility with MeiliSearch

This package only guarantees the compatibility with the [version v0.22.0 of MeiliSearch](https://github.com/meilisearch/MeiliSearch/releases/tag/v0.22.0).

## 🔧 Installation <!-- omit in toc -->

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
  meilisearch_host: 'YourMeiliSearchHost', # example: http://localhost:7700
  meilisearch_api_key: 'YourMeiliSearchAPIKey',
}
```

The gem is compatible with [ActiveRecord](https://github.com/rails/rails/tree/master/activerecord), [Mongoid](https://github.com/mongoid/mongoid) and [Sequel](https://github.com/jeremyevans/sequel).

#### Add documents <!-- omit in toc -->

The following code will create a `Book` index and add search capabilities to your `Book` model.

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch do
    attribute :title, :author # only the attributes 'title', and 'author' will be sent to MeiliSearch
    # all attributes will be sent to MeiliSearch if block is left empty
  end
end
```

⚠️ Note that even if you want to use all the default options, you must declare an empty `meilisearch` block in your model.

#### Basic Backend Search <!-- omit in toc -->

We **strongly recommend the use of front-end search** through our [JavaScript API Client](https://github.com/meilisearch/meilisearch-js/) or [Instant Meilisearch plugin](https://github.com/meilisearch/instant-meilisearch)

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

This gem supports:
- [kaminari](https://github.com/amatsuda/kaminari)
- [pagy](https://github.com/ddnexus/pagy)
- [will_paginate](https://github.com/mislav/will_paginate).

Specify the `:pagination_backend` in the configuration file:

```ruby
MeiliSearch.configuration = {
  meilisearch_host: 'YourMeiliSearchHost',
  meilisearch_api_key: 'YourMeiliSearchAPIKey',
  pagination_backend: :kaminari #:will_paginate
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

#### Extra Configuration <!-- omit in toc -->

Requests made to MeiliSearch may timeout and retry. To adapt the behavior to
your needs, you can change the parameters during configuration:

```ruby
MeiliSearch.configuration = {
  meilisearch_host: 'YourMeiliSearchHost',
  meilisearch_api_key: 'YourMeiliSearchAPIKey',
  timeout: 2,
  max_retries: 1,
}
```

## ⚙️ Settings

You can configure the index settings by adding them inside the `meilisearch` block as shown below:

```ruby
class Book < ApplicationRecord
  include MeiliSearch

  meilisearch do
    searchable_attributes [:title, :author, :publisher, :description]
    filterable_attributes [:genre]
    ranking_rules [
      'proximity',
      'typo',
      'words',
      'attribute',
      'sort',
      'exactness',
      'publication_year:desc'
    ]
    synonyms nyc: ['new york']

    # The following parameters are applied when calling the search() method:
    attributes_to_highlight ['*']
    attributes_to_crop [:description]
    crop_length 10
  end
end
```

Check the dedicated section of the documentation, for more information on the [settings](https://docs.meilisearch.com/reference/features/settings.html).

## 🔍 Custom search

All the supported options are described in the [search parameters](https://docs.meilisearch.com/reference/features/search_parameters.html) section of the documentation.

```ruby
Book.search('Harry', attributesToHighlight: ['*'])
```
👉 Don't forget that `attributes_to_highlight`, `attributes_to_crop`, and
`crop_length` can be set up in the `meilisearch` block of your model.

## 🪛 Options

### MeiliSearch configuration & environment

#### Custom index_uid <!-- omit in toc -->

By default, the **index_uid** will be the class name, e.g. `Book`. You can customize the index_uid by using the `index_uid:` option.

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch index_uid: 'MyCustomUID' do
  end
end
```

#### Index UID according to the environment <!-- omit in toc -->

You can suffix the index UID with the current Rails environment using the following option:

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch per_environment: true do # The index UID will be "Book_#{Rails.env}"
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
      "#{first_name} #{last_name}"
    end
    add_attribute :full_name_reversed
  end

  def full_name_reversed
    "#{last_name} #{first_name}"
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

By default, the primary key is based on your record's id. You can change this behavior by specifying the `primary_key:` option.

Note that the primary key must have a **unique value**.

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch primary_key: 'ISBN' do
  end
end
```
#### Conditional indexing

You can control if a record must be indexed by using the `if:` or `unless:` options.<br>
As soon as you use those constraints, `add_documents` and `delete_documents` calls will be performed in order to keep the index synced with the DB. To prevent this behavior, you can create a `will_save_change_to_#{attr_name}?` method.

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch if: :published?, unless: :premium? do
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
##### Target multiple indexes <!-- omit in toc -->

You can index a record in several indexes using the `add_index` option:

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  PUBLIC_INDEX_UID = 'Books'
  SECURED_INDEX_UID = 'PrivateBooks'

  # store all books in index 'SECURED_INDEX_UID'
  meilisearch index_uid: SECURED_INDEX_UID do
    searchable_attributes [:title, :author]

    # store all 'public' (released and not premium) books in index 'PUBLIC_INDEX_UID'
    add_index PUBLIC_INDEX_UID, if: :public? do
      searchable_attributes [:title, :author]
    end
  end

  private
  def public?
    released? && !premium?
  end
end
```

#### Share a single index

You may want to share an index between several models. You'll need to ensure you don't have any conflict with the `primary_key` of the models involved.

```ruby
class Cat < ActiveRecord::Base
  include MeiliSearch

  meilisearch index_uid: 'Animals', primary_key: :ms_id do
  end

  private
  def ms_id
    "cat_#{primary_key}" # ensure the cats & dogs primary_keys are not conflicting
  end
end

class Dog < ActiveRecord::Base
  include MeiliSearch

  meilisearch index_uid: 'Animals', primary_key: :ms_id do
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
end
```

🤔 If you are performing updates and deletions in the background, a record deletion can be committed to your database prior to the job actually executing. Thus if you were to load the record to remove it from the database then your `ActiveRecord#find` will fail with a `RecordNotFound`.

In this case you can bypass loading the record from **ActiveRecord** and just communicate with the index directly.

With **ActiveJob**:

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch enqueue: :trigger_job do
    attribute :title, :author, :description
  end

  def self.trigger_job(record, remove)
    MyActiveJob.perform_later(record.id, remove)
  end
end

class MyActiveJob < ApplicationJob
  def perform(id, remove)
    if remove
      # The record has likely already been removed from your database so we cannot
      # use ActiveRecord#find to load it.
      # We access the underlying MeiliSearch index object.
      Book.index.delete_document(id)
    else
      # The record should be present.
      Book.find(id).index!
    end
  end
end
```

With [**Sidekiq**](https://github.com/mperham/sidekiq):

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch enqueue: :trigger_sidekiq_worker do
    attribute :title, :author, :description
  end

  def self.trigger_sidekiq_worker(record, remove)
    MySidekiqWorker.perform_async(record.id, remove)
  end
end

class MySidekiqWorker
  def perform(id, remove)
    if remove
      # The record has likely already been removed from your database so we cannot
      # use ActiveRecord#find to load it.
      # We access the underlying MeiliSearch index object.
      Book.index.delete_document(id)
    else
      # The record should be present.
      Book.find(id).index!
    end
  end
end
```

With [**DelayedJob**](https://github.com/collectiveidea/delayed_job):

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch enqueue: :trigger_delayed_job do
    attribute :title, :author, :description
  end

  def self.trigger_delayed_job(record, remove)
    if remove
      record.delay.remove_from_index!
    else
      record.delay.index!
    end
  end
end
```

#### Relations

Extend a change to a related record.

**With ActiveRecord**, you'll need to use `touch` and `after_touch`.

```ruby
class Author < ActiveRecord::Base
  include MeiliSearch

  has_many :books
  # If your association uses belongs_to
  # - use `touch: true`
  # - do not define an `after_save` hook
  after_save { books.each(&:touch) }
end

class Book < ActiveRecord::Base
  include MeiliSearch

  belongs_to :author
  after_touch :index!

  meilisearch do
    attribute :title, :description, :publisher
    attribute :author do
      author.name
    end
  end
end
```

With **Sequel**, you can use the `touch` plugin to propagate changes.

```ruby
# app/models/author.rb
class Author < Sequel::Model
  include MeiliSearch

  one_to_many :books

  plugin :timestamps
  # Can't use the associations since it won't trigger the after_save
  plugin :touch

  # Define the associations that need to be touched here
  # Less performant, but allows for the after_save hook to be triggered
  def touch_associations
    apps.map(&:touch)
  end

  def touch
    super
    touch_associations
  end
end

# app/models/book.rb
class Book < Sequel::Model
  include MeiliSearch

  many_to_one :author
  after_touch :index!

  plugin :timestamps
  plugin :touch

  meilisearch do
    attribute :title, :description, :publisher
    attribute :author do
      author.name
    end
  end
end
```

#### Sanitize attributes

You can strip all HTML tags from your attributes with the `sanitize` option.

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch sanitize: true do
  end
end
```

#### UTF-8 encoding

You can force the UTF-8 encoding of all your attributes using the `force_utf8_encoding` option.

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch force_utf8_encoding: true do
  end
end
```

### Manual operations

#### Indexing & deletion

You can manually index a record by using the `index!` instance method and remove it by using the `remove_from_index!` instance method.

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

To delete all your records, use the `clear_index!` class method:

```ruby
Book.clear_index!
```

#### Access the underlying index object

To access the index object and use the [Ruby SDK](https://github.com/meilisearch/meilisearch-ruby) methods for an index, call the `index` class method:

```ruby
index = Book.index
# index.get_settings, index.number_of_documents
```

### Development & testing

#### Exceptions <!-- omit in toc -->

You can disable exceptions that could be raised while trying to reach MeiliSearch's API by using the `raise_on_failure` option:

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  # Only raise exceptions in development environment.
  meilisearch raise_on_failure: Rails.env.development? do
  end
end
```

#### Testing <!-- omit in toc -->

##### Synchronous testing <!-- omit in toc -->

You can force indexing and removing to be synchronous by setting the following option:

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch synchronous: true do
  end
end
```
🚨 This is only recommended for testing purposes, the gem will call the `wait_for_pending_update` method that will stop your code execution until the asynchronous task has been processed by MeilSearch.

##### Disable auto-indexing & auto-removal <!-- omit in toc -->

You can disable auto-indexing and auto-removing setting the following options:

```ruby
class Book < ActiveRecord::Base
  include MeiliSearch

  meilisearch auto_index: false, auto_remove: false do
  end
end
```

You can temporarily disable auto-indexing using the without_auto_index scope:

```ruby
Book.without_auto_index do
  # Inside this block, auto indexing task will not run.
  1.upto(10000) { Book.create! attributes }
end
```

## ⚙️ Development workflow & contributing

Any new contribution is more than welcome in this project!

If you want to know more about the development workflow or want to contribute, please visit our [contributing guidelines](/CONTRIBUTING.md) for detailed instructions!

## 👏  Credits

The provided features and the code base is inspired by [algoliasearch-rails](https://github.com/algolia/algoliasearch-rails/).

<hr>

**MeiliSearch** provides and maintains many **SDKs and Integration tools** like this one. We want to provide everyone with an **amazing search experience for any kind of project**. If you want to contribute, make suggestions, or just know what's going on right now, visit us in the [integration-guides](https://github.com/meilisearch/integration-guides) repository.
