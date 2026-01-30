# frozen_string_literal: true

class FileSizeValidator < ActiveModel::EachValidator
  MAX_SIZE = 500.megabytes

  def validate_each(record, attribute, value)
    return unless value.attached?

    max_size = options[:max] || MAX_SIZE
    return if value.blob.byte_size <= max_size

    record.errors.add(attribute, options[:message] || "is too large (maximum is #{max_size / 1.megabyte}MB)")
  end
end
