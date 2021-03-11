require 'rails'

module MeiliSearch
  class Railtie < Rails::Railtie
    rake_tasks do
      load "meilisearch/tasks/meilisearch.rake"
    end
  end
  class Engine < Rails::Engine
  end
end
