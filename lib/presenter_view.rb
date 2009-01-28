# This class wraps ActionView for use by Presenters
#
class PresenterView < ActionView::Base
  def initialize(view_paths, controller, helper_module)
    metaclass.send :include, helper_module
    super view_paths, {}, controller
  end
  
  # Hack ActionView so we can give it access to the controller without it being retarded.
  # This appears to be the easiest way...
  def _pick_partial_template(partial_path)
    if partial_path.include?('/')
      path = File.join(File.dirname(partial_path), "_#{File.basename(partial_path)}")
    else
      path = "_#{partial_path}"
    end

    _pick_template(path)
  end
end