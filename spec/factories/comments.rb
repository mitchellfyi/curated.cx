# frozen_string_literal: true

# == Schema Information
#
# Table name: comments
#
#  id               :bigint           not null, primary key
#  body             :text             not null
#  commentable_type :string           not null
#  edited_at        :datetime
#  hidden_at        :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  commentable_id   :bigint           not null
#  hidden_by_id     :bigint
#  parent_id        :bigint
#  site_id          :bigint           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_comments_on_commentable             (commentable_type,commentable_id)
#  index_comments_on_commentable_and_parent  (commentable_type,commentable_id,parent_id)
#  index_comments_on_hidden_at               (hidden_at)
#  index_comments_on_parent_id               (parent_id)
#  index_comments_on_site_and_user           (site_id,user_id)
#  index_comments_on_site_id                 (site_id)
#  index_comments_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (hidden_by_id => users.id)
#  fk_rails_...  (parent_id => comments.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :comment do
    association :user
    body { Faker::Lorem.paragraph }
    parent { nil }

    # Backward compatibility: allow content_item: as alias for commentable:
    transient do
      content_item { nil }
    end

    # Use lazy evaluation so commentable isn't created when content_item is passed
    commentable { content_item || association(:content_item) }
    site { commentable.site }

    trait :reply do
      transient do
        parent_comment { nil }
      end

      parent { parent_comment || association(:comment, commentable: commentable, site: site) }
    end

    trait :edited do
      edited_at { 1.hour.ago }
    end

    trait :long do
      body { Faker::Lorem.paragraphs(number: 10).join("\n\n") }
    end

    trait :for_note do
      association :commentable, factory: :note
    end
  end
end
