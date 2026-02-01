# frozen_string_literal: true

# == Schema Information
#
# Table name: votes
#
#  id           :bigint           not null, primary key
#  value        :integer          default(1), not null
#  votable_type :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  site_id      :bigint           not null
#  user_id      :bigint           not null
#  votable_id   :bigint           not null
#
# Indexes
#
#  index_votes_on_site_id  (site_id)
#  index_votes_on_user_id  (user_id)
#  index_votes_on_votable  (votable_type,votable_id)
#  index_votes_uniqueness  (site_id,user_id,votable_type,votable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :vote do
    association :user
    value { 1 }

    # Backward compatibility: allow content_item: as alias for votable:
    transient do
      content_item { nil }
    end

    # Use lazy evaluation so votable isn't created when content_item is passed
    votable { content_item || association(:content_item) }
    site { votable.site }

    trait :downvote do
      value { -1 }
    end

    trait :for_note do
      association :votable, factory: :note
    end
  end
end
