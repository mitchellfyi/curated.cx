# frozen_string_literal: true

# == Schema Information
#
# Table name: purchases
#
#  id                         :bigint           not null, primary key
#  amount_cents               :integer          default(0), not null
#  email                      :string           not null
#  purchased_at               :datetime         not null
#  source                     :integer          default("checkout"), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  digital_product_id         :bigint           not null
#  site_id                    :bigint           not null
#  stripe_checkout_session_id :string
#  stripe_payment_intent_id   :string
#  user_id                    :bigint
#
# Indexes
#
#  index_purchases_on_digital_product_id                        (digital_product_id)
#  index_purchases_on_site_id                                   (site_id)
#  index_purchases_on_site_id_and_digital_product_id_and_email  (site_id,digital_product_id,email)
#  index_purchases_on_site_id_and_purchased_at                  (site_id,purchased_at)
#  index_purchases_on_stripe_checkout_session_id                (stripe_checkout_session_id) UNIQUE WHERE (stripe_checkout_session_id IS NOT NULL)
#  index_purchases_on_stripe_payment_intent_id                  (stripe_payment_intent_id) UNIQUE WHERE (stripe_payment_intent_id IS NOT NULL)
#  index_purchases_on_user_id                                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (digital_product_id => digital_products.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class Purchase < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :digital_product
  belongs_to :user, optional: true
  has_many :download_tokens, dependent: :destroy

  # Enums
  enum :source, { checkout: 0, referral: 1, admin_grant: 2 }, default: :checkout

  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :purchased_at, presence: true
  validates :stripe_checkout_session_id, uniqueness: true, allow_nil: true
  validates :stripe_payment_intent_id, uniqueness: true, allow_nil: true

  # Callbacks
  before_validation :set_purchased_at, on: :create, if: -> { purchased_at.blank? }

  # Scopes
  scope :recent, -> { order(purchased_at: :desc) }
  scope :by_product, ->(product) { where(digital_product: product) }
  scope :for_email, ->(email) { where(email: email.downcase) }

  # Instance methods
  def free?
    amount_cents.zero?
  end

  def amount_dollars
    amount_cents / 100.0
  end

  def formatted_amount
    free? ? "Free" : "$#{'%.2f' % amount_dollars}"
  end

  private

  def set_purchased_at
    self.purchased_at = Time.current
  end
end
