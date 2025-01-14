<p align="center">
  <img src="https://raw.githubusercontent.com/meilisearch/integration-guides/main/assets/logos/meilisearch_rails.svg" alt="Meilisearch-Rails" width="200" height="200" />
</p>

<h1 align="center">Meilisearch Rails</h1>

<h4 align="center">
  <a href="https://github.com/meilisearch/meilisearch">Meilisearch</a> |
  <a href="https://www.meilisearch.com/pricing?utm_campaign=oss&utm_source=integration&utm_medium=meilisearch-rails">Meilisearch Cloud</a> |
  <a href="https://docs.meilisearch.com">Documentation</a> |
  <a href="https://discord.meilisearch.com">Discord</a> |
  <a href="https://roadmap.meilisearch.com/tabs/1-under-consideration">Roadmap</a> |
  <a href="https://www.meilisearch.com">Website</a> |
  <a href="https://www.meilisearch.com/docs/faq">FAQ</a>
</h4>

<p align="center">
  <a href="https://github.com/meilisearch/meilisearch-rails/actions"><img src="https://github.com/meilisearch/meilisearch-rails/workflows/Tests/badge.svg" alt="Test"></a>
  <a href="https://app.codecov.io/gh/meilisearch/meilisearch-rails/tree/main" >
    <img src="https://codecov.io/gh/meilisearch/meilisearch-rails/branch/main/graph/badge.svg?token=9J7LRP11IR"/>
  </a>
  <a href="https://github.com/meilisearch/meilisearch-rails/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-informational" alt="License"></a>
  <a href="https://ms-bors.herokuapp.com/repositories/68"><img src="https://bors.tech/images/badge_small.svg" alt="Bors enabled"></a>
</p>

<p align="center">⚡ The Meilisearch integration for Ruby on Rails 💎</p>

**Meilisearch Rails** is the Meilisearch integration for Ruby on Rails developers.

**Meilisearch** is an open-source search engine. [Learn more about Meilisearch.](https://github.com/meilisearch/meilisearch)

## Table of Contents <!-- omit in TOC -->

- [📖 Documentation](#-documentation)
- [🤖 Compatibility with Meilisearch](#-compatibility-with-meilisearch)
- [🚀 Getting started](#-getting-started)
- [Compatibility](#-compatibility)
- [⚙️ Settings](#️-settings)
- [🔍 Custom search](#-custom-search)
- [🔍🔍 Multi search](#-multi-search)
- [🪛 Options](#-options)
  - [Meilisearch configuration & environment](#meilisearch-configuration--environment)
  - [Pagination with `kaminari` or `will_paginate`](#backend-pagination-with-kaminari-or-will_paginate-)
  - [Pagination with `pagy`](#backend-pagination-with-pagy-)
  - [Index configuration](#index-configuration)
    - [Custom attribute definition](#custom-attribute-definition)
    - [Custom primary key](#custom-primary-key)
    - [Conditional indexing](#conditional-indexing)
    - [Share a single index](#share-a-single-index)
    - [Queues & background jobs](#queues--background-jobs)
    - [Relations](#relations)
    - [Sanitize attributes](#sanitize-attributes)
    - [UTF-8 encoding](#utf-8-encoding)
    - [Eager loading](#eager-loading)
  - [Manual operations](#manual-operations)
    - [Indexing & deletion](#indexing--deletion)
    - [Access the underlying index object](#access-the-underlying-index-object)
  - [Development & testing](#development--testing)
- [⚙️ Development workflow & contributing](#️-development-workflow--contributing)
- [👏  Credits](#--credits)

## 📖 Documentation

The whole usage of this gem is detailed in this README.

To learn more about Meilisearch, check out our [Documentation](https://www.meilisearch.com/docs/learn/tutorials/getting_started.html) or our [API References](https://www.meilisearch.com/docs/reference/api/).

## 🤖 Compatibility with Meilisearch

This package guarantees compatibility with [version v1.x of Meilisearch](https://github.com/meilisearch/meilisearch/releases/latest), but some features may not be present. Please check the [issues](https://github.com/meilisearch/meilisearch-rails/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22+label%3Aenhancement) for more info.

## 🔧 Installation <!-- omit in toc -->

This package requires Ruby version 3.0 or later and Rails 6.1 or later. It may work in older versions but it is not officially supported.

With `gem` in command line:
```bash
gem install meilisearch-rails
```

In your `Gemfile` with [bundler](https://bundler.io/):
```ruby
source 'https://rubygems.org'

gem 'meilisearch-rails'
```

### Run Meilisearch <!-- omit in toc -->

⚡️ **Launch, scale, and streamline in minutes with Meilisearch Cloud**—no maintenance, no commitment, cancel anytime. [Try it free now](https://cloud.meilisearch.com/login?utm_campaign=oss&utm_source=github&utm_medium=meilisearch-rails).

🪨  Prefer to self-host? [Download and deploy](https://www.meilisearch.com/docs/learn/self_hosted/getting_started_with_self_hosted_meilisearch?utm_campaign=oss&utm_source=github&utm_medium=meilisearch-rails) our fast, open-source search engine on your own infrastructure.

## 🚀 Getting started

#### Configuration <!-- omit in toc -->

Create a new file `config/initializers/meilisearch.rb` to setup your `MEILISEARCH_HOST` and `MEILISEARCH_API_KEY`

```ruby
Meilisearch::Rails.configuration = {
  meilisearch_url: ENV.fetch('MEILISEARCH_HOST', 'http://localhost:7700'),
  meilisearch_api_key: ENV.fetch('MEILISEARCH_API_KEY', 'YourMeilisearchAPIKey')
}
```

Or you can run a rake task to create the initializer file for you:

```bash
bin/rails meilisearch:install
```

The gem is compatible with [ActiveRecord](https://github.com/rails/rails/tree/master/activerecord), [Mongoid](https://github.com/mongoid/mongoid) and [Sequel](https://github.com/jeremyevans/sequel).

⚠️ Note that even if you want to use all the default options, you must declare an empty `meilisearch` block in your model.  

#### Add documents <!-- omit in toc -->

The following code will create a `Book` index and add search capabilities to your `Book` model.

```ruby
class Book < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch do
    attribute :title, :author # only the attributes 'title', and 'author' will be sent to Meilisearch
    # all attributes will be sent to Meilisearch if block is left empty
  end
end
```

#### Automatic indexing

As soon as you configure your model as mentioned above, `meilisearch-rails` will keep your database table data in sync with your Meilisearch instance using the `ActiveRecord` callbacks automatically.

#### Basic Backend Search <!-- omit in toc -->

We **strongly recommend the use of front-end search** through our [JavaScript API Client](https://github.com/meilisearch/meilisearch-js/) or [Instant Meilisearch plugin](https://github.com/meilisearch/instant-meilisearch)

Search returns ORM-compliant objects reloaded from your database.

```ruby
# Meilisearch is typo-tolerant:
hits = Book.search('harry pottre')
hits.each do |hit|
  puts hit.title
  puts hit.author
end
```

#### Extra Configuration <!-- omit in toc -->

Requests made to Meilisearch may timeout and retry. To adapt the behavior to
your needs, you can change the parameters during configuration:

```ruby
Meilisearch::Rails.configuration = {
  meilisearch_url: 'YourMeilisearchUrl',
  meilisearch_api_key: 'YourMeilisearchAPIKey',
  timeout: 2,
  max_retries: 1,
}
```

## Compatibility

If your model already has methods that meilisearch-rails defines such as `search` and `index`, they will not be redefined. You can target the meilisearch-rails-defined methods by prefixing with `ms_`, e.g. `Book.ms_search('harry potter')`.

## ⚙️ Settings

You can configure the index settings by adding them inside the `meilisearch` block as shown below:

```ruby
class Book < ApplicationRecord
  include Meilisearch::Rails

  meilisearch do
    searchable_attributes [:title, :author, :publisher, :description]
    filterable_attributes [:genre]
    sortable_attributes [:title]
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
    faceting max_values_per_facet: 2000
    pagination max_total_hits: 1000
    proximity_precision 'byWord'
  end
end
```

Check the dedicated section of the documentation, for more information on the [settings](https://www.meilisearch.com/docs/reference/api/settings#settings_parameters).

## 🔍 Custom search

All the supported options are described in the [search parameters](https://www.meilisearch.com/docs/reference/api/search#search-parameters) section of the documentation.

```ruby
Book.search('Harry', attributes_to_highlight: ['*'])
```

Then it's possible to retrieve the highlighted or cropped value by using the `formatted` method available in the object.

```ruby
harry_book.formatted # => {"id"=>"1", "name"=>"<em>Harry</em> Potter", "description"=>…
```

👉 Don't forget that `attributes_to_highlight`, `attributes_to_crop`, and
`crop_length` can be set up in the `meilisearch` block of your model.

### 🔍 Sorted search

As an example of how to use the sort option, here is how you could achieve
returning all books sorted by title in ascending order:

```ruby
Book.search('*', sort: ['title:asc'])
```

👉 Don't forget to set up the `sortable_attributes` option in the `meilisearch` block of your model.

## 🔍🔍 Multi search

Meilisearch supports searching multiple models at the same time (see [🔍 Custom search](#-custom-search) for search options):

```ruby
multi_search_results = Meilisearch::Rails.multi_search(
  Book => { q: 'Harry' },
  Manga => { q: 'Attack' }
)
```

You can iterate through the results with `.each` or `.each_result`:

```erb
<% multi_search_results.each do |record| %>
  <p><%= record.title %></p>
  <p><%= record.author %></p>
<% end %>

<p>Harry Potter and the Philosopher's Stone</p>
<p>J. K. Rowling</p>
<p>Harry Potter and the Chamber of Secrets</p>
<p>J. K. Rowling</p>
<p>Attack on Titan</p>
<p>Iseyama</p>
```

```erb
<% multi_search_results.each_result do |klass, results| %>
  <p><%= klass.name.pluralize %></p>

  <ul>
    <% results.each do |record| %>
      <li><%= record.title %></li>
    <% end %>
  </ul>
<% end %>


<p>Books</p>
<ul>
  <li>Harry Potter and the Philosopher's Stone</li>
  <li>Harry Potter and the Chamber of Secrets</li>
</ul>
<p>Mangas</p>
<ul>
  <li>Attack on Titan</li>
</ul>
```

See the [official multi search documentation](https://www.meilisearch.com/docs/reference/api/multi_search).

## 🪛 Options

### Meilisearch configuration & environment

### Backend Pagination with `kaminari` or `will_paginate` <!-- omit in toc -->

This gem supports:
- [kaminari](https://github.com/amatsuda/kaminari)
- [will_paginate](https://github.com/mislav/will_paginate)

Specify the `:pagination_backend` in the configuration file:

```ruby
Meilisearch::Rails.configuration = {
  meilisearch_url: 'YourMeilisearchUrl',
  meilisearch_api_key: 'YourMeilisearchAPIKey',
  pagination_backend: :kaminari # :will_paginate
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

The **number of hits per page defaults to 20**, you can customize it by adding the `hits_per_page` parameter to your search:

```ruby
Book.search('harry potter', hits_per_page: 10)
```

### Backend Pagination with `pagy` <!-- omit in toc -->

This gem supports [pagy](https://github.com/ddnexus/pagy) to paginate your search results.

To use `pagy` with your `meilisearch-rails` you need to:

Add the `pagy` gem to your Gemfile.
Create a new initializer `pagy.rb` with this:

```rb
# config/initializers/pagy.rb

require 'pagy/extras/meilisearch'
```

Then in your model you must extend `Pagy::Meilisearch`:

```rb
class Book < ApplicationRecord
  include Meilisearch::Rails
  extend Pagy::Meilisearch

  meilisearch # ...
end
```

And in your controller and view:

```rb
# controllers/books_controller.rb
def search
  hits = Book.pagy_search(params[:query])
  @pagy, @hits = pagy_meilisearch(hits, items: 25)
end


# views/books/search.html.rb
<%== pagy_nav(@pagy) %>
```

:warning: There is no need to set `pagination_backend` in the configuration block `Meilisearch::Rails.configuration` for `pagy`.

Check [`ddnexus/pagy`](https://ddnexus.github.io/pagy/extras/meilisearch) for more information.

#### Deactivate Meilisearch in certain moments

By default, HTTP connections to the Meilisearch URL are always active, but sometimes you want to disable the HTTP requests in a particular moment or environment.<br>
you have multiple ways to achieve this.

By adding `active: false` in the configuration initializer:

```ruby
Meilisearch::Rails.configuration = {
  meilisearch_url: 'YourMeilisearchUrl',
  meilisearch_api_key: 'YourMeilisearchAPIKey',
  active: false
}
```

Or you can disable programmatically:

```ruby
Meilisearch::Rails.deactivate! # all the following HTTP calls will be dismissed.

# or you can pass a block to it:

Meilisearch::Rails.deactivate! do
  # every Meilisearch call here will be dismissed, no error will be raised.
  # after the block, Meilisearch state will be active. 
end
```

You can also activate if you deactivated earlier:

```ruby
Meilisearch::Rails.activate!
```

:warning: These calls are persistent, so prefer to use the method with the block. This way, you will not forget to activate it afterward.

#### Custom index_uid <!-- omit in toc -->

By default, the **index_uid** will be the class name, e.g. `Book`. You can customize the index_uid by using the `index_uid:` option.

```ruby
class Book < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch index_uid: 'MyCustomUID'
end
```

#### Index UID according to the environment <!-- omit in toc -->

You can suffix the index UID with the current Rails environment by setting it globally:

```ruby
Meilisearch::Rails.configuration = {
  meilisearch_url: 'YourMeilisearchUrl',
  meilisearch_api_key: 'YourMeilisearchAPIKey',
  per_environment: true
}
```

This way your index UID will look like this `"Book_#{Rails.env}"`.

### Index configuration

#### Custom attribute definition

You can add a custom attribute by using the `add_attribute` option or by using a block.

⚠️ When using custom attributes, the gem is not able to detect changes on them. Your record will be pushed to the API even if the custom attribute didn't change. To prevent this behavior, you can create a `will_save_change_to_#{attr_name}?` method.

```ruby
class Author < ApplicationRecord
  include Meilisearch::Rails

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

Note that the primary key must return a **unique value** otherwise your data could be overwritten.

```ruby
class Book < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch primary_key: :isbn # isbn is a column in your table definition.
end
```

You can also set the `primary_key` as a method, this method will be evaluated in runtime, and its return 
will be used as the reference to the document when Meilisearch needs it.

```rb
class Book < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch primary_key: :my_custom_ms_id

  private

  def my_custom_ms_id
    "isbn_#{primary_key}" # ensure this return is unique, otherwise you'll lose data.
  end
end
```

#### Conditional indexing

You can control if a record must be indexed by using the `if:` or `unless:` options.<br>
As soon as you use those constraints, `add_documents` and `delete_documents` calls will be performed in order to keep the index synced with the DB. To prevent this behavior, you can create a `will_save_change_to_#{attr_name}?` method.

```ruby
class Book < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch if: :published?, unless: :premium?

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
  include Meilisearch::Rails

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
  include Meilisearch::Rails

  meilisearch index_uid: 'Animals', primary_key: :ms_id

  private

  def ms_id
    "cat_#{primary_key}" # ensure the cats & dogs primary_keys are not conflicting
  end
end

class Dog < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch index_uid: 'Animals', primary_key: :ms_id

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
  include Meilisearch::Rails

  meilisearch enqueue: true # ActiveJob will be triggered using a `meilisearch` queue
end
```

🤔 If you are performing updates and deletions in the background, a record deletion can be committed to your database prior to the job actually executing. Thus if you were to load the record to remove it from the database then your `ActiveRecord#find` will fail with a `RecordNotFound`.

In this case you can bypass loading the record from **ActiveRecord** and just communicate with the index directly.

With **ActiveJob**:

```ruby
class Book < ActiveRecord::Base
  include Meilisearch::Rails

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
      # We access the underlying Meilisearch index object.
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
  include Meilisearch::Rails

  meilisearch enqueue: :trigger_sidekiq_job do
    attribute :title, :author, :description
  end

  def self.trigger_sidekiq_job(record, remove)
    MySidekiqJob.perform_async(record.id, remove)
  end
end

class MySidekiqJob
  def perform(id, remove)
    if remove
      # The record has likely already been removed from your database so we cannot
      # use ActiveRecord#find to load it.
      # We access the underlying Meilisearch index object.
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
  include Meilisearch::Rails

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
  include Meilisearch::Rails

  has_many :books
  # If your association uses belongs_to
  # - use `touch: true`
  # - do not define an `after_save` hook
  after_save { books.each(&:touch) }
end

class Book < ActiveRecord::Base
  include Meilisearch::Rails

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
  include Meilisearch::Rails

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
  include Meilisearch::Rails

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
  include Meilisearch::Rails

  meilisearch sanitize: true
end
```

#### UTF-8 encoding

You can force the UTF-8 encoding of all your attributes using the `force_utf8_encoding` option.

```ruby
class Book < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch force_utf8_encoding: true
end
```

#### Eager loading

You can eager load associations using `meilisearch_import` scope.

```ruby
class Author < ActiveRecord::Base
  include Meilisearch::Rails

  has_many :books

  scope :meilisearch_import, -> { includes(:books) }
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

You can disable exceptions that could be raised while trying to reach Meilisearch's API by using the `raise_on_failure` option:

```ruby
class Book < ActiveRecord::Base
  include Meilisearch::Rails

  # Only raise exceptions in development environment.
  meilisearch raise_on_failure: Rails.env.development?
end
```

#### Testing <!-- omit in toc -->

##### Synchronous testing <!-- omit in toc -->

You can force indexing and removing to be synchronous by setting the following option:

```ruby
class Book < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch synchronous: true
end
```
🚨 This is only recommended for testing purposes, the gem will call the `wait_for_task` method that will stop your code execution until the asynchronous task has been processed by MeilSearch.

##### Disable auto-indexing & auto-removal <!-- omit in toc -->

You can disable auto-indexing and auto-removing setting the following options:

```ruby
class Book < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch auto_index: false, auto_remove: false
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

**Meilisearch** provides and maintains many **SDKs and Integration tools** like this one. We want to provide everyone with an **amazing search experience for any kind of project**. If you want to contribute, make suggestions, or just know what's going on right now, visit us in the [integration-guides](https://github.com/meilisearch/integration-guides) repository.
