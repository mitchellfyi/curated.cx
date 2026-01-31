# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriber_taggings
#
#  id                     :bigint           not null, primary key
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  digest_subscription_id :bigint           not null
#  subscriber_tag_id      :bigint           not null
#
# Indexes
#
#  index_subscriber_taggings_on_digest_subscription_id  (digest_subscription_id)
#  index_subscriber_taggings_on_subscriber_tag_id       (subscriber_tag_id)
#  index_subscriber_taggings_uniqueness                 (digest_subscription_id,subscriber_tag_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (digest_subscription_id => digest_subscriptions.id)
#  fk_rails_...  (subscriber_tag_id => subscriber_tags.id)
#
class SubscriberTagging < ApplicationRecord
  # Associations
  belongs_to :digest_subscription
  belongs_to :subscriber_tag

  # Validations
  validates :subscriber_tag_id, uniqueness: { scope: :digest_subscription_id, message: "already assigned to this subscription" }
end
