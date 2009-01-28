# Base Module for Presenters.
#

module Presenters
  # Base class from which all presenters inherit.
  #
  class Base
    extend ActiveSupport::Memoizable
    
    attr_accessor :view_instance, :output_buffer
    attr_reader :model, :controller, :context
    class_inheritable_accessor :master_helper_module
    class_inheritable_array :view_paths
    
    # Include some useful modules.
    #     What exactly should be included here? We get along with the modules for request
    #     forgery protection and record identifier a.t.m..
    #     Anything else needed?                                               -nd 20080701-
    # 
    # ActionController::Helpers is needed by ActionController::RequestForgeryProtection
    # and its .helper gets overwritten later by the .helper here. Therefor it has to be
    # included before the definition of .helper.
    # 
    include ActionController::Helpers
    include ActionController::RequestForgeryProtection    # for forms
    include ActionController::RecordIdentifier            # dom_id & co.
    delegate :session, :request,
             :allow_forgery_protection, :protect_against_forgery?, :request_forgery_protection_token,
             :to => :controller

    # Default view directory
    self.view_paths = ['app/views/presenters']
    
    class << self
      # Sub-classes will have a path derived from their name appended to the view_paths used by ActionView.
      # E.g.,
      #   Presenters::B < Presenters::A < Presenters::Base
      # will have as view_paths:
      #   ['app/views/presenters', 'app/views/presenters/a', 'app/views/presenters/b']
      #
      def inherited(subclass)
        super
        subclass.push_presenter_path
      end
      
      # A module that will collect all helpers that need to be made available to the view.
      #
      master_helper_module = Module.new
      
      # Make a helper available to the current presenter, its subclasses and the presenter's views.
      # Same as in Controller::Base.
      #
      def helper(helper)
        include helper
        master_helper_module.send(:include, helper)
      end
      
      # Define a reader for a model attribute. Acts as a filtered delegation to the model. 
      #
      # You may specify a :filter_through option that is either a symbol or an array of symbols. The return value
      # from the model will be filtered through the functions (arity 1) and then passed back to the receiver. 
      #
      # Example: 
      #
      #   model_reader :foobar                                        # same as delegate :foobar, :to => :model
      #   model_reader :foobar, :filter_through => :h                 # html escape foobar 
      #   model_reader :foobar, :filter_through => [:textilize, :h]   # first textilize, then html escape
      #
      def model_reader(*args)
        args = args.dup
        opts = args.pop if args.last.kind_of?(Hash)
      
        fields = args.flatten
        filters = opts.nil? ? [] : [*(opts[:filter_through])].reverse
      
        fields.each do |field|
          reader = "def #{field}; 
                    @model_reader_cache ||= {}
                    @model_reader_cache[:#{field}] ||= #{filters.join('(').strip}(model.#{field})#{')' * (filters.size - 1) unless filters.empty?}; 
                    end"
          class_eval(reader)
        end
      end
      
      # Delegates method calls to the controller.
      #
      # Example: 
      #   controller_method :current_user
      #
      # In the presenter:
      #   self.current_user
      # will call
      #   controller.current_user
      #
      def controller_method(*methods)
        methods.each do |method|
          delegate method, :to => :controller
        end
      end
    
      # Returns the path from the presenter_view_paths to the actual templates.
      # e.g. "app/views/presenters/models/book"
      #
      # If the class is named
      #   Presenters::Models::Book
      # this method will yield
      #   app/views/presenters/models/book
      #
      def push_presenter_path(name=nil)
        name ||= self.name
        path = File.join(RAILS_ROOT, 'app', 'views', name.underscore)
        view_paths.unshift path
      end
      
      def push_module_presenter_path(module_name)
        class_path = view_paths.pop
        push_presenter_path "presenters/#{module_name}"
        view_paths.unshift class_path
      end
    end # class << self
    
    # Create a presenter. To create a presenter, you need to have a model (to present) and a context.
    # The context is usually a view or a controller.
    # 
    def initialize(model, context)
      @model = model
      @controller = case context
      when ActionController::Base: context
      when Presenters::Base:       context.controller
      else                         raise "Invalid context #{context} for presenter. Must be a controller or a presenter."
      end
      debugger if @controller.nil?
      @context = context
    end
    
    def method_missing(method_name, *args, &block)
      case method_name.to_s
      when /render_(.+)/: render $1
      when /id_for_(.+)/
        self.class.send(:define_method, method_name) { generate_html_id $1 }
        self.class.memoize method_name
        send method_name
      else
        super
      end
    end
    
    # Render several views, sequentially:
    #
    #   multirender :header, :overview, :viewer, :footer
    #
    def multirender(views)
      views.collect { |view| send "render_#{view}" }.join("\n")
    end
    
    private
    
    # All rendering is done via method_missing, by calling "render_#{view_name}". This allows subclasses to
    # override a particular view without creating a template file.
    #
    def render(view_name)
      self.output_buffer ||= ''
      view_instance.render :partial => view_name, :locals => { :presenter => self }
    end
    
    def view_instance
      view_paths = self.class.view_paths.dup
      view_paths.concat controller.view_paths if controller.respond_to? :view_paths
      @view_instance = PresenterView.new view_paths, controller, master_helper_module
      # debugger
      return @view_instance
    end
  end
end
