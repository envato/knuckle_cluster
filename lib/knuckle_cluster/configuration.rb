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

    profile_inheritance = profile_hierarchy(
      child_profile_name: profile,
      data: data,
      profile_inheritance: [profile]
    )

    #Starting at the very lowest profile, build an options hash
    output = {}
    profile_inheritance.each do |prof|
      output.merge!(data[prof] || {})
    end

    output.delete('profile')

    keys_to_symbols(output)
  end

  private

  def self.profile_hierarchy(child_profile_name:, data:, profile_inheritance:)
    child_profile = data[child_profile_name]
    if child_profile.nil?
      return profile_inheritance
    end

    parent_profile = child_profile['profile']
    if parent_profile.nil? || profile_inheritance.include?(parent_profile)
      return profile_inheritance
    end

    profile_hierarchy(
      child_profile_name: parent_profile,
      data: data,
      profile_inheritance: profile_inheritance.insert(0, parent_profile)
    )
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