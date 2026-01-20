# frozen_string_literal: true

module Admin
  class CategoriesService
    def initialize(tenant)
      @tenant = tenant
    end

    def all_categories
      PerformanceOptimizer.load_categories_with_counts(@tenant.id)
                          .map { |data| data[:category] }
    end

    def find_category(id)
      Category.includes(:tenant).find(id)
    end
  end
end
