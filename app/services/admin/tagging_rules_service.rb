# frozen_string_literal: true

module Admin
  class TaggingRulesService
    def initialize(tenant)
      @tenant = tenant
    end

    def all_rules
      base_scope.includes(:taxonomy).by_priority
    end

    def rules_for_taxonomy(taxonomy)
      base_scope.where(taxonomy: taxonomy).by_priority
    end

    def find_rule(id)
      TaggingRule.includes(:tenant, :taxonomy).find(id)
    end

    private

    def base_scope
      target_tenant = @tenant || Current.tenant

      scope = TaggingRule.without_site_scope.where(tenant: target_tenant)
      active_site = Current.site || target_tenant&.sites&.first
      scope = scope.where(site: active_site) if active_site
      scope
    end
  end
end
