require_relative 'profiles_file'
require_relative 'profile_builder'
require_relative 'profiles_validator'

class KnuckleCluster::Configuration

  def self.load_parameters(root_profile_name:, profiles_file_name: nil)
    profiles_hash = ProfilesFile.new(profiles_file_name).load
    ProfilesValidator.new(profiles_hash, root_profile_name).validate
    profile = ProfileBuilder.new(profiles_hash, root_profile_name).build
    profile.parameters
  end

end