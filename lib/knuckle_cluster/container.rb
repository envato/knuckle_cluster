module KnuckleCluster
  class Container
    def initialize(
      index:,
      name:,
      task:
    )
      @index = index
      @name = name
      @task = task
    end

    attr_reader :index, :name, :task
  end
end
