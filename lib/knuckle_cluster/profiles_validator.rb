class ProfilesValidator

  def initialize(profiles_file, root_profile_name)
    @profiles_file = profiles_file
    @root_profile_name = root_profile_name
  end

  def validate
    validate_root_profile
    validate_parent_profiles
  end

  private

  def validate_root_profile
    check_profile_exists(@root_profile_name)
  end

  def validate_parent_profiles
    parent_profile_names.each {|profile_name| check_profile_exists(profile_name)}
  end

  def check_profile_exists(profile_name)
    raise profile_error_message(profile_name) unless has_profile?(profile_name)
  end

  def profile_error_message(profile_name)
    "Config file does not include profile for #{profile_name}"
  end

  def has_profile?(profile_name)
    @profiles_file[:"#{profile_name}"]
  end

  def parent_profile_names
    @profiles_file.map {|_, profile| profile[:profile]}.compact
  end

end