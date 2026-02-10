# frozen_string_literal: true

module Admin
  class CategoriesService
    def initialize(tenant)
      @tenant = tenant
    end

    def all_categories
      target_tenant = @tenant || Current.tenant

      scope = Category.without_site_scope.includes(:entries).where(tenant: target_tenant)
      active_site = Current.site || target_tenant&.sites&.first
      scope = scope.where(site: active_site) if active_site
      scope = scope.where(id: Current.tenant.categories.select(:id)) if Current.tenant
      scope.order(:name)
    end

    def find_category(id)
      Category.includes(:tenant).find(id)
    end
  end
end
