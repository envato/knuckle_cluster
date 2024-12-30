require 'knuckle_cluster/asg_instance_registry'
require 'knuckle_cluster/ecs_agent_registry'
require 'knuckle_cluster/spot_request_instance_registry'
require "knuckle_cluster/scp"
require "knuckle_cluster/version"
require "knuckle_cluster/configuration"

require 'aws-sdk-core'
require 'aws-sdk-ec2'
require 'aws-sdk-ecs'
require 'aws-sdk-autoscaling'

require 'forwardable'
require 'table_print'

module KnuckleCluster
  class << self
    extend Forwardable

    include Scp

    def new(
        cluster_name: nil,
        spot_request_id: nil,
        asg_name: nil,
        region: 'us-east-1',
        bastion: nil,
        rsa_key_location: nil,
        ssh_username: 'ec2-user',
        sudo: false,
        aws_vault_profile: nil,
        shortcuts: {},
        tunnels: {},
        hide: {})
      @cluster_name      = cluster_name
      @spot_request_id   = spot_request_id
      @asg_name          = asg_name
      @region            = region
      @bastion           = bastion
      @rsa_key_location  = rsa_key_location
      @ssh_username      = ssh_username
      @sudo              = sudo
      @aws_vault_profile = aws_vault_profile
      @shortcuts         = shortcuts
      @tunnels           = tunnels
      @hide              = hide

      if @cluster_name.nil? && @spot_request_id.nil? && @asg_name.nil?
        raise "Must specify either cluster_name, spot_request_id or asg name"
      end
      self
    end

    def connect_to_agents(command: nil, auto: false)
      agent = select_agent(auto: auto)
      run_command_in_agent(agent: agent, command: command)
    end

    def connect_to_containers(command: 'bash', auto: false)
      container = select_container(auto: auto)
      run_command_in_container(container: container, command: command)
    end

    def connect_to_container(name:, command: 'bash')
      if shortcut = shortcuts[name.to_sym]
        name = shortcut[:container]
        new_command = shortcut[:command]
        new_command += " #{command}" unless command == 'bash'
        command = new_command
      end

      container = find_container(name: name)
      run_command_in_container(container: container, command: command)
    end

    def container_logs(name:)
      container = find_container(name: name)
      subcommand = "#{'sudo ' if sudo}docker logs -f \\`#{get_container_id_command(container.name)}\\`"
      run_command_in_agent(agent: container.task.agent, command: subcommand)
    end

    def open_tunnel(name:)
      if tunnel = tunnels[name.to_sym]
        agent = select_agent(auto: true)
        open_tunnel_via_agent(**tunnel.merge(agent: agent))
      else
        puts "ERROR: A tunnel configuration was not found for '#{name}'"
      end
    end

    private

    attr_reader :cluster_name, :spot_request_id, :asg_name,
                :region, :bastion, :rsa_key_location, :ssh_username,
                :sudo, :aws_vault_profile, :shortcuts, :tunnels

    def select_agent(auto: false)
      return agents.first if auto

      puts "\nListing Agents"

      output_agents

      puts "\nConnect to which agent? (INDEX)"
      agents[STDIN.gets.strip.to_i - 1]
    end

    def select_container(auto: false)
      return containers.first if auto

      puts "\nListing Containers"

      tp tasks,
         { task: { display_method: :name, width: 999 } },
         { agent: { display_method: 'agent.instance_id' } },
         { index: { display_method: 'containers.index' } },
         { container: { display_method: 'containers.name', width: 999 } }

      puts "\nConnect to which container? (INDEX)"
      containers[STDIN.gets.strip.to_i - 1]
    end

    def find_container(name:)
      matching = containers.select { |container| container.name.include?(name) }
      puts "\nAttempting to find a container matching '#{name}'..."

      if matching.empty?
        puts "No container with a name matching '#{name}' was found"
        Process.exit
      end

      unique_names = matching.map(&:name).uniq

      if unique_names.uniq.count > 1
        puts "Containers with the following names were found, please be more specific:"
        puts unique_names
        Process.exit
      end

      # If there are multiple containers with the same name, choose any one
      container = matching.first
      puts "Found container #{container.name} on #{container.task.agent.instance_id}\n\n"
      container
    end

    def run_command_in_container(container:, command:)
      subcommand = "#{'sudo ' if sudo}docker exec -it \\`#{get_container_id_command(container.name)}\\` #{command}"
      run_command_in_agent(agent: container.task.agent, command: subcommand)
    end

    def get_container_id_command(container_name)
      "#{'sudo ' if sudo}docker ps --filter 'label=com.amazonaws.ecs.container-name=#{container_name}' | tail -1 | awk '{print \\$1}'"
    end

    def run_command_in_agent(agent:, command:)
      command = generate_connection_string(agent: agent, subcommand: command)
      system(command)
    end

    def open_tunnel_via_agent(agent:, local_port:, remote_host:, remote_port:)
      command = generate_connection_string(
        agent: agent,
        port_forward: [local_port, remote_host, remote_port].join(':'),
        subcommand: <<~SCRIPT
          echo ""
          echo "localhost:#{local_port} is now tunneled to #{remote_host}:#{remote_port}"
          echo "Press Enter to close the tunnel once you are finished."
          read
        SCRIPT
      )
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

    def generate_connection_string(agent:, subcommand: nil, port_forward: nil)
      ip = bastion ? agent.private_ip : agent.public_ip
      command = "ssh #{ip} -l#{ssh_username}"
      command += " -i #{rsa_key_location}" if rsa_key_location
      if bastion.is_a? String
        command += " -o ProxyCommand='ssh -qxT #{bastion} nc #{ip} 22'"
      elsif bastion.is_a? Hash
        command += " -o Proxycommand='ssh -qxt #{bastion[:host]} -l#{bastion[:username]} -i #{bastion[:rsa_key_location]} nc #{ip} 22'"
      end
      command += " -L #{port_forward}" if port_forward
      command += " -t \"#{subcommand}\"" if subcommand
      command
    end

    def agent_registry
      @agent_registry ||= (
        if @cluster_name
          EcsAgentRegistry.new(
            aws_client_config: aws_client_config,
            cluster_name:      cluster_name,
            hide:              @hide,
          )
        elsif @spot_request_id
          SpotRequestInstanceRegistry.new(
            aws_client_config: aws_client_config,
            spot_request_id:   spot_request_id,
          )
        elsif @asg_name
          AsgInstanceRegistry.new(
            aws_client_config: aws_client_config,
            asg_name:          asg_name,
          )
        end
      )
    end

    def_delegators :agent_registry, :agents, :tasks, :containers, :output_agents
  end
end
