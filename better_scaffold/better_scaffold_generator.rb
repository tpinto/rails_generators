class BetterScaffoldGenerator < Rails::Generator::Base
  attr_accessor :name, :attributes, :controller_actions, :admin_controller_actions
  
  @@chars_to_actions = {
    'i' => "index",
    'n' => ["new", "create"],
    's' => "show",
    'e' => ["edit", "update"],
    'd' => "destroy"
  }
  
  def initialize(runtime_args, runtime_options = {})
    super
    usage if @args.empty?
    
    @name = @args.first
    
    @controller_actions = []
    @admin_controller_actions = []
    @attributes = []

    @args[1..-1].each do |arg|
      if arg.include? ':'
        @attributes << Rails::Generator::GeneratedAttribute.new(*arg.split(":"))
      elsif arg =~ /controller\+(.*)/
        $1.split("").each do |action|
          @controller_actions << @@chars_to_actions[action]
        end
      elsif arg =~ /admin\+(.*)/
        $1.split("").each do |action|
          @admin_controller_actions << @@chars_to_actions[action]
        end
      end
    end

    @controller_actions.flatten!
    @controller_actions.uniq!
    @admin_controller_actions.flatten!
    @admin_controller_actions.uniq!
    @attributes.uniq!
    
    if @attributes.empty?
      options[:skip_model] = true # default to skipping model if no attributes passed
      if model_exists?
        model_columns_for_attributes.each do |column|
          @attributes << Rails::Generator::GeneratedAttribute.new(column.name.to_s, column.type.to_s)
        end
      else
        @attributes << Rails::Generator::GeneratedAttribute.new('name', 'string')
      end
    end
  end
  
  def manifest
    record do |m|
      unless options[:skip_model]
        m.directory "app/models"
        m.template "model.rb", "app/models/#{singular_name}.rb"
        unless options[:skip_migration]
          m.migration_template "migration.rb", "db/migrate", :migration_file_name => "create_#{plural_name}"
        end
      end
      
      if !options[:skip_controller] and controller_actions.any?
        m.directory "app/controllers"
        m.template "controller.rb", "app/controllers/#{plural_name}_controller.rb"
        
        m.directory "app/views/#{plural_name}"
        controller_actions.each do |action|
          if File.exist? source_path("views/#{action}.html.erb")
            m.template "views/#{action}.html.erb", "app/views/#{plural_name}/#{action}.html.erb"
          end
        end
      
        if form_partial?
          m.template "views/_form.html.erb", "app/views/#{plural_name}/_form.html.erb"
        end
      
        m.route_resources plural_name
      end
      
      if !options[:skip_admin] and admin_controller_actions.any?
        m.directory "app/controllers/admin"
        m.template "admin_controller.rb", "app/controllers/admin/#{plural_name}_controller.rb"
        
        m.directory "app/views/admin/#{plural_name}"
        admin_controller_actions.each do |action|
          if File.exist? source_path("views/admin/#{action}.html.erb")
            m.template "views/admin/#{action}.html.erb", "app/views/admin/#{plural_name}/#{action}.html.erb"
          end
        end
      
        if admin_form_partial?
          m.template "views/admin/_form.html.erb", "app/views/admin/#{plural_name}/_form.html.erb"
        end
      
        #m.route_namespaced_resources :admin, plural_name
      end
    end
  end
  
  def form_partial?
    actions? :new, :edit
  end
  
  def admin_form_partial?
    admin_actions? :new, :edit
  end
  
  def all_actions
    %w[index show new create edit update destroy]
  end
  
  def action?(name)
    controller_actions.include? name.to_s
  end
  
  def admin_action?(name)
    admin_controller_actions.include? name.to_s
  end
  
  def actions?(*names)
    names.all? { |n| action? n.to_s }
  end
  
  def admin_actions?(*names)
    names.all? { |n| admin_action? n.to_s }
  end
  
  def singular_name
    name.underscore
  end
  
  def plural_name
    name.underscore.pluralize
  end
  
  def class_name
    name.camelize
  end
  
  def plural_class_name
    plural_name.camelize
  end
  
  def controller_methods(dir_name)
    controller_actions.map do |action|
      read_template("#{dir_name}/#{action}.rb")
    end.join("  \n").strip
  end
  
  def admin_controller_methods(dir_name)
    admin_controller_actions.map do |action|
      read_template("#{dir_name}/admin/#{action}.rb")
    end.join("  \n").strip
  end
  
  def render_form
    if form_partial?
      "<%= render :partial => 'form' %>"
    else
      read_template("views/_form.html.erb")
    end
  end
  
  def admin_render_form
    if admin_form_partial?
      "<%= render :partial => 'form' %>"
    else
      read_template("views/admin/_form.html.erb")
    end
  end
  
  def items_path(suffix = 'path')
    if action? :index
      "#{plural_name}_#{suffix}"
    else
      "root_#{suffix}"
    end
  end
  
  def item_path(suffix = 'path')
    if action? :show
      "@#{singular_name}"
    else
      items_path(suffix)
    end
  end
  
  def model_columns_for_attributes
    class_name.constantize.columns.reject do |column|
      column.name.to_s =~ /^(id|created_at|updated_at)$/
    end
  end
  
protected

  #def route_namespaced_resources(namespace, *resources)
  #  resource_list = resources.map { |r| r.to_sym.inspect }.join(', ')
  #  sentinel = 'ActionController::Routing::Routes.draw do |map|'
  #  logger.route "#{namespace}.resources #{resource_list}"
  #  unless options[:pretend]
  #    gsub_file 'config/routes.rb', /(#{Regexp.escape(sentinel)})/mi do |match|
  #      "#{match}\n  map.namespace(:#{namespace}) do |#{namespace}|\n     #{namespace}.resources #{resource_list}\n  end\n"
  #    end
  #  end
  #end

  def add_options!(opt)
    opt.separator ''
    opt.separator 'Options:'
    opt.on("--skip-model", "Don't generate a model or migration file.") { |v| options[:skip_model] = v }
    opt.on("--skip-migration", "Don't generate migration file for model.") { |v| options[:skip_migration] = v }
    opt.on("--skip-timestamps", "Don't add timestamps to migration file.") { |v| options[:skip_timestamps] = v }
    opt.on("--skip-controller", "Don't generate controller, helper, or views.") { |v| options[:skip_controller] = v }
    opt.on("--skip-admin", "Don't generate the admin controller, helper, or views.") { |v| options[:skip_admin] = v }
  end
  
  # is there a better way to do this? Perhaps with const_defined?
  def model_exists?
    File.exist? destination_path("app/models/#{singular_name}.rb")
  end
  
  def read_template(relative_path)
    ERB.new(File.read(source_path(relative_path)), nil, '-').result(binding)
  end
  
  def banner
    <<-EOS
Creates a controller and optional model given the name, actions, and attributes.

USAGE: #{$0} #{spec.name} ModelName [controller_actions and model:attributes] [options]
EOS
  end
end