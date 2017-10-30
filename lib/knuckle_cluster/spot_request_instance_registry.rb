require 'knuckle_cluster/agent'

require 'forwardable'

module KnuckleCluster
  class SpotRequestInstanceRegistry
    extend Forwardable

    def initialize(aws_client_config:, spot_request_id:)
      @aws_client_config = aws_client_config
      @spot_request_id   = spot_request_id
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

    attr_reader :aws_client_config, :spot_request_id

    def load_agents
      spot_fleet_instances = ec2_client.describe_spot_fleet_instances(spot_fleet_request_id: spot_request_id)
      instance_ids = spot_fleet_instances.active_instances.map(&:instance_id)

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
      @ec2_client ||= ::Aws::EC2::Client.new(aws_client_config)
    end

  end
end
