require 'knuckle_cluster/agent'

require 'forwardable'

module KnuckleCluster
  class AsgInstanceRegistry
    extend Forwardable

    def initialize(aws_client_config:, asg_name:)
      @aws_client_config = aws_client_config
      @asg_name   = asg_name
    end

    def agents
      @agents ||= load_agents
    end

    def output_agents
      tp agents,
        :index,
        :instance_id,
        # :public_ip,
        :private_ip,
        :availability_zone
    end

    private

    attr_reader :aws_client_config, :asg_name

    def load_agents
      auto_scaling_instances = autoscaling_client.describe_auto_scaling_groups(auto_scaling_group_names: [@asg_name]).to_h

      instance_ids = auto_scaling_instances[:auto_scaling_groups][0][:instances].map{|instance| instance[:instance_id]}

      instance_reservations = ec2_client.describe_instances(instance_ids: instance_ids).reservations

      instance_reservations.map(&:instances).flatten.map.with_index do |instance, index|
        Agent.new(
          index:                  index + 1,
          instance_id:            instance[:instance_id],
          public_ip:              instance[:public_ip_address],
          private_ip:             instance[:private_ip_address],
          availability_zone:      instance.dig(:placement, :availability_zone),
        )
      end
    end

    def ec2_client
      @ec2_client ||= Aws::EC2::Client.new(aws_client_config)
    end

    def autoscaling_client
      @autoscaling_client ||= Aws::AutoScaling::Client.new(aws_client_config)
    end

  end
end
