require 'knuckle_cluster/asg_instance_registry'
require 'knuckle_cluster/ecs_agent_registry'
require 'knuckle_cluster/spot_request_instance_registry'
require 'knuckle_cluster/scp'
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
        tunnels: {})
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

    def initiate_scp(source:, destination:)
      if source.start_with?('agent') || destination.start_with?('agent')
        agent = select_agent

        if source.start_with?('agent')
          source      = generate_agent_scp_string(source,      agent)
        elsif destination.start_with?('agent')
          destination = generate_agent_scp_string(destination, agent)
        end

        scp_with_agent(source: source, destination: destination, agent: agent)
      elsif source.start_with?('container') || destination.start_with?('container')
        container = select_container
        agent     = container.task.agent
        if source.start_with?('container')
          #This is SCP FROM container
          raise "SCP From container not yet implemented"
        elsif destination.start_with?('container')
          #SCP TO container
          destination = destination.split(':').last
          tmp_destination_file = '~/tmp_kc.tmp'
          tmp_destination = generate_agent_scp_string(tmp_destination_file, agent)
          scp_with_agent(source: source, agent: agent, destination: tmp_destination)
          container_id = get_container_id_command(container.name)
          subcommand = "#{'sudo ' if sudo}docker cp #{tmp_destination_file} \\`#{container_id}\\`:#{destination} && rm #{tmp_destination_file}"
          puts subcommand
          run_command_in_agent(agent: agent, command: subcommand)
          puts "Done!"
        end
      end
    end

    def generate_agent_scp_string(input, agent)
      split_input = input.split(':')
      location    = split_input.last
      target_ip = bastion ? agent.private_ip : agent.public_ip
      return "#{ssh_username}@#{target_ip}:#{location}"
    end

    def scp_with_agent(source:, destination:, agent: nil)
      command = generate_scp_connection_string(agent: agent)
      command += " #{source}"
      command += " #{destination}"
      system(command)
      puts "Done!"
    end

    def generate_scp_connection_string(agent:)
      ip = bastion ? agent.private_ip : agent.public_ip
      command = "scp"
      command += " -i #{rsa_key_location}" if rsa_key_location
      command += " -o ProxyCommand='ssh -qxT #{bastion} nc #{ip} 22'" if bastion
      command
    end

    def scp_to_container(source:, destination:)
      container = select_container
      agent     = container.task.agent
      tmp_destination_file = '~/tmp_kc.tmp'
      scp_to_agent(source: source, agent: agent, destination: tmp_destination_file)
      container_id = get_container_id_command(container.name)
      subcommand = "#{'sudo ' if sudo}docker cp #{tmp_destination_file} \\`#{container_id}\\`:#{destination} && rm #{tmp_destination_file}"
      run_command_in_agent(agent: agent, command: subcommand)
      puts "Done!"
    end

    def container_logs(name:)
      container = find_container(name: name)
      subcommand = "#{'sudo ' if sudo}docker logs -f \\`#{get_container_id_command(container.name)}\\`"
      run_command_in_agent(agent: container.task.agent, command: subcommand)
    end

    def open_tunnel(name:)
      if tunnel = tunnels[name.to_sym]
        agent = select_agent(auto: true)
        open_tunnel_via_agent(tunnel.merge(agent: agent))
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

      puts "\nConnect to which agent?"
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

      puts "\nConnect to which container?"
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
      command += " -o ProxyCommand='ssh -qxT #{bastion} nc #{ip} 22'" if bastion
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
