module KnuckleCluster
  class Agent
    def initialize(
      index:,
      instance_id:,
      public_ip:,
      private_ip:,
      availability_zone:,
      container_instance_arn: nil,
      task_registry: nil
    )
      @index = index
      @instance_id = instance_id
      @public_ip = public_ip
      @private_ip = private_ip
      @availability_zone = availability_zone
      @container_instance_arn = container_instance_arn
      @task_registry = task_registry
    end

    attr_reader :index, :instance_id, :public_ip, :private_ip,
                :availability_zone, :container_instance_arn, :task_registry

    def tasks
      task_registry.where(container_instance_arn: container_instance_arn)
    end
  end
end
