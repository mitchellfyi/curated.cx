# frozen_string_literal: true

# == Schema Information
#
# Table name: digital_products
#
#  id             :bigint           not null, primary key
#  description    :text
#  download_count :integer          default(0), not null
#  metadata       :jsonb            not null
#  price_cents    :integer          default(0), not null
#  slug           :string           not null
#  status         :integer          default("draft"), not null
#  title          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#
# Indexes
#
#  index_digital_products_on_site_id             (site_id)
#  index_digital_products_on_site_id_and_slug    (site_id,slug) UNIQUE
#  index_digital_products_on_site_id_and_status  (site_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
FactoryBot.define do
  factory :digital_product do
    association :site
    sequence(:title) { |n| "Digital Product #{n}" }
    description { Faker::Lorem.paragraph }
    price_cents { rand(499..9999) }
    status { :draft }
    metadata { {} }

    # Automatically generate slug from title
    slug { nil }

    trait :draft do
      status { :draft }
    end

    trait :published do
      status { :published }
    end

    trait :archived do
      status { :archived }
    end

    trait :free do
      price_cents { 0 }
    end

    trait :with_file do
      after(:build) do |product|
        product.file.attach(
          io: StringIO.new("Sample PDF content"),
          filename: "product.pdf",
          content_type: "application/pdf"
        )
      end
    end

    trait :with_downloads do
      download_count { rand(1..100) }
    end

    trait :expensive do
      price_cents { 9999 }
    end

    trait :cheap do
      price_cents { 499 }
    end
  end
end
