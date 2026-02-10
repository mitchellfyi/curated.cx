# frozen_string_literal: true

# == Schema Information
#
# Table name: submissions
#
#  id             :bigint           not null, primary key
#  description    :text
#  ip_address     :string
#  listing_type   :integer          default("tool"), not null
#  reviewed_at    :datetime
#  reviewer_notes :text
#  status         :integer          default("pending"), not null
#  title          :string           not null
#  url            :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  category_id    :bigint           not null
#  entry_id       :bigint
#  reviewed_by_id :bigint
#  site_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_submissions_on_category_id         (category_id)
#  index_submissions_on_entry_id            (entry_id)
#  index_submissions_on_reviewed_by_id      (reviewed_by_id)
#  index_submissions_on_site_id             (site_id)
#  index_submissions_on_site_id_and_status  (site_id,status)
#  index_submissions_on_status              (status)
#  index_submissions_on_user_id             (user_id)
#  index_submissions_on_user_id_and_status  (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (entry_id => entries.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe Submission, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:category) { create(:category, site: site, tenant: tenant) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:site) }
    it { is_expected.to belong_to(:category) }
    it { is_expected.to belong_to(:entry).optional }
    it { is_expected.to belong_to(:reviewer).class_name("User").optional }
  end

  describe "validations" do
    subject { build(:submission, site: site, category: category, user: user) }

    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(2000) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, approved: 1, rejected: 2) }
    it { is_expected.to define_enum_for(:listing_type).with_values(tool: 0, job: 1, service: 2) }
  end

  describe "scopes" do
    let!(:pending_submission) { create(:submission, :pending, site: site, category: category, user: user) }
    let!(:approved_submission) { create(:submission, :approved, site: site, category: category, user: user) }

    describe ".needs_review" do
      it "returns pending submissions ordered by created_at" do
        expect(Submission.needs_review).to include(pending_submission)
        expect(Submission.needs_review).not_to include(approved_submission)
      end
    end

    describe ".by_user" do
      let(:other_user) { create(:user) }
      let!(:other_submission) { create(:submission, site: site, category: category, user: other_user) }

      it "returns submissions for the specified user" do
        expect(Submission.by_user(user)).to include(pending_submission, approved_submission)
        expect(Submission.by_user(user)).not_to include(other_submission)
      end
    end
  end

  describe "#approve!" do
    let(:submission) { create(:submission, :pending, site: site, category: category, user: user) }
    let(:reviewer) { create(:user, :admin) }

    it "changes status to approved" do
      submission.approve!(reviewer: reviewer)
      expect(submission.reload.status).to eq("approved")
    end

    it "sets reviewer" do
      submission.approve!(reviewer: reviewer)
      expect(submission.reload.reviewer).to eq(reviewer)
    end

    it "sets reviewed_at" do
      submission.approve!(reviewer: reviewer)
      expect(submission.reload.reviewed_at).to be_present
    end

    it "creates an entry" do
      expect { submission.approve!(reviewer: reviewer) }.to change(Entry, :count).by(1)
    end

    it "links the entry" do
      entry = submission.approve!(reviewer: reviewer)
      expect(submission.reload.entry).to eq(entry)
    end

    it "sets reviewer notes" do
      submission.approve!(reviewer: reviewer, notes: "Great submission!")
      expect(submission.reload.reviewer_notes).to eq("Great submission!")
    end
  end

  describe "#reject!" do
    let(:submission) { create(:submission, :pending, site: site, category: category, user: user) }
    let(:reviewer) { create(:user, :admin) }

    it "changes status to rejected" do
      submission.reject!(reviewer: reviewer)
      expect(submission.reload.status).to eq("rejected")
    end

    it "sets reviewer" do
      submission.reject!(reviewer: reviewer)
      expect(submission.reload.reviewer).to eq(reviewer)
    end

    it "sets reviewer notes" do
      submission.reject!(reviewer: reviewer, notes: "Does not meet guidelines.")
      expect(submission.reload.reviewer_notes).to eq("Does not meet guidelines.")
    end
  end

  describe "URL normalization" do
    it "adds https:// prefix if missing" do
      submission = build(:submission, url: "example.com", site: site, category: category, user: user)
      submission.valid?
      expect(submission.url).to eq("https://example.com")
    end

    it "preserves http:// prefix" do
      submission = build(:submission, url: "http://example.com", site: site, category: category, user: user)
      submission.valid?
      expect(submission.url).to eq("http://example.com")
    end

    it "preserves https:// prefix" do
      submission = build(:submission, url: "https://example.com", site: site, category: category, user: user)
      submission.valid?
      expect(submission.url).to eq("https://example.com")
    end
  end
end
