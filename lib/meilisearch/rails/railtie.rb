require 'rails'

module MeiliSearch
  module Rails
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load 'meilisearch/rails/tasks/meilisearch.rake'
      end
    end

    class Engine < ::Rails::Engine
    end
  end
end
