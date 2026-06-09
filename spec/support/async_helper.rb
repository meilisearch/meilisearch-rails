module AsyncHelper
  def self.task_cursor(index_uids:, types: nil)
    ensure_index_uids!(index_uids)
    options = { limit: 1, index_uids: task_index_uids(index_uids) }
    options[:types] = types if types

    tasks = Meilisearch::Rails.client.tasks(options)['results']

    tasks.first&.fetch('uid', 0) || 0
  end

  def self.wait_for_pending_tasks(index_uids:, after_uid: nil, types: nil, timeout: 5, interval: 0.01)
    ensure_index_uids!(index_uids)
    options = { statuses: %w[enqueued processing], limit: 1000, index_uids: task_index_uids(index_uids) }
    options[:types] = types if types

    Timeout.timeout(timeout) do
      loop do
        pending = Meilisearch::Rails.client.tasks(options)['results']

        pending = pending.select { |task| task['uid'] > after_uid } if after_uid
        break if pending.empty?

        pending.each { |task| Meilisearch::Rails.client.wait_for_task(task['uid']) }
        sleep interval
      end
    end
  end

  def self.await_meilisearch_tasks(index_uids:, types: nil, timeout: 5, interval: 0.01)
    ensure_index_uids!(index_uids)

    result = yield

    wait_for_pending_tasks(
      index_uids: index_uids,
      types: types,
      timeout: timeout,
      interval: interval
    )

    result
  end

  def self.ensure_index_uids!(index_uids)
    return if index_uids.is_a?(Array) && index_uids.any? { |uid| !uid.nil? && !uid.to_s.empty? }

    raise ArgumentError, '`index_uids` must contain at least one non-empty index uid'
  end

  def self.task_index_uids(index_uids)
    environment_suffix = index_uid_environment_suffix
    return index_uids unless environment_suffix

    index_uids.map do |uid|
      uid = uid.to_s
      uid.end_with?(environment_suffix) ? uid : "#{uid}#{environment_suffix}"
    end
  end

  def self.index_uid_environment_suffix
    return unless Meilisearch::Rails.configuration[:per_environment]
    return unless defined?(Rails) && Rails.respond_to?(:env)

    "_#{Rails.env}"
  end
end
