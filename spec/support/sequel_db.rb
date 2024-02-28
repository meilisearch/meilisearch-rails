def sequel_db
  @sequel_db = Sequel.connect(if defined?(JRUBY_VERSION)
                                'jdbc:sqlite:sequel_data.sqlite3'
                              else
                                { 'adapter' => 'sqlite',
                                  'database' => 'sequel_data.sqlite3' }
                              end)
end

FileUtils.rm('sequel_data.sqlite3') if File.exist?('sequel_data.sqlite3')

