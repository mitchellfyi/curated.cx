# frozen_string_literal: true

module Admin
  class DigitalProductsService
    def all_products
      DigitalProduct.includes(:site).recent
    end

    def find_product(id)
      DigitalProduct.find(id)
    end

    def create_product(attributes)
      product = DigitalProduct.new(attributes)
      product.site = Current.site
      product.save
      product
    end

    def update_product(product, attributes)
      product.update(attributes)
    end

    def destroy_product(product)
      product.destroy
    end

    def dashboard_stats
      site = Current.site

      {
        total_revenue: total_revenue(site),
        total_products: total_products_count(site),
        published_products: published_products_count(site),
        draft_products: draft_products_count(site),
        total_purchases: total_purchases_count(site),
        total_downloads: total_downloads_count(site),
        top_products: top_products(site)
      }
    end

    private

    def total_revenue(site)
      Purchase.where(site: site).sum(:amount_cents)
    end

    def total_products_count(site)
      DigitalProduct.where(site: site).count
    end

    def published_products_count(site)
      DigitalProduct.where(site: site).published.count
    end

    def draft_products_count(site)
      DigitalProduct.where(site: site).draft.count
    end

    def total_purchases_count(site)
      Purchase.where(site: site).count
    end

    def total_downloads_count(site)
      DigitalProduct.where(site: site).sum(:download_count)
    end

    def top_products(site, limit: 5)
      DigitalProduct.where(site: site)
                    .select("digital_products.*, COUNT(purchases.id) as purchases_count")
                    .left_joins(:purchases)
                    .group("digital_products.id")
                    .order("purchases_count DESC")
                    .limit(limit)
    end
  end
end
