namespace :meilisearch do
  desc 'Reindex all models'
  task reindex: :environment do
    MeiliSearch::Rails::Utilities.reindex_all_models
  end

  desc 'Set settings to all indexes'
  task set_all_settings: :environment do
    MeiliSearch::Rails::Utilities.set_settings_all_models
  end

  desc 'Clear all indexes'
  task clear_indexes: :environment do
    puts 'clearing all indexes'
    MeiliSearch::Rails::Utilities.clear_all_indexes
  end
end
