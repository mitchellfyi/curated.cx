# frozen_string_literal: true

module Admin
  class ActivityController < ApplicationController
    include AdminAccess

    # GET /admin/activity
    def index
      @activities = []

      # Recent user signups
      User.order(created_at: :desc).limit(5).each do |user|
        @activities << {
          type: "user_signup",
          icon: "user-add",
          color: "green",
          title: "New user signup",
          description: user.email,
          link: admin_user_path(user),
          time: user.created_at
        }
      end

      # Recent content imports
      ContentItem.order(created_at: :desc).limit(5).each do |item|
        @activities << {
          type: "content_import",
          icon: "document-add",
          color: "blue",
          title: "Content imported",
          description: item.title.presence || item.url_canonical,
          link: admin_content_item_path(item),
          time: item.created_at
        }
      end

      # Recent notes
      Note.order(created_at: :desc).limit(5).each do |note|
        @activities << {
          type: "note_created",
          icon: "pencil",
          color: "purple",
          title: "Note created",
          description: truncate(note.body, length: 60),
          link: admin_note_path(note),
          time: note.created_at
        }
      end

      # Failed imports
      ImportRun.failed.order(completed_at: :desc).limit(5).each do |run|
        @activities << {
          type: "import_failed",
          icon: "exclamation",
          color: "red",
          title: "Import failed",
          description: "#{run.source.name}: #{run.error_message&.truncate(50)}",
          link: admin_import_run_path(run),
          time: run.completed_at || run.started_at
        }
      end

      # Submissions
      Submission.order(created_at: :desc).limit(5).each do |submission|
        @activities << {
          type: "submission",
          icon: "inbox",
          color: "yellow",
          title: "New submission",
          description: submission.url,
          link: admin_submissions_path,
          time: submission.created_at
        }
      end

      # Flags
      Flag.order(created_at: :desc).limit(5).each do |flag|
        @activities << {
          type: "flag",
          icon: "flag",
          color: "red",
          title: "Content flagged",
          description: "#{flag.flaggable_type} - #{flag.reason}",
          link: admin_flag_path(flag),
          time: flag.created_at
        }
      end

      # Sort all activities by time
      @activities = @activities.sort_by { |a| a[:time] }.reverse.first(30)
    end

    private

    def truncate(text, length: 50)
      return "" if text.blank?
      text.length > length ? "#{text[0...length]}..." : text
    end
  end
end
