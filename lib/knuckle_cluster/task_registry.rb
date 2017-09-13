require 'knuckle_cluster/task'

module KnuckleCluster
  class TaskRegistry
    def initialize(ecs_client:, cluster_name:, agent_registry:)
      @ecs_client = ecs_client
      @cluster_name = cluster_name
      @agent_registry = agent_registry
    end

    def tasks
      @tasks ||= load_tasks
    end

    def where(container_instance_arn:)
      tasks_by_container_instance_arn[container_instance_arn]
    end

    private

    attr_reader :ecs_client, :cluster_name, :agent_registry

    def load_tasks
      task_arns = ecs_client.list_tasks(cluster: cluster_name).task_arns
      task_ids  = task_arns.map { |x| x[/.*\/(.*)/,1] }

      return if task_ids.empty?

      index = 0

      ecs_client.describe_tasks(tasks: task_ids, cluster: cluster_name).tasks.flat_map do |task|
        agent = agent_registry.find_by(container_instance_arn: task.container_instance_arn)

        task.containers.map do |container|
          index += 1

          Task.new(
            index:                  index,
            arn:                    task.task_arn,
            container_instance_arn: task.container_instance_arn,
            agent:                  agent,
            definition:             task.task_definition_arn[/.*\/(.*):.*/,1],
            task_name:              task.task_definition_arn[/.*\/(.*):\d/,1],
            container_name:         container.name,
          )
        end
      end
    end

    def tasks_by_container_instance_arn
      @tasks_by_container_instance_arn ||= tasks.group_by(&:container_instance_arn)
    end
  end
end
