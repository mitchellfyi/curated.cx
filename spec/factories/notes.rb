# frozen_string_literal: true

# == Schema Information
#
# Table name: notes
#
#  id             :bigint           not null, primary key
#  body           :text             not null
#  comments_count :integer          default(0), not null
#  hidden_at      :datetime
#  link_preview   :jsonb
#  published_at   :datetime
#  reposts_count  :integer          default(0), not null
#  upvotes_count  :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  hidden_by_id   :bigint
#  repost_of_id   :bigint
#  site_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_notes_on_hidden_at                 (hidden_at)
#  index_notes_on_hidden_by_id              (hidden_by_id)
#  index_notes_on_repost_of_id              (repost_of_id)
#  index_notes_on_site_id                   (site_id)
#  index_notes_on_site_id_and_published_at  (site_id,published_at DESC)
#  index_notes_on_user_id                   (user_id)
#  index_notes_on_user_id_and_created_at    (user_id,created_at DESC)
#
# Foreign Keys
#
#  fk_rails_...  (hidden_by_id => users.id)
#  fk_rails_...  (repost_of_id => notes.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :note do
    association :user
    association :site
    body { Faker::Lorem.paragraph(sentence_count: 2) }
    published_at { nil }

    trait :published do
      published_at { Time.current }
    end

    trait :draft do
      published_at { nil }
    end

    trait :hidden do
      hidden_at { Time.current }
      association :hidden_by, factory: :user
    end

    trait :with_link do
      body { "Check this out: https://example.com/article" }
    end

    trait :with_link_preview do
      link_preview do
        {
          "url" => "https://example.com/article",
          "title" => "Example Article",
          "description" => "This is an example article description",
          "image" => "https://example.com/image.jpg",
          "site_name" => "Example.com"
        }
      end
    end

    trait :repost do
      transient do
        original_note { nil }
      end

      repost_of { original_note || association(:note, :published, site: site) }
    end
  end
end
