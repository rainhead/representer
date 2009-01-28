module PresenterHelper
  # Create a new presenter instance for the given model instance
  # with the given arguments.
  #
  # Presenters are usually of class Presenters::<ModelClassName>. Presenters for
  # enumerables are named after the class of their first member, e.g.:
  #
  #   presenter_for([photo1, photo2]).is_a?(Presenters::PhotoSet)  #=> true
  #
  # The context should be either a controller or another presenter instance.
  #
  def presenter_for(model, context = self)
    return model if model.is_a? Presenters::Base
    presenter_class = presenter_class_for(model).new(model, context)
  end
  
  # Like presenter_for, but returns an array of presenters rather than a Presenters::Set.
  def presenter_for_each(models, context = self)
    models.map { |model| presenter_for model, context }
  end
  
  private
  
  # Returns the default presenter class for the given model instance.
  #
  # Default class name is:
  # Presenters::<ModelClassName>
  #
  # Override this method if you'd like to change the _default_
  # model-to-presenter class mapping.
  #
  def presenter_class_for(clazz, suffix = nil)
    if clazz.is_a? Enumerable
      target = clazz.first.is_a?(Presenters::Base) ? clazz.first.model : clazz.first
      return presenter_class_for(target, "Set")
    end
    clazz = clazz.class unless clazz.is_a? Class
    begin
      "Presenters::#{clazz}#{suffix}".constantize
    rescue NameError => e
      clazz = clazz.superclass
      retry if clazz and not (clazz.name['::']) # Nested classes break Rails' automagical loading, XXX fix later.
      raise e
    rescue Exception => e
      raise "Exception while finding presenter class Presenters::#{clazz}#{suffix}. Exception was: " + e.to_s
    end
  end
end
