require 'yaml'
require_relative '../../lib/core_extenstions/hash'

class ProfilesFile

  Hash.include CoreExtensions::Hash

  DEFAULT_PROFILE_FILE_NAME = File.join(ENV['HOME'], '.ssh/knuckle_cluster').freeze

  def initialize(profiles_file_name)
    @profiles_file_name = profiles_file_name || DEFAULT_PROFILE_FILE_NAME
  end

  def load
    raise "File #{@profiles_file_name} not found" unless File.exists?(@profiles_file_name)
    YAML.load_file(@profiles_file_name).symbolize_keys
  end

end