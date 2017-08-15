require_relative 'profile'

class ProfileBuilder

  def initialize(profiles_hash, root_profile_name)
    @root_profile_name = root_profile_name
    @profiles_hash = profiles_hash
  end

  def build
    @profiles = build_profiles
    attach_parents
    find_profile(@root_profile_name)
  end

  private

  def build_profiles
    @profiles_hash.map {|key, value| Profile.new(key.to_s, value)}
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