module KnuckleCluster
  class Task
    def initialize(
      arn:,
      container_instance_arn:,
      agent:,
      definition:,
      name:,
      task_registry:
    )
      @arn = arn
      @container_instance_arn = container_instance_arn
      @agent = agent
      @definition = definition
      @name = name
      @task_registry = task_registry
    end

    attr_reader :arn, :container_instance_arn, :agent, :definition, :name, :task_registry

    def containers
      task_registry.containers_where(task: self)
    end
  end
end
