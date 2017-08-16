require_relative 'profiles_file'
require_relative 'profile_builder'
require_relative 'profiles_validator'

class KnuckleCluster::Configuration

  def self.load_parameters(root_profile_name:, profiles_file_name: nil)
    profiles_file = ProfilesFile.new(profiles_file_name).load
    profile = ProfileBuilder.new(profiles_file, root_profile_name).build
    profile.parameters
  end

end