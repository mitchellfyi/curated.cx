# frozen_string_literal: true

module Admin
  class ActivityController < ApplicationController
    include AdminAccess

    # Activity types with their display configuration
    ACTIVITY_TYPES = {
      user_signup: { icon: "user-add", color: "green", title: "New user signup" },
      content_import: { icon: "document-add", color: "blue", title: "Content imported" },
      note_created: { icon: "pencil", color: "purple", title: "Note created" },
      import_failed: { icon: "exclamation", color: "red", title: "Import failed" },
      submission: { icon: "inbox", color: "yellow", title: "New submission" },
      flag: { icon: "flag", color: "red", title: "Content flagged" }
    }.freeze

    # GET /admin/activity
    def index
      @activities = fetch_all_activities
                      .sort_by { |a| a[:time] }
                      .reverse
                      .first(30)
    end

    private

    def fetch_all_activities
      [
        *fetch_user_signups,
        *fetch_content_imports,
        *fetch_notes,
        *fetch_failed_imports,
        *fetch_submissions,
        *fetch_flags
      ]
    end

    def fetch_user_signups
      User.select(:id, :email, :created_at)
          .order(created_at: :desc)
          .limit(5)
          .map { |user| build_activity(:user_signup, user.email, admin_user_path(user), user.created_at) }
    end

    def fetch_content_imports
      Entry.select(:id, :title, :url_canonical, :created_at)
                 .order(created_at: :desc)
                 .limit(5)
                 .map { |item| build_activity(:content_import, item.title.presence || item.url_canonical, admin_entry_path(item), item.created_at) }
    end

    def fetch_notes
      Note.select(:id, :body, :created_at)
          .order(created_at: :desc)
          .limit(5)
          .map { |note| build_activity(:note_created, truncate_text(note.body, 60), admin_note_path(note), note.created_at) }
    end

    def fetch_failed_imports
      ImportRun.failed
               .includes(:source)
               .select("import_runs.id, import_runs.error_message, import_runs.completed_at, import_runs.started_at, import_runs.source_id")
               .order(completed_at: :desc)
               .limit(5)
               .map do |run|
                 desc = "#{run.source&.name}: #{run.error_message&.truncate(50)}"
                 build_activity(:import_failed, desc, admin_import_run_path(run), run.completed_at || run.started_at)
               end
    end

    def fetch_submissions
      Submission.select(:id, :url, :created_at)
                .order(created_at: :desc)
                .limit(5)
                .map { |sub| build_activity(:submission, sub.url, admin_submissions_path, sub.created_at) }
    end

    def fetch_flags
      Flag.select(:id, :flaggable_type, :reason, :created_at)
          .order(created_at: :desc)
          .limit(5)
          .map do |flag|
            desc = "#{flag.flaggable_type} - #{flag.reason}"
            build_activity(:flag, desc, admin_flag_path(flag), flag.created_at)
          end
    end

    def build_activity(type, description, link, time)
      config = ACTIVITY_TYPES[type]
      {
        type: type.to_s,
        icon: config[:icon],
        color: config[:color],
        title: config[:title],
        description: description,
        link: link,
        time: time
      }
    end

    def truncate_text(text, length)
      return "" if text.blank?
      text.length > length ? "#{text[0...length]}..." : text
    end
  end
end
