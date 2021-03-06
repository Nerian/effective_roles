module EffectiveRolesHelper
  # For use in formtastic forms
  def effective_roles_fields(form, user = nil, options = {})
    raise ArgumentError.new('EffectiveRoles config.role_descriptions must be a Hash.  The Array syntax is deprecated.') unless EffectiveRoles.role_descriptions.kind_of?(Hash)

    roles = EffectiveRoles.assignable_roles_for(user, form.object)
    descriptions = EffectiveRoles.role_descriptions[form.object.class.name] || EffectiveRoles.role_descriptions || {}

    opts = {:f => form, :roles => roles, :descriptions => descriptions}.merge(options)

    render :partial => 'effective/roles/fields', :locals => opts
  end

  def effective_roles_summary(obj, options = {}) # User or a Post, any acts_as_roleable
    raise 'expected an acts_as_roleable object' unless obj.respond_to?(:roles)

    descriptions = EffectiveRoles.role_descriptions[obj.class.name] || EffectiveRoles.role_descriptions || {}
    opts = {:obj => obj, :roles => obj.roles, :descriptions => descriptions}.merge(options)

    render :partial => 'effective/roles/summary', :locals => opts
  end

  # Output a table of permissions for each role based on current permissions

  # effective_roles_summary_table(roles: [:admin, :superadmin], only: [Post, Event])
  # effective_roles_summary_table(except: [Post, User])
  # effective_roles_summary_table(aditionally: [Report::PostReport, User, {clinic_report: :export}])
  def effective_roles_summary_table(opts = {})
    raise 'Expected argument to be a Hash' unless opts.kind_of?(Hash)

    roles = Array(opts[:roles]).presence
    roles ||= [:public, :signed_in] + EffectiveRoles.roles

    if opts[:only].present?
      klasses = Array(opts[:only])
      render partial: '/effective/roles/summary_table', locals: {klasses: klasses, roles: roles}
      return
    end

    # Figure out all klasses (ActiveRecord objects)
    Rails.application.eager_load!
    tables = ActiveRecord::Base.connection.tables - ['schema_migrations', 'delayed_jobs']

    klasses = ActiveRecord::Base.descendants.map do |model|
      model if (model.respond_to?(:table_name) && tables.include?(model.table_name))
    end.compact

    if opts[:except]
      klasses = klasses - Array(opts[:except])
    end

    if opts[:plus]
      klasses = klasses + Array(opts[:plus])
    end

    klasses = klasses.sort do |a, b|
      a = a.respond_to?(:name) ? a.name : a.to_s
      b = b.respond_to?(:name) ? b.name : b.to_s

      a_namespaces = a.split('::')
      b_namespaces = b.split('::')

      if a_namespaces.length != b_namespaces.length
        a_namespaces.length <=> b_namespaces.length
      else
        a <=> b
      end
    end

    if opts[:additionally]
      klasses = klasses + Array(opts[:additionally])
    end

    render partial: '/effective/roles/summary_table', locals: {klasses: klasses, roles: roles}
  end

  def effective_roles_authorization_badge(level)
    case level
    when :manage
      content_tag(:span, 'Full', class: 'label label-primary')
    when :update
      content_tag(:span, 'Edit', class: 'label label-success')
    when :update_own
      content_tag(:span, 'Edit Own', class: 'label label-info')
    when :create
      content_tag(:span, 'Create', class: 'label label-success')
    when :show
      content_tag(:span, 'Read only', class: 'label label-warning')
    when :index
      content_tag(:span, 'Read only', class: 'label label-warning')
    when :destroy
      content_tag(:span, 'Delete only', class: 'label label-warning')
    when :none
      content_tag(:span, 'No Access', class: 'label label-danger')
    when :yes
      content_tag(:span, 'Yes', class: 'label label-primary')
    when :no
      content_tag(:span, 'No', class: 'label label-danger')
    when :unknown
      content_tag(:span, 'Unknown', class: 'label')
    else
      content_tag(:span, level.to_s.titleize, class: 'label label-info')
    end
  end

  def effective_roles_authorization_label(klass)
    # Custom permissions
    return "#{klass.keys.first} #{klass.values.first}" if klass.kind_of?(Hash) && klass.length == 1

    klass = klass.keys.first if klass.kind_of?(Hash)
    label = (klass.respond_to?(:name) ? klass.name : klass.to_s)

    ['Effective::Datatables::'].each do |replace|
      label = label.sub(replace, '')
    end

    label
  end

end
