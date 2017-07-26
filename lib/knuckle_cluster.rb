require "knuckle_cluster/version"
require "knuckle_cluster/configuration"

require 'aws-sdk'
require 'table_print'

module KnuckleCluster
  class << self
    def new(
        cluster_name:,
        region: 'us-east-1',
        bastion: nil,
        rsa_key_location: nil,
        ssh_username: 'ec2-user',
        sudo: false,
        aws_vault_profile: nil)
      @cluster_name      = cluster_name
      @region            = region
      @bastion           = bastion
      @rsa_key_location  = rsa_key_location
      @ssh_username      = ssh_username
      @sudo              = sudo
      @aws_vault_profile = aws_vault_profile
      self
    end

    def connect_to_agents(command: nil, auto: false)
      agent = select_agent(auto: auto)
      run_command_in_agent(agent: agent, command: command)
    end

    def connect_to_containers(command: 'bash', auto: false)
      task = select_container(auto: auto)
      run_command_in_container(task: task, command: command)
    end

    def connect_to_container(name:, command: 'bash')
      task = find_container(name: name)
      run_command_in_container(task: task, command: command)
    end

    def container_logs(name:)
      task = find_container(name: name)
      subcommand = "#{'sudo ' if sudo}docker logs -f \\`#{'sudo ' if sudo}docker ps \| grep #{task[:task_name]} \| grep #{task[:container_name]} \| awk \'{print \\$1}\'\\`"
      run_command_in_agent(agent: task[:agent], command: subcommand)
    end

    def reload!
      @ecs = @ec2 = @tasks = nil
    end

    private

    attr_reader :cluster_name, :region, :bastion, :rsa_key_location, :ssh_username, :sudo, :aws_vault_profile

    def ecs
      @ecs ||= Aws::ECS::Client.new(aws_client_config)
    end

    def ec2
      @ec2 ||= Aws::EC2::Client.new(aws_client_config)
    end

    def select_agent(auto:)
      if auto
        cluster_agents_with_tasks.first
      else
        agents = cluster_agents_with_tasks
        puts "\nListing Agents"
        tp agents, :index, :instance_id, :ip, :az, tasks: {display_method: ->(u){u[:tasks].map{|x| x[:definition]}.uniq.join(", ")}, width: 999}
        puts "\nConnect to which agent?"
        agents[STDIN.gets.strip.to_i - 1]
      end
    end

    def select_container(auto:)
      if auto
        task_containers.first
      else
        containers = task_containers
        puts "\nListing Containers"
        tp containers, :index, {container_name: {width: 999}}, {task_name: {width: 999}}, instance: {display_method: ->(u) {u[:agent][:instance_id]}}
        puts "\nConnect to which container?"
        containers[STDIN.gets.strip.to_i - 1]
      end
    end

    def find_container(name:)
      matching = task_containers.select { |task| task[:container_name].include?(name) }

      if matching.empty?
        puts "No container with a name matching '#{name}' was found"
        Process.exit
      end

      unique_names = matching.map { |task| task[:container_name] }.uniq

      if unique_names.uniq.count > 1
        puts "Containers with the following names were found, please be more specific:"
        puts unique_names
        Process.exit
      end

      # If there are multiple containers with the same name, choose any one
      matching.first
    end

    def run_command_in_container(task:, command:)
      subcommand = "#{'sudo ' if sudo}docker exec -it \\`#{'sudo ' if sudo}docker ps \| grep #{task[:task_name]} \| grep #{task[:container_name]} \| awk \'{print \\$1}\'\\` #{command}"
      run_command_in_agent(agent: task[:agent], command: subcommand)
    end

    def run_command_in_agent(agent:, command:)
      command = generate_connection_string(ip: agent[:ip], subcommand: command)
      system(command)
    end

    def aws_client_config
      @aws_client_config ||= { region: region }.tap do |config|
        config.merge!(aws_vault_credentials) if aws_vault_profile
      end
    end

    def aws_vault_credentials
      environment = `aws-vault exec #{aws_vault_profile} -- env | grep AWS_`
      vars = environment.split.map { |pair| pair.split('=') }.group_by(&:first)
      {}.tap do |credentials|
        %i{access_key_id secret_access_key session_token}.map do |var_name|
          credentials[var_name] = vars["AWS_#{var_name.upcase}"]&.first&.last
        end
      end
    end

    def generate_connection_string(ip:, subcommand: nil)
      command = "ssh #{ip} -l#{ssh_username}"
      command += " -i #{rsa_key_location}" if rsa_key_location
      command += " -o ProxyCommand='ssh -qxT #{bastion} nc #{ip} 22'" if bastion
      command += " -t \"#{subcommand}\"" if subcommand
      command
    end

    def task_containers
      @task_containers ||= begin
        task_arns = ecs.list_tasks(cluster: cluster_name).task_arns
        task_ids  = task_arns.map { |x| x[/.*\/(.*)/,1] }
        return [] if task_ids.empty?

        ecs.describe_tasks(tasks: task_ids, cluster: cluster_name).tasks.map do |task|
          task.containers.map do |container|
            {
              arn:                    task.task_arn,
              container_instance_arn: task.container_instance_arn,
              agent:                  cluster_agents.find { |x| x[:container_instance_arn] == task.container_instance_arn },
              definition:             task.task_definition_arn[/.*\/(.*):.*/,1],
              task_name:              task.task_definition_arn[/.*\/(.*):\d/,1],
              container_name:         container.name,
            }
          end
        end.flatten.map.with_index do |container, index|
          container.merge(index: index + 1)
        end
      end
    end

    def cluster_agents
      @cluster_agents ||= begin
        container_instance_arns = ecs.list_container_instances(cluster: cluster_name)
                                     .container_instance_arns
        return [] if container_instance_arns.empty?

        ecs_instances_by_id = ecs.describe_container_instances(
          cluster:             cluster_name,
          container_instances: container_instance_arns,
        ).container_instances.group_by(&:ec2_instance_id)

        ec2_instance_reservations = ec2.describe_instances(instance_ids: ecs_instances_by_id.keys)
                                       .reservations

        ec2_instance_reservations.map(&:instances).flatten.map.with_index do |instance, index|
          {
            index:                  index + 1,
            instance_id:            instance[:instance_id],
            ip:                     bastion ? instance[:private_ip_address] : instance[:public_ip_address],
            az:                     instance[:placement][:availability_zone],
            container_instance_arn: ecs_instances_by_id[instance[:instance_id]].first.container_instance_arn,
          }
        end
      end
    end

    def cluster_agents_with_tasks
      @cluster_agents_with_tasks ||= cluster_agents.map do |agent|
        tasks = task_containers.select do |task|
          task[:container_instance_arn] == agent[:container_instance_arn]
        end
        agent.merge(tasks: tasks)
      end
    end
  end
end
