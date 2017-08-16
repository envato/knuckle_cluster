require_relative 'profile'
require_relative 'profiles_validator'

class ProfileBuilder

  def initialize(profiles_file, root_profile_name)
    @root_profile_name = root_profile_name
    @profiles_file = profiles_file
  end

  def build
    ProfilesValidator.new(@profiles_file, @root_profile_name).validate
    build_profiles
    attach_parents
    find_profile(@root_profile_name)
  end

  private

  def build_profiles
    @profiles = @profiles_file.map {|name, file_parameters| Profile.new(name.to_s, file_parameters)}
  end

  def attach_parents
    @profiles.each {|profile| profile.parent = find_parent(profile)}
  end

  def find_parent(profile)
    profile_name = profile.parent_name
    find_profile(profile_name)
  end

  def find_profile(profile_name)
    @profiles.find {|raw_profile| raw_profile.name == profile_name}
  end

end