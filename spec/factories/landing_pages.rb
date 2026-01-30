# frozen_string_literal: true

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
