class KnuckleCluster::Configuration
  require 'yaml'
  DEFAULT_PROFILE_FILE = File.join(ENV['HOME'],'.ssh/knuckle_cluster').freeze

  def self.load_parameters(profile:, profile_file: nil)
    profile_file ||= DEFAULT_PROFILE_FILE
    raise "File #{profile_file} not found" unless File.exists?(profile_file)

    data = YAML.load_file(profile_file)

    unless data.keys.include?(profile)
      raise "Config file does not include profile for #{profile}"
    end

    profile_inheritance = profile_hierarchy(profile_name: profile, data: data)

    #Starting at the very lowest profile, build an options hash
    output = {}
    profile_inheritance.each do |prof|
      output.merge!(data[prof] || {})
    end

    output.delete('profile')

    keys_to_symbols(output)
  end

  private


  def self.profile_hierarchy(profile_name:, data:)
    #Figure out all the profiles to inherit from
    current_profile = data[profile_name]
    profile_inheritance = [profile_name]
    while(current_profile && current_profile.keys.include?('profile'))
      parent_profile_name = current_profile['profile']
      break if profile_inheritance.include? parent_profile_name
      profile_inheritance << parent_profile_name
      current_profile = data[parent_profile_name]
    end
    profile_inheritance.reverse
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