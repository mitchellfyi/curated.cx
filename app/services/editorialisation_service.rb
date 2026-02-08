# frozen_string_literal: true

# Main service for AI editorialisation of content items.
# Orchestrates prompt building, AI API calls, and result storage.
#
# Usage:
#   result = EditorialisationService.editorialise(content_item)
#   # result is the Editorialisation record (completed, failed, or skipped)
#
class EditorialisationService
  # Minimum characters of extracted text required for editorialisation
  MIN_TEXT_LENGTH = 200

  # Entry point - class method for convenience
  def self.editorialise(content_item)
    new(content_item).call
  end

  def initialize(content_item)
    @content_item = content_item
    @site = content_item.site
  end

  # Main execution method
  # Returns: Editorialisation record with appropriate status
  def call
    # Check eligibility first
    unless eligible?
      return create_skipped_record(skip_reason)
    end

    # Create pending editorialisation record
    editorialisation = create_pending_record

    begin
      execute_editorialisation(editorialisation)
    rescue AiApiError, AiRateLimitError, AiTimeoutError => e
      # Retryable errors - mark failed and re-raise for job retry
      editorialisation.mark_failed!(e.message)
      raise
    rescue AiInvalidResponseError, AiConfigurationError => e
      # Non-retryable errors - mark failed and don't re-raise
      editorialisation.mark_failed!(e.message)
      editorialisation
    rescue StandardError => e
      # Unexpected errors - mark failed and re-raise
      editorialisation.mark_failed!("Unexpected error: #{e.message}")
      raise
    end
  end

  private

  attr_reader :content_item, :site

  # Check if content item is eligible for editorialisation
  def eligible?
    skip_reason.nil?
  end

  # Returns reason for skipping, or nil if eligible
  def skip_reason
    @skip_reason ||= calculate_skip_reason
  end

  def calculate_skip_reason
    # Check if already editorialised
    if content_item.editorialised_at.present?
      return "Already editorialised"
    end

    # Check if existing completed editorialisation exists
    if ::Editorialisation.exists?(content_item_id: content_item.id, status: :completed)
      return "Existing completed editorialisation"
    end

    # Check text length
    text_length = content_item.extracted_text&.length || 0
    if text_length < MIN_TEXT_LENGTH
      return "Insufficient text (#{text_length} chars, minimum #{MIN_TEXT_LENGTH})"
    end

    # Check if source has editorialisation enabled
    unless content_item.source&.editorialisation_enabled?
      return "Source editorialisation disabled"
    end

    nil
  end

  def create_skipped_record(reason)
    # If an editorialisation already exists for this content item, return it
    # (respects unique constraint on content_item_id)
    existing = ::Editorialisation.find_by(content_item_id: content_item.id)
    return existing if existing

    prompt_manager = EditorialisationServices::PromptManager.new

    ::Editorialisation.create!(
      site: site,
      content_item: content_item,
      prompt_version: prompt_manager.version,
      prompt_text: "(skipped)",
      status: :skipped,
      error_message: reason
    )
  end

  def create_pending_record
    prompt_manager = EditorialisationServices::PromptManager.new
    prompt = prompt_manager.build_prompt(content_item)

    ::Editorialisation.create!(
      site: site,
      content_item: content_item,
      prompt_version: prompt[:version],
      prompt_text: prompt[:user_prompt],
      status: :pending
    )
  end

  def execute_editorialisation(editorialisation)
    editorialisation.mark_processing!

    # Build prompt
    prompt_manager = EditorialisationServices::PromptManager.new(version: editorialisation.prompt_version)
    prompt = prompt_manager.build_prompt(content_item)

    # Make AI API call
    ai_client = EditorialisationServices::AiClient.new
    result = ai_client.complete(
      system_prompt: prompt[:system_prompt],
      user_prompt: prompt[:user_prompt],
      model: prompt[:model]["name"],
      max_tokens: prompt[:model]["max_tokens"],
      temperature: prompt[:model]["temperature"]
    )

    # Parse the response
    parsed = parse_ai_response(result[:content], prompt_manager.constraints)

    # Update editorialisation record
    editorialisation.mark_completed!(
      parsed: parsed,
      raw: result[:content],
      tokens: result[:tokens_used],
      duration: result[:duration_ms],
      model: result[:model]
    )

    # Update content item with AI results
    update_content_item(parsed)

    editorialisation
  end

  def parse_ai_response(raw_content, constraints)
    begin
      parsed = JSON.parse(raw_content)
    rescue JSON::ParserError => e
      raise AiInvalidResponseError.new("Failed to parse AI response as JSON: #{e.message}")
    end

    # Validate expected fields
    unless parsed.key?("summary") && parsed.key?("why_it_matters")
      raise AiInvalidResponseError.new("AI response missing required fields")
    end

    # Enforce length limits
    max_summary = constraints["max_summary_length"] || 280
    max_why = constraints["max_why_it_matters_length"] || 500
    max_tags = constraints["max_suggested_tags"] || 5
    max_takeaways = constraints["max_key_takeaways"] || 5
    max_audience = constraints["max_audience_tags"] || 3

    result = {
      "summary" => truncate_field(parsed["summary"], max_summary),
      "why_it_matters" => truncate_field(parsed["why_it_matters"], max_why),
      "suggested_tags" => Array(parsed["suggested_tags"]).first(max_tags)
    }

    # Enhanced editorial fields (v2.0.0+)
    if parsed.key?("key_takeaways")
      result["key_takeaways"] = Array(parsed["key_takeaways"]).first(max_takeaways)
    end

    if parsed.key?("audience_tags")
      result["audience_tags"] = Array(parsed["audience_tags"]).first(max_audience)
    end

    if parsed.key?("quality_score")
      score = parsed["quality_score"].to_f
      result["quality_score"] = score.clamp(0.0, 10.0).round(1)
    end

    result
  end

  def truncate_field(text, max_length)
    return "" if text.blank?
    text.to_s.truncate(max_length)
  end

  def update_content_item(parsed)
    attrs = {
      ai_summary: parsed["summary"],
      why_it_matters: parsed["why_it_matters"],
      ai_suggested_tags: parsed["suggested_tags"],
      editorialised_at: Time.current
    }

    # Enhanced editorial fields (v2.0.0+)
    attrs[:key_takeaways] = parsed["key_takeaways"] if parsed.key?("key_takeaways")
    attrs[:audience_tags] = parsed["audience_tags"] if parsed.key?("audience_tags")
    attrs[:quality_score] = parsed["quality_score"] if parsed.key?("quality_score")

    content_item.update_columns(attrs)
  end
end
