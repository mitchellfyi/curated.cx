# frozen_string_literal: true

module Admin
  class CategoriesService
    def initialize(tenant)
      @tenant = tenant
    end

    def all_categories
      Category.includes(:listings).order(:name)
    end

    def find_category(id)
      Category.find(id)
    end
  end
end
