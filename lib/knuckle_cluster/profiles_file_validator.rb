class ProfilesFileValidator

  def initialize(profiles_file_name)
    @profiles_file_name = profiles_file_name
  end

  def validate
    raise "File #{@profiles_file_name} not found" unless File.exists?(@profiles_file_name)
  end

end