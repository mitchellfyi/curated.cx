# frozen_string_literal: true

# Job to extract link preview metadata for notes
class ExtractNoteLinkPreviewJob < ApplicationJob
  queue_as :default

  # Retry on network errors
  retry_on LinkPreviewService::ExtractionError, wait: :polynomially_longer, attempts: 3

  # Discard if the note was deleted
  discard_on ActiveRecord::RecordNotFound

  def perform(note_id, url)
    note = Note.unscoped.find(note_id)

    preview = LinkPreviewService.extract(url)

    note.update!(link_preview: preview)
  rescue LinkPreviewService::ExtractionError => e
    # Log but don't fail the note creation - preview is optional
    Rails.logger.warn("Failed to extract link preview for note #{note_id}: #{e.message}")
    raise # Re-raise for retry mechanism
  end
end
