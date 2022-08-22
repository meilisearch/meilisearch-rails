def assert_queries(expected_count)
  queries = []

  ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
    queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name])
  end

  yield

  ActiveSupport::Notifications.unsubscribe('sql.active_record')
  expect(queries.size).to eq(expected_count), "#{queries.size} instead of #{expected_count} queries were executed. #{queries.inspect}"
end
