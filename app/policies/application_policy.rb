# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    user.present?
  end

  def show?
    index?
  end

  def create?
    user_has_tenant_role?([ :editor, :admin, :owner ])
  end

  def new?
    create?
  end

  def update?
    create?
  end

  def edit?
    update?
  end

  def destroy?
    user_has_tenant_role?([ :admin, :owner ])
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if user&.admin?
        scope.all
      elsif Current.tenant.present?
        scope.where(tenant_id: Current.tenant.id)
      else
        scope.none
      end
    end

    private

    attr_reader :user, :scope
  end

  private

  def user_has_tenant_role?(role_names)
    return false unless user.present?
    return true if user.admin?
    return false unless Current.tenant.present?

    role_names.any? { |role| user.has_role?(role, Current.tenant) }
  end

  def user_is_admin?
    user&.admin?
  end

  def user_has_tenant_access?
    return false unless user.present?
    return true if user.admin?
    return false unless Current.tenant.present?

    user.can_access_tenant?(Current.tenant)
  end
end
