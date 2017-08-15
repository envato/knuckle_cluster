class Profile

  PARENT_KEY = :profile

  attr_accessor :parent
  attr_reader :name, :parent_name, :data

  def initialize(name, raw_profile_record)
    @name = name
    @parent_name = raw_profile_record[PARENT_KEY]
    @data = create_profile_data(raw_profile_record)
  end

  def has_parent?
    !parent_name.nil?
  end

  def parameters
    merge_parent_data
  end

  protected

  def merge_parent_data(child_data={})
    merged_data = @data.clone.merge(child_data)
    return merged_data unless has_parent?
    parent.merge_parent_data(merged_data)
  end

  private

  def create_profile_data(raw_profile_record)
    data_clone = raw_profile_record.clone
    data_clone.delete(PARENT_KEY)
    data_clone
  end

end