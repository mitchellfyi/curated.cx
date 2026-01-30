# frozen_string_literal: true

class FileContentTypeValidator < ActiveModel::EachValidator
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/zip
    application/epub+zip
    audio/mpeg
    video/mp4
    image/png
    image/jpeg
  ].freeze

  def validate_each(record, attribute, value)
    return unless value.attached?

    content_type = value.blob.content_type
    allowed_types = options[:in] || ALLOWED_CONTENT_TYPES

    return if allowed_types.include?(content_type)

    record.errors.add(attribute, options[:message] || "has an invalid file type")
  end
end
