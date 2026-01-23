# == Schema Information
#
# Table name: listings
#
#  id            :bigint           not null, primary key
#  ai_summaries  :jsonb            not null
#  ai_tags       :jsonb            not null
#  body_html     :text
#  body_text     :text
#  description   :text
#  domain        :string
#  image_url     :text
#  metadata      :jsonb            not null
#  published_at  :datetime
#  site_name     :string
#  title         :string
#  url_canonical :text             not null
#  url_raw       :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  category_id   :bigint           not null
#  site_id       :bigint           not null
#  source_id     :bigint
#  tenant_id     :bigint           not null
#
# Indexes
#
#  index_listings_on_category_id                (category_id)
#  index_listings_on_category_published         (category_id,published_at)
#  index_listings_on_domain                     (domain)
#  index_listings_on_published_at               (published_at)
#  index_listings_on_site_id                    (site_id)
#  index_listings_on_site_id_and_url_canonical  (site_id,url_canonical) UNIQUE
#  index_listings_on_source_id                  (source_id)
#  index_listings_on_tenant_and_url_canonical   (tenant_id,url_canonical) UNIQUE
#  index_listings_on_tenant_domain_published    (tenant_id,domain,published_at)
#  index_listings_on_tenant_id                  (tenant_id)
#  index_listings_on_tenant_id_and_category_id  (tenant_id,category_id)
#  index_listings_on_tenant_id_and_source_id    (tenant_id,source_id)
#  index_listings_on_tenant_published_created   (tenant_id,published_at,created_at)
#  index_listings_on_tenant_title               (tenant_id,title)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :listing do
    tenant
    site { tenant&.sites&.first || association(:site, tenant: tenant) }
    category { tenant&.categories&.first || association(:category, tenant: tenant, site: site) }
    sequence(:url_raw) { |n| "https://example#{n}.com" }
    sequence(:title) { |n| "Article Title #{n}" }
    description { Faker::Lorem.paragraph }
    image_url { Faker::Internet.url(host: 'images.example.com', path: '/image.jpg') }
    site_name { Faker::Company.name }
    published_at { Faker::Time.between(from: 1.month.ago, to: Time.current) }
    body_html { Faker::Lorem.paragraphs(number: 3).map { |p| "<p>#{p}</p>" }.join }
    body_text { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    ai_summaries { {} }
    ai_tags { {} }
    metadata { {} }

    after(:build) do |listing|
      listing.created_at ||= 2.days.ago

      if listing.category.nil? && listing.tenant
        listing.site ||= listing.tenant.sites.first || create(:site, tenant: listing.tenant)
        listing.category = listing.tenant.categories.find_by(site: listing.site) || create(:category, tenant: listing.tenant, site: listing.site)
      elsif listing.category && listing.site.nil?
        listing.site = listing.category.site
      end
    end

    trait :with_ai_content do
      ai_summaries do
        {
          short: Faker::Lorem.sentence,
          medium: Faker::Lorem.sentences(number: 2).join(' '),
          long: Faker::Lorem.paragraph
        }
      end
      ai_tags do
        {
          keywords: Faker::Lorem.words(number: 5),
          confidence: 0.85
        }
      end
    end

    trait :news_article do
      association :category, :news
      url_raw { "https://#{Faker::Internet.domain_name}/#{Faker::Lorem.words(number: 3).join('-')}" }
      title { Faker::Lorem.sentence.chomp('.') }
      site_name { Faker::Company.name + ' News' }
      published_at { Faker::Time.between(from: 1.week.ago, to: Time.current) }
    end

    trait :app_listing do
      association :category, :apps
      url_raw { "https://#{Faker::Internet.domain_name}" }
      title { Faker::App.name }
      description { Faker::Lorem.sentence }
      site_name { title }
    end

    trait :service_listing do
      association :category, :services
      url_raw { "https://#{Faker::Internet.domain_name}" }
      title { Faker::Company.name }
      description { Faker::Company.catch_phrase }
      site_name { title }
    end

    trait :published do
      published_at { 1.day.ago }
    end

    trait :unpublished do
      published_at { nil }
    end

    # Monetisation traits

    trait :tool do
      listing_type { :tool }
    end

    trait :job do
      listing_type { :job }
      company { Faker::Company.name }
      location { "#{Faker::Address.city}, #{Faker::Address.country}" }
      salary_range { "$#{rand(50..150)}k - $#{rand(150..300)}k" }
      apply_url { Faker::Internet.url(host: "jobs.example.com") }
      expires_at { 30.days.from_now }
    end

    trait :service do
      listing_type { :service }
    end

    trait :featured do
      featured_from { 1.day.ago }
      featured_until { 30.days.from_now }
      association :featured_by, factory: :user
    end

    trait :featured_expired do
      featured_from { 30.days.ago }
      featured_until { 1.day.ago }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :with_affiliate do
      affiliate_url_template { "https://affiliate.example.com?url={url}&ref=curated" }
      affiliate_attribution { { source: "curated", medium: "affiliate" } }
    end

    trait :paid do
      paid { true }
      payment_reference { "pay_#{SecureRandom.hex(8)}" }
    end
  end
end
