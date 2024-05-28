module AsyncHelper
  def self.await_last_task
    task = MeiliSearch::Rails.client.tasks['results'].first
    MeiliSearch::Rails.client.wait_for_task task['uid']
  end
end
