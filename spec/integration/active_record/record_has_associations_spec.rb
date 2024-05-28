require 'support/models/post'

describe 'When a record has associations' do
  before(:all) do
    Post.clear_index!(true)
  end

  it 'eagerly loads associations' do
    post1 = Post.new(title: 'foo')
    post1.comments << Comment.new(body: 'one')
    post1.comments << Comment.new(body: 'two')
    post1.save!

    post2 = Post.new(title: 'bar')
    post2.comments << Comment.new(body: 'three')
    post2.comments << Comment.new(body: 'four')
    post2.save!

    assert_queries(2) do
      Post.reindex!
    end
  end
end
