# frozen_string_literal: true

# Validates that ActiveStorage attachments have allowed content types.
#
# Usage:
#   validates :avatar, file_content_type: { in: %w[image/png image/jpeg] }
#   validates :document, file_content_type: { in: FileContentTypeValidator::DOCUMENT_TYPES }
#   validates :attachment, file_content_type: true  # Uses ALLOWED_CONTENT_TYPES
#
# Options:
#   :in       - Array of allowed content types
#   :message  - Custom error message (default: "has an invalid file type")
#   :allow_nil - Skip validation if attachment not present (default: true for attached?)
#
class FileContentTypeValidator < ActiveModel::EachValidator
  # Common content type groups for convenience
  IMAGE_TYPES = %w[
    image/png
    image/jpeg
    image/gif
    image/webp
    image/svg+xml
  ].freeze

  DOCUMENT_TYPES = %w[
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    text/plain
    text/markdown
  ].freeze

  MEDIA_TYPES = %w[
    audio/mpeg
    audio/mp4
    audio/wav
    audio/ogg
    video/mp4
    video/webm
    video/quicktime
  ].freeze

  ARCHIVE_TYPES = %w[
    application/zip
    application/x-zip-compressed
    application/epub+zip
    application/gzip
  ].freeze

  ALLOWED_CONTENT_TYPES = (IMAGE_TYPES + DOCUMENT_TYPES + MEDIA_TYPES + ARCHIVE_TYPES).freeze

  def validate_each(record, attribute, value)
    return unless value.attached?

    content_type = extract_content_type(value)
    return if content_type.nil?

    allowed_types = normalize_allowed_types(options[:in])
    return if content_type_allowed?(content_type, allowed_types)

    record.errors.add(attribute, error_message(content_type, allowed_types))
  end

  private

  def extract_content_type(value)
    # Handle both single and multiple attachments
    if value.is_a?(ActiveStorage::Attached::Many)
      # For has_many_attached, validate each blob
      value.blobs.each do |blob|
        return blob.content_type unless content_type_allowed?(blob.content_type, normalize_allowed_types(options[:in]))
      end
      nil # All blobs valid
    else
      value.blob&.content_type
    end
  end

  def normalize_allowed_types(types)
    types || ALLOWED_CONTENT_TYPES
  end

  def content_type_allowed?(content_type, allowed_types)
    allowed_types.any? do |allowed|
      if allowed.end_with?("/*")
        # Wildcard matching (e.g., "image/*" matches "image/png")
        content_type.start_with?(allowed.chomp("/*"))
      else
        content_type == allowed
      end
    end
  end

  def error_message(content_type, allowed_types)
    return options[:message] if options[:message].present?

    allowed_summary = summarize_types(allowed_types)
    "has an invalid file type (#{content_type}). Allowed: #{allowed_summary}"
  end

  def summarize_types(types)
    if types.length > 5
      "#{types.first(3).join(', ')} and #{types.length - 3} more"
    else
      types.join(", ")
    end
  end
end
