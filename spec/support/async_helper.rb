module AsyncHelper
  def self.await_last_task
    task = Meilisearch::Rails.client.tasks['results'].first
    Meilisearch::Rails.client.wait_for_task task['uid']
  end
end
