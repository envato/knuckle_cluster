class KnuckleCluster::Configuration
  require 'yaml'

  DEFAULT_PROFILE_FILE = File.join(ENV['HOME'],'.ssh/knuckle_cluster').freeze

  def self.load_parameters(profile:, profile_file: nil)
    profile_data = load_profile_from_file(profile, profile_file)
    profile_inheritance_chain = find_profile_inheritance_chain(profile, profile_data)
    resolve_inheritance(profile_inheritance_chain, profile_data)
  end

  private

  def self.load_profile_from_file(profile, profile_file)
    profile_file ||= DEFAULT_PROFILE_FILE
    raise "File #{profile_file} not found" unless File.exists?(profile_file)

    data = YAML.load_file(profile_file)

    unless data.keys.include?(profile)
      raise "Config file does not include profile for #{profile}"
    end
    return data
  end

  def self.find_profile_inheritance_chain(starting_profile, profiles)
    return nil unless profiles.keys.include?(starting_profile)
    return [
              starting_profile, 
              find_profile_inheritance_chain(
                profiles[starting_profile]['profile'], profiles
              )
           ].flatten
  end

  def self.resolve_inheritance(profile_inheritance_chain, profile_data)
    output = {}
    profile_inheritance_chain.reverse.each do |prof|
      output.merge!(profile_data[prof] || {})
    end
    cleanup_hash(output)
  end

  def self.cleanup_hash(output)
    output.delete('profile')
    keys_to_symbols(output)
  end


  def self.keys_to_symbols(hash)
    hash.keys.each do |key|
      hash[key.to_sym] = hash.delete(key)
    end
    hash
  end
end
