module Models
  class ModelSpecification
    Field = Data.define(:name, :type)

    attr_reader :name, :fields, :body

    def initialize(klass_name, fields:, &block)
      @name = klass_name
      @fields = fields.map { |name, type| Field.new(name, type) }
      @body = block
    end
  end
end
