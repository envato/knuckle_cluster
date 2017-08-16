require 'yaml'
require_relative '../../lib/core_extenstions/hash'
require_relative 'profiles_file_validator'

class ProfilesFile

  Hash.include CoreExtensions::Hash

  DEFAULT_PROFILE_FILE_NAME = File.join(ENV['HOME'], '.ssh/knuckle_cluster').freeze

  def initialize(profiles_file_name)
    @profiles_file_name = profiles_file_name || DEFAULT_PROFILE_FILE_NAME
  end

  def load
    ProfilesFileValidator.new(@profiles_file_name).validate
    YAML.load_file(@profiles_file_name).symbolize_keys
  end

end