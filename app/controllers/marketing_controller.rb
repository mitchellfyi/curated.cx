# frozen_string_literal: true

class MarketingController < ApplicationController
  before_action :ensure_root_tenant
  skip_after_action :verify_authorized

  def pricing
    set_page_meta_tags(
      title: t("marketing.pricing.title"),
      description: t("marketing.pricing.description")
    )
  end

  def features
    set_page_meta_tags(
      title: t("marketing.features.title"),
      description: t("marketing.features.description")
    )
  end

  private

  def ensure_root_tenant
    redirect_to root_path unless Current.tenant&.root?
  end
end
