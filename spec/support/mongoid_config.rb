mongo_db_name = (ENV['MONGODB_DATABASE'] || '_ms_rails_test') + SecureRandom.hex(8)
Mongoid.load_configuration(
  {
    clients: {
      default: {
        database: mongo_db_name,
        hosts: [ENV['MONGODB_HOST'] || 'localhost:27017'],
        options: {
          read: { mode: :primary },
          max_pool_size: 1
        }
      }
    }
  }
)
