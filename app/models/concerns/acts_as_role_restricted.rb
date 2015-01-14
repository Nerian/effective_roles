# ActsAsRoleRestricted
#
# This model implements the
# https://github.com/ryanb/cancan/wiki/Role-Based-Authorization
# multi role based authorization based on the roles_mask field
#
# Mark your model with 'acts_as_role_restricted'
#
# and create the migration
#
# structure do
#    roles_mask              :integer, :default => 0
# end
#

module ActsAsRoleRestricted
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_role_restricted(*options)
      @acts_as_role_restricted_opts = options || []
      include ::ActsAsRoleRestricted
    end
  end

  included do
    validates :roles_mask, :numericality => true, :allow_nil => true
  end

  module ClassMethods
    # Call with for_role(:admin) or for_role(@user.roles) or for_role([:admin, :member]) or for_role(:admin, :member, ...)

    # Returns all records which have been assigned any of the the given roles
    def with_role(*roles)
      where(with_role_sql(roles))
    end

    # Returns all records which have been assigned any of the given roles, as well as any record with no role assigned
    def for_role(*roles)
      sql = with_role_sql(roles) || ''
      sql += ' OR ' if sql.present?
      sql += "(#{self.table_name}.roles_mask = 0) OR (#{self.table_name}.roles_mask IS NULL)"
      where(sql)
    end

    def with_role_sql(*roles)
      roles = roles.flatten.compact
      roles = roles.first.try(:roles) if roles.length == 1 and roles.first.respond_to?(:roles)

      roles = (roles.map { |role| role.to_sym } & EffectiveRoles.roles)
      roles.map { |role| "(#{self.table_name}.roles_mask & %d > 0)" % 2**EffectiveRoles.roles.index(role) }.join(' OR ')
    end

    def without_role(*roles)
      roles = roles.flatten.compact
      roles = roles.first.try(:roles) if roles.length == 1 and roles.first.respond_to?(:roles)

      roles = (roles.map { |role| role.to_sym } & EffectiveRoles.roles)

      where(roles.map { |role| "NOT(#{self.table_name}.roles_mask & %d > 0)" % 2**EffectiveRoles.roles.index(role) }.join(' OR '))
    end
  end

  def roles=(roles)
    self.roles_mask = (roles.map(&:to_sym) & EffectiveRoles.roles).map { |r| 2**EffectiveRoles.roles.index(r) }.sum
  end

  def roles
    EffectiveRoles.roles.reject { |r| ((roles_mask || 0) & 2**EffectiveRoles.roles.index(r)).zero? }
  end

  # if user.is? :admin
  def is?(role)
    roles.include?(role.try(:to_sym))
  end

  def roles_match_with?(obj)
    if !obj.respond_to?(:is_role_restricted?) || !obj.is_role_restricted?
      true
    else
      (roles & obj.roles).any?
    end
  end

  def is_role_restricted?
    (roles_mask || 0) > 0
  end

  # Does self have permission to view obj?
  def roles_permit?(obj)
    if obj.respond_to?(:is_role_restricted?)
      obj.is_role_restricted? == false || (roles & obj.roles).any?
    elsif Integer(obj) > 0
      obj_roles = EffectiveRoles.roles_for_roles_mask(obj)
      (roles & obj_roles).any?
    else
      raise 'unsupported object passed to roles_permit?(obj).  Expecting an acts_as_role_restricted object or a roles_mask integer'
    end
  end

end

