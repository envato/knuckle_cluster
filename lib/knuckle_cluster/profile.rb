class Profile

  PARENT_KEY = :profile

  attr_accessor :parent
  attr_reader :name, :parent_name

  def initialize(name, file_parameters)
    @name = name
    @parent_name = file_parameters[PARENT_KEY]
    @parameters = create_parameters(file_parameters)
  end

  def has_parent?
    !parent_name.nil?
  end

  def parameters
    merge_parent_parameters
  end

  protected

  def merge_parent_parameters(child_parameters={})
    merged_parameters = @parameters.clone.merge(child_parameters)
    return merged_parameters unless has_parent?
    parent.merge_parent_parameters(merged_parameters)
  end

  private

  def create_parameters(file_parameters)
    parameters = file_parameters.clone
    parameters.delete(PARENT_KEY)
    parameters
  end

end