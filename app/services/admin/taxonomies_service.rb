# frozen_string_literal: true

module Admin
  class TaxonomiesService
    def initialize(tenant)
      @tenant = tenant
    end

    def all_taxonomies
      base_scope.by_position
    end

    def root_taxonomies
      base_scope.roots.by_position
    end

    def find_taxonomy(id)
      Taxonomy.includes(:tenant, :parent, :children).find(id)
    end

    private

    def base_scope
      target_tenant = @tenant || Current.tenant

      scope = Taxonomy.without_site_scope.includes(:children, :tagging_rules).where(tenant: target_tenant)
      active_site = Current.site || target_tenant&.sites&.first
      scope = scope.where(site: active_site) if active_site
      scope
    end
  end
end
