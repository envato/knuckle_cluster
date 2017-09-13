module KnuckleCluster
  class Task
    def initialize(
      index:,
      arn:,
      container_instance_arn:,
      agent:,
      definition:,
      task_name:,
      container_name:
    )
      @index = index
      @arn = arn
      @container_instance_arn = container_instance_arn
      @agent = agent
      @definition = definition
      @task_name = task_name
      @container_name = container_name
    end

    attr_reader :index, :arn, :container_instance_arn, :agent, :definition, :task_name, :container_name
  end
end
