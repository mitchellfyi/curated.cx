# frozen_string_literal: true

# == Schema Information
#
# Table name: landing_pages
#
#  id             :bigint           not null, primary key
#  content        :jsonb            not null
#  cta_text       :string
#  cta_url        :string
#  headline       :string
#  hero_image_url :string
#  published      :boolean          default(FALSE), not null
#  slug           :string           not null
#  subheadline    :text
#  title          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#  tenant_id      :bigint           not null
#
# Indexes
#
#  index_landing_pages_on_site_id                (site_id)
#  index_landing_pages_on_site_id_and_published  (site_id,published)
#  index_landing_pages_on_site_id_and_slug       (site_id,slug) UNIQUE
#  index_landing_pages_on_tenant_id              (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :landing_page do
    association :tenant, factory: [ :tenant, :enabled ]
    site { tenant.sites.first || association(:site, tenant: tenant) }
    sequence(:slug) { |n| "campaign-#{n}" }
    title { Faker::Marketing.buzzwords.titleize }
    headline { Faker::Lorem.sentence(word_count: 6) }
    subheadline { Faker::Lorem.paragraph(sentence_count: 2) }
    cta_text { "Get Started" }
    cta_url { "https://example.com/signup" }
    published { true }
    content { {} }

    trait :draft do
      published { false }
    end

    trait :with_hero_image do
      hero_image_url { "https://example.com/hero.jpg" }
    end

    trait :with_features do
      content do
        {
          "sections" => [
            {
              "type" => "features",
              "title" => "Why Choose Us",
              "subtitle" => "Here's what makes us different",
              "items" => [
                { "icon" => "🚀", "title" => "Fast", "description" => "Lightning fast performance" },
                { "icon" => "🔒", "title" => "Secure", "description" => "Enterprise-grade security" },
                { "icon" => "💪", "title" => "Powerful", "description" => "Full-featured solution" }
              ]
            }
          ]
        }
      end
    end

    trait :with_testimonials do
      content do
        {
          "sections" => [
            {
              "type" => "testimonials",
              "title" => "What Our Customers Say",
              "items" => [
                { "quote" => "This product changed everything!", "name" => "Jane Doe", "title" => "CEO, Acme Inc" },
                { "quote" => "Simply amazing experience.", "name" => "John Smith", "title" => "CTO, Tech Corp" }
              ]
            }
          ]
        }
      end
    end

    trait :with_faq do
      content do
        {
          "sections" => [
            {
              "type" => "faq",
              "title" => "Frequently Asked Questions",
              "items" => [
                { "question" => "How does it work?", "answer" => "It's simple - just sign up and get started!" },
                { "question" => "What's the pricing?", "answer" => "We offer flexible plans for all budgets." }
              ]
            }
          ]
        }
      end
    end

    trait :full_page do
      with_hero_image
      content do
        {
          "sections" => [
            {
              "type" => "features",
              "title" => "Features",
              "items" => [
                { "icon" => "⚡", "title" => "Speed", "description" => "Blazing fast" }
              ]
            },
            {
              "type" => "testimonials",
              "title" => "Testimonials",
              "items" => [
                { "quote" => "Great product!", "name" => "User" }
              ]
            },
            {
              "type" => "faq",
              "title" => "FAQ",
              "items" => [
                { "question" => "Question?", "answer" => "Answer." }
              ]
            }
          ],
          "theme" => "light"
        }
      end
    end
  end
end
