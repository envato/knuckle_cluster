module KnuckleCluster
  module Scp
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
          source = source.split(':').last
          tmp_source_file = '~/tmp_kc.tmp'
          container_id = get_container_id_command(container.name)

          subcommand = "#{'sudo ' if sudo}docker cp \\`#{container_id}\\`:#{source} #{tmp_source_file}"
          run_command_in_agent(agent: agent, command: subcommand)

          scp_source = generate_agent_scp_string(tmp_source_file, agent)
          scp_with_agent(source: scp_source, agent: agent, destination: destination)

          subcommand = "#{'sudo ' if sudo} rm #{tmp_source_file}"
          run_command_in_agent(agent: agent, command: subcommand)

          puts "Done!"
        elsif destination.start_with?('container')
          #SCP TO container
          destination = destination.split(':').last
          tmp_destination_file = '~/tmp_kc.tmp'
          tmp_destination = generate_agent_scp_string(tmp_destination_file, agent)
          scp_with_agent(source: source, agent: agent, destination: tmp_destination)
          container_id = get_container_id_command(container.name)
          subcommand = "#{'sudo ' if sudo}docker cp #{tmp_destination_file} \\`#{container_id}\\`:#{destination} && rm #{tmp_destination_file}"
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
  end
end
