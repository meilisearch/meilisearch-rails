class Dummy
  include MeiliSearch::Rails

  def self.model_name
    'Dummy'
  end

  meilisearch
end

class DummyChild < Dummy
end

class DummyGrandChild < DummyChild
end
