class KnuckleCluster::Configuration
  require 'yaml'
  DEFAULT_PROFILE_FILE = File.join(ENV['HOME'],'.ssh/knuckle_cluster').freeze

  def self.load_parameters(profile:, profile_file: nil)

    profile_config_data = load_profile_config_file(profile_file)
    validate_profile_config_file(profile, profile_config_data)
    profile_inheritance = discover_profile_inheritance(profile,profile_config_data)
    cluster_config_options = build_cluster_config_options(profile_inheritance, profile_config_data)
    puts(cluster_config_options)
    keys_to_symbols(cluster_config_options)
  end

  private

  def self.load_profile_config_file(profile_file)
    profile_file ||= DEFAULT_PROFILE_FILE
    raise "File #{profile_file} not found" unless File.exists?(profile_file)
    return YAML.load_file(profile_file)
  end

  def self.validate_profile_config_file(profile, profile_config_data)
    unless profile_config_data.keys.include?(profile)
      raise "Config file does not include profile for #{profile}"
    end
  end

  def self.discover_profile_inheritance(profile, profile_config_data)
    #Figure out all the profiles to inherit from
    tmp_data = profile_config_data[profile]
    profile_inheritance = [profile]
    while(tmp_data && tmp_data.keys.include?('profile'))
      profile_name = tmp_data['profile']
      break if profile_inheritance.include? profile_name
      profile_inheritance << profile_name
      tmp_data = profile_config_data[profile_name]
    end
    return profile_inheritance
  end

  def self.build_cluster_config_options(profile_inheritance, profile_config_data)
    #Starting at the very lowest profile, build an options hash
    output = {}
    profile_inheritance.reverse.each do |prof|
      output.merge!(profile_config_data[prof] || {})
    end
     output.delete('profile')
    return output
  end

  def self.keys_to_symbols(data)
    #Implemented here - beats including activesupport
    return data unless Hash === data
    ret = {}
    data.each do |k,v|
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