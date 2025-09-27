# frozen_string_literal: true

class TenantsController < ApplicationController
  def index
    # Only admins can list all tenants
    authorize Tenant
    @tenants = policy_scope(Tenant)
  end

  def show
    authorize Current.tenant
    # Renders app/views/tenants/show.html.erb
  end
end
