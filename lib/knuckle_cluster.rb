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
      agent_data.each do |agent|
        agent[:tasks] = task_data.select{|task|
          task[:container_instance_arn] == agent[:container_instance_arn]
        }
      end

      if auto
        conn_idx = 0
      else
        puts "\nListing Agents"
        tp agent_data, :index, :instance_id, :ip, :az, tasks: {display_method: ->(u){u[:tasks].map{|x| x[:definition]}.uniq.join(", ")}, width: 999}
        puts "\nConnect to which agent?"
        conn_idx = STDIN.gets.strip.to_i - 1
      end

      command = generate_connection_string(ip: agent_data[conn_idx][:ip], subcommand: command)
      system(command)
    end

    def connect_to_containers(command: 'bash', auto: false)
      task_data

      if auto
        conn_idx = 0
      else
        puts "\nListing Containers"
        tp task_data, :index, {container_name: {width: 999}}, {task_name: {width: 999}}, instance: {display_method: ->(u) {u[:agent][:instance_id]}}
        puts "\nConnect to which container?"
        conn_idx = STDIN.gets.strip.to_i - 1
      end

      task = task_data[conn_idx]
      subcommand = "#{'sudo ' if sudo}docker exec -it \\`#{'sudo ' if sudo}docker ps \| grep #{task[:task_name]} \| grep #{task[:container_name]} \| awk \'{print \\$1}\'\\` #{command}"
      command = generate_connection_string(ip: task[:agent][:ip], subcommand: subcommand)
      system(command)
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

    def aws_client_config
      @aws_client_config ||= { region: region }.tap do |config|
        if aws_vault_profile
          access_key_id, secret_access_key, session_token = aws_vault_credentials
          config[:access_key_id] = access_key_id
          config[:secret_access_key] = secret_access_key
          config[:session_token] = session_token
        end
      end
    end

    def aws_vault_credentials
      environment = `aws-vault exec #{aws_vault_profile} -- env | grep AWS_`
      vars = environment.split.map { |pair| pair.split('=') }.group_by(&:first)
      access_key_id = vars['AWS_ACCESS_KEY_ID']&.first&.last
      secret_access_key = vars['AWS_SECRET_ACCESS_KEY']&.first&.last
      session_token = vars['AWS_SESSION_TOKEN']&.first&.last
      [access_key_id, secret_access_key, session_token]
    end

    def generate_connection_string(ip:, subcommand: nil)
      command = "ssh #{ip} -l#{ssh_username}"
      command += " -i #{rsa_key_location}" if rsa_key_location
      command += " -o ProxyCommand='ssh -qxT #{bastion} nc #{ip} 22'" if bastion
      command += " -t \"#{subcommand}\"" if subcommand
      command
    end

    def task_data
      @task_data ||= [].tap do |data|
        task_arns = ecs.list_tasks({cluster: cluster_name}).task_arns
        task_ids  = task_arns.map{|x| x[/.*\/(.*)/,1]}
        return [] if task_ids.empty?
        tasks = ecs.describe_tasks({tasks: task_ids, cluster: cluster_name}).tasks
        tasks.each do |task|
          task_name = task.task_definition_arn[/.*\/(.*):\d/,1]
          task.containers.each do |container|
            tmp = {}
            tmp[:index]                  = data.length + 1 #ugh
            tmp[:arn]                    = task.task_arn
            tmp[:container_instance_arn] = task.container_instance_arn
            tmp[:agent]                  = agent_data.select{|x| x[:container_instance_arn] == task.container_instance_arn}.first
            tmp[:definition]             = task.task_definition_arn[/.*\/(.*):.*/,1]
            tmp[:task_name]              = task_name
            tmp[:container_name]         = container[:name]
            data << tmp
          end
        end
      end
    end

    def agent_data
      @agent_data ||= (
        container_instances = ecs.list_container_instances(cluster: cluster_name).container_instance_arns
        return [] if container_instances.empty?

        ec2_instance_data = {}.tap do |data|
          ecs.describe_container_instances(
          cluster: cluster_name,
          container_instances: container_instances).container_instances.each do |ci|
            data[ci.ec2_instance_id] = ci.container_instance_arn
          end
        end

        instance_data = ec2.describe_instances(instance_ids: ec2_instance_data.keys).to_h

        [].tap do |agents|
          instance_data[:reservations].each do |res|
            res[:instances].each do |instance|
              container_instance_arn = ec2_instance_data[instance[:instance_id]]
              tmp = {}
              tmp[:index]       = agents.length + 1 #ugh
              tmp[:instance_id] = instance[:instance_id]
              tmp[:ip]          = bastion ? instance[:private_ip_address] : instance[:public_ip_address]
              tmp[:az]          = instance[:placement][:availability_zone]
              tmp[:container_instance_arn] = container_instance_arn
              agents << tmp
            end
          end
        end
      )
    end
  end

end
