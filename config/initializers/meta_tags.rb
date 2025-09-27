# frozen_string_literal: true

require "meta-tags"

# MetaTags configuration
MetaTags.configure do |config|
  # How many characters should the title be truncated to?
  config.title_limit = 70

  # Maximum length of the description tag
  config.description_limit = 160

  # Maximum length of the keywords tag
  config.keywords_limit = 255

  # Default separator for keywords
  config.keywords_separator = ", "

  # When true, keywords will be converted to lowercase, otherwise they will appear on the page as provided
  config.keywords_lowercase = true

  # When true, the output will not include new line characters between meta tags
  config.minify_output = true
end
