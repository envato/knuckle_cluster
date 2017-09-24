require 'knuckle_cluster/agent'
require 'knuckle_cluster/task_registry'

require 'forwardable'

module KnuckleCluster
  class EcsAgentRegistry
    extend Forwardable

    def initialize(aws_client_config:, cluster_name:)
      @aws_client_config = aws_client_config
      @cluster_name = cluster_name
    end

    def agents
      @agents ||= load_agents
    end

    def find_by(container_instance_arn:)
      agents_by_container_instance_arn[container_instance_arn]&.first
    end

    def output_agents
      tp agents,
        :index,
        :instance_id,
        # :public_ip,
        # :private_ip,
        # :availability_zone,
        { task: { display_method: 'tasks.name', width: 999 } },
        { container: { display_method: 'tasks.containers.name', width: 999 } }
    end

    def_delegators :task_registry, :tasks, :containers

    private

    attr_reader :aws_client_config, :cluster_name

    def load_agents
      container_instance_arns = ecs_client.list_container_instances(cluster: cluster_name)
                                   .container_instance_arns
      return [] if container_instance_arns.empty?

      ecs_instances_by_id = ecs_client.describe_container_instances(
        cluster:             cluster_name,
        container_instances: container_instance_arns,
      ).container_instances.group_by(&:ec2_instance_id)

      ec2_instance_reservations = ec2_client.describe_instances(instance_ids: ecs_instances_by_id.keys)
                                            .reservations

      ec2_instance_reservations.map(&:instances).flatten.map.with_index do |instance, index|
        Agent.new(
          index:                  index + 1,
          instance_id:            instance[:instance_id],
          public_ip:              instance[:public_ip_address],
          private_ip:             instance[:private_ip_address],
          availability_zone:      instance.dig(:placement, :availability_zone),
          container_instance_arn: ecs_instances_by_id[instance[:instance_id]].first.container_instance_arn,
          task_registry:          task_registry,
        )
      end
    end

    def agents_by_container_instance_arn
      @agents_by_container_instance_arn ||= agents.group_by(&:container_instance_arn)
    end

    def task_registry
      @task_registry ||= TaskRegistry.new(
        ecs_client:     ecs_client,
        cluster_name:   cluster_name,
        agent_registry: self,
      )
    end

    def ec2_client
      @ec2_client ||= Aws::EC2::Client.new(aws_client_config)
    end

    def ecs_client
      @ecs_client ||= Aws::ECS::Client.new(aws_client_config)
    end
  end
end
