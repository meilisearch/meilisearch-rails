namespace :meilisearch do
  desc 'Reindex all models'
  task reindex: :environment do
    puts 'Reindexing all Meilisearch models'

    Meilisearch::Rails::Utilities.reindex_all_models
  end

  desc 'Set settings to all indexes'
  task set_all_settings: :environment do
    puts 'Set settings in all Meilisearch models'

    Meilisearch::Rails::Utilities.set_settings_all_models
  end

  desc 'Clear all indexes'
  task clear_indexes: :environment do
    puts 'Clearing indexes from all Meilisearch models'

    Meilisearch::Rails::Utilities.clear_all_indexes
  end

  desc 'Create initializer file'
  task install: :environment do
    puts 'Creating initializer file'

    copy_file "#{__dir__}/../templates/initializer.rb", 'config/initializers/meilisearch.rb'
  end
end
