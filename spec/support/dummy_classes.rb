class Dummy
  include MeiliSearch

  def self.model_name
    'Dummy'
  end

  meilisearch
end

class DummyChild < Dummy
end

class DummyGrandChild < DummyChild
end
