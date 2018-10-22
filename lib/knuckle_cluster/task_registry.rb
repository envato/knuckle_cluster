require 'knuckle_cluster/task'
require 'knuckle_cluster/container'

module KnuckleCluster
  class TaskRegistry
    def initialize(ecs_client:, cluster_name:, agent_registry:, hide: {})
      @ecs_client     = ecs_client
      @cluster_name   = cluster_name
      @agent_registry = agent_registry
      @hide           = hide
    end

    def tasks
      @tasks ||= load_tasks.compact
    end

    def containers
      tasks && all_containers
    end

    def where(container_instance_arn:)
      tasks_by_container_instance_arn[container_instance_arn]
    end

    def containers_where(task:)
      containers_by_task[task]
    end

    private

    attr_reader :ecs_client, :cluster_name, :agent_registry, :all_containers

    def load_tasks
      task_arns = ecs_client.list_tasks(cluster: cluster_name).task_arns
      task_ids  = task_arns.map { |x| x[/.*\/(.*)/,1] }

      return [] if task_ids.empty?

      @all_containers = []
      index = 0

      ecs_client.describe_tasks(tasks: task_ids, cluster: cluster_name).tasks.flat_map do |task|
        agent = agent_registry.find_by(container_instance_arn: task.container_instance_arn)

        task_name = task.task_definition_arn[/.*\/(.*):\d/,1]

        if @hide[:task]
          regex = Regexp.new(@hide[:task])
          next if regex.match(task_name)
        end

        #Exclude any tasks that have no connectable containers
        containers = task.containers
        if @hide[:container]
          regex = Regexp.new(@hide[:container])
          containers.reject!{|container| regex.match(container.name)}
        end
        next unless containers.any?

        Task.new(
          arn:                    task.task_arn,
          container_instance_arn: task.container_instance_arn,
          agent:                  agent,
          definition:             task.task_definition_arn[/.*\/(.*):.*/,1],
          name:                   task_name,
          task_registry:          self,
        ).tap do |new_task|
          containers.each do |container|
            index += 1

            all_containers << Container.new(
              index: index,
              name:  container.name,
              task:  new_task,
            )
          end
        end
      end
    end

    def tasks_by_container_instance_arn
      @tasks_by_container_instance_arn ||= tasks.group_by(&:container_instance_arn)
    end

    def containers_by_task
      @containers_by_task ||= all_containers.group_by(&:task)
    end
  end
end
