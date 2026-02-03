# frozen_string_literal: true

# Validates that ActiveStorage attachments are within size limits.
#
# Usage:
#   validates :avatar, file_size: { max: 5.megabytes }
#   validates :document, file_size: { min: 1.kilobyte, max: 10.megabytes }
#   validates :files, file_size: { max: 50.megabytes, total: 100.megabytes }
#
# Options:
#   :max     - Maximum file size per attachment (default: 500MB)
#   :min     - Minimum file size per attachment (optional)
#   :total   - Maximum total size for has_many_attached (optional)
#   :message - Custom error message
#
class FileSizeValidator < ActiveModel::EachValidator
  DEFAULT_MAX_SIZE = 500.megabytes
  DEFAULT_MIN_SIZE = 0

  def validate_each(record, attribute, value)
    return unless value.attached?

    max_size = options[:max] || DEFAULT_MAX_SIZE
    min_size = options[:min] || DEFAULT_MIN_SIZE
    total_max = options[:total]

    if value.is_a?(ActiveStorage::Attached::Many)
      validate_many(record, attribute, value, min_size, max_size, total_max)
    else
      validate_single(record, attribute, value, min_size, max_size)
    end
  end

  private

  def validate_single(record, attribute, value, min_size, max_size)
    byte_size = value.blob.byte_size

    if byte_size > max_size
      record.errors.add(attribute, too_large_message(byte_size, max_size))
    elsif byte_size < min_size
      record.errors.add(attribute, too_small_message(byte_size, min_size))
    end
  end

  def validate_many(record, attribute, value, min_size, max_size, total_max)
    total_size = 0

    value.blobs.each do |blob|
      if blob.byte_size > max_size
        record.errors.add(attribute, too_large_message(blob.byte_size, max_size, blob.filename))
      elsif blob.byte_size < min_size
        record.errors.add(attribute, too_small_message(blob.byte_size, min_size, blob.filename))
      end
      total_size += blob.byte_size
    end

    if total_max && total_size > total_max
      record.errors.add(attribute, total_too_large_message(total_size, total_max))
    end
  end

  def too_large_message(actual, max, filename = nil)
    return options[:message] if options[:message].present?

    prefix = filename ? "#{filename} " : ""
    "#{prefix}is too large (#{human_size(actual)}). Maximum: #{human_size(max)}"
  end

  def too_small_message(actual, min, filename = nil)
    return options[:message] if options[:message].present?

    prefix = filename ? "#{filename} " : ""
    "#{prefix}is too small (#{human_size(actual)}). Minimum: #{human_size(min)}"
  end

  def total_too_large_message(actual, max)
    "total size is too large (#{human_size(actual)}). Maximum total: #{human_size(max)}"
  end

  def human_size(bytes)
    case bytes
    when 0...1.kilobyte
      "#{bytes} bytes"
    when 1.kilobyte...1.megabyte
      "#{(bytes / 1.kilobyte.to_f).round(1)} KB"
    when 1.megabyte...1.gigabyte
      "#{(bytes / 1.megabyte.to_f).round(1)} MB"
    else
      "#{(bytes / 1.gigabyte.to_f).round(2)} GB"
    end
  end
end
