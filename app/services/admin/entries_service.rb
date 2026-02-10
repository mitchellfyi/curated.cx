# frozen_string_literal: true

module Admin
  class EntriesService
    def initialize(tenant)
      @tenant = tenant
    end

    def all_entries(kind: "directory", category_id: nil, limit: 50)
      target_tenant = @tenant || Current.tenant
      scope = Entry.without_site_scope.includes(:category)
      scope = scope.where(tenant: target_tenant) if target_tenant
      active_site = Current.site || target_tenant&.sites&.first
      scope = scope.where(site: active_site) if active_site
      scope = scope.directory_items if kind == "directory"
      scope = scope.feed_items if kind == "feed"
      scope = scope.where(category_id: category_id) if category_id.present?
      scope = scope.where.not(category_id: nil) if kind == "directory"
      scope.order(created_at: :desc).limit(limit)
    end

    def find_entry(id)
      Entry.includes(:category, :tenant).find(id)
    end

    def create_entry(attributes)
      Entry.new(attributes)
    end

    def update_entry(entry, attributes)
      entry.update(attributes)
    end

    def destroy_entry(entry)
      entry.destroy
    end
  end
end
