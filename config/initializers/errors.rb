# frozen_string_literal: true

# Explicitly require error classes since they don't follow zeitwerk conventions
# (multiple classes per file with non-matching names)
require_relative "../../app/errors/application_error"
require_relative "../../app/errors/ai_api_error"
