class KnuckleCluster::Configuration
  require 'yaml'
  DEFAULT_PROFILE_FILE = File.join(ENV['HOME'],'.ssh/knuckle_cluster').freeze

  def self.load_parameters(profile_name:, profile_file: nil)
    profile_data = load_profile_data(
      profile_name: profile_name,
      profile_file: profile_file,
    )

    profile_inheritance = generate_profile_inheritance_list(
      profile_data: profile_data,
      profile_name: profile_name,
    )

    generate_config(
      profile_data:        profile_data,
      profile_inheritance: profile_inheritance
    )
  end

  private

  def self.load_profile_data(profile_name:, profile_file: DEFAULT_PROFILE_FILE)
    raise "File #{profile_file} not found" unless File.exists?(profile_file)

    profile_data = YAML.load_file(profile_file)

    unless profile_data.keys.include?(profile_name)
      raise "Config file does not include profile for #{profile_name}"
    end
    profile_data
  end

  def self.generate_profile_inheritance_list(profile_data:, profile_name:)
    profile_inheritance  = [profile_name]
    current_profile_data = profile_data[profile_name]

    while(current_profile_data.keys.include?('profile'))
      next_profile_name = current_profile_data['profile']
      break if profile_inheritance.include? next_profile_name #prevent infinite loops

      profile_inheritance << next_profile_name

      if profile_data[next_profile_name]
        current_profile_data = profile_data[next_profile_name]
      else
        raise "Cannot find profile data with name #{next_profile_name}"
      end
    end

    profile_inheritance.reverse
  end

  def self.generate_config(profile_data:, profile_inheritance:)
    output = {}
    profile_inheritance.each do |prof|
      output.merge!(profile_data[prof] || {})
    end

    output.delete('profile')

    keys_to_symbols(output)
  end

  def self.keys_to_symbols(profile_data)
    #Implemented here - beats including activesupport
    return profile_data unless Hash === profile_data
    ret = {}
    profile_data.each do |k,v|
      if Hash === v
        #Look, doesnt need to be recursive but WHY NOT?!?
        ret[k.to_sym] = keys_to_symbols(v)
      else
        ret[k.to_sym] = v
      end
    end
    ret
  end
end