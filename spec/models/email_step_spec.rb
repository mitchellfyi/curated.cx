# frozen_string_literal: true

# == Schema Information
#
# Table name: email_steps
#
#  id                :bigint           not null, primary key
#  body_html         :text             not null
#  body_text         :text
#  delay_seconds     :integer          default(0), not null
#  position          :integer          default(0), not null
#  subject           :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  email_sequence_id :bigint           not null
#
# Indexes
#
#  index_email_steps_on_email_sequence_id               (email_sequence_id)
#  index_email_steps_on_email_sequence_id_and_position  (email_sequence_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (email_sequence_id => email_sequences.id)
#
require "rails_helper"

RSpec.describe EmailStep, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:email_sequence) { create(:email_sequence, site: site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "associations" do
    it { is_expected.to belong_to(:email_sequence) }
    it { is_expected.to have_many(:sequence_emails).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:email_step, email_sequence: email_sequence) }

    it { is_expected.to validate_presence_of(:subject) }
    it { is_expected.to validate_presence_of(:body_html) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_presence_of(:delay_seconds) }

    it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:delay_seconds).is_greater_than_or_equal_to(0) }

    it "allows position of 0" do
      step = build(:email_step, email_sequence: email_sequence, position: 0)
      expect(step).to be_valid
    end

    it "does not allow negative position" do
      step = build(:email_step, email_sequence: email_sequence, position: -1)
      expect(step).not_to be_valid
    end

    it "allows delay_seconds of 0" do
      step = build(:email_step, email_sequence: email_sequence, delay_seconds: 0)
      expect(step).to be_valid
    end

    it "does not allow negative delay_seconds" do
      step = build(:email_step, email_sequence: email_sequence, delay_seconds: -1)
      expect(step).not_to be_valid
    end
  end

  describe "scopes" do
    describe ".ordered" do
      let!(:step2) { create(:email_step, email_sequence: email_sequence, position: 2) }
      let!(:step0) { create(:email_step, email_sequence: email_sequence, position: 0) }
      let!(:step1) { create(:email_step, email_sequence: email_sequence, position: 1) }

      it "orders by position ascending" do
        ordered = described_class.ordered

        expect(ordered.first).to eq(step0)
        expect(ordered.second).to eq(step1)
        expect(ordered.third).to eq(step2)
      end
    end
  end

  describe "#delay_duration" do
    it "returns delay as ActiveSupport::Duration for 0 seconds" do
      step = build(:email_step, email_sequence: email_sequence, delay_seconds: 0)

      expect(step.delay_duration).to eq(0.seconds)
    end

    it "returns delay as ActiveSupport::Duration for 1 day" do
      step = build(:email_step, email_sequence: email_sequence, delay_seconds: 86_400)

      expect(step.delay_duration).to eq(1.day)
    end

    it "returns delay as ActiveSupport::Duration for 3 days" do
      step = build(:email_step, email_sequence: email_sequence, delay_seconds: 259_200)

      expect(step.delay_duration).to eq(3.days)
    end
  end

  describe "factory" do
    it "creates a valid email step" do
      step = build(:email_step, email_sequence: email_sequence)
      expect(step).to be_valid
    end

    it "creates a valid step with :one_day_delay trait" do
      step = build(:email_step, :one_day_delay, email_sequence: email_sequence)
      expect(step).to be_valid
      expect(step.delay_seconds).to eq(86_400)
    end

    it "creates a valid step with :three_day_delay trait" do
      step = build(:email_step, :three_day_delay, email_sequence: email_sequence)
      expect(step).to be_valid
      expect(step.delay_seconds).to eq(259_200)
    end

    it "creates a valid step with :one_week_delay trait" do
      step = build(:email_step, :one_week_delay, email_sequence: email_sequence)
      expect(step).to be_valid
      expect(step.delay_seconds).to eq(604_800)
    end
  end
end
