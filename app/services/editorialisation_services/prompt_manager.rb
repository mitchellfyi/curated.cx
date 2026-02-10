# frozen_string_literal: true

module EditorialisationServices
  # Manages prompt templates for AI editorialisation.
  # Loads prompts from config/editorialisation/prompts/ directory.
  #
  # Usage:
  #   manager = Editorialisation::PromptManager.new
  #   version = manager.current_version
  #   prompt = manager.build_prompt(content_item)
  #
  class PromptManager
    PROMPTS_PATH = Rails.root.join("config/editorialisation/prompts")
    DEFAULT_VERSION = "v1.0.0"

    # Maximum characters of extracted text to include in prompt
    MAX_TEXT_LENGTH = 4000

    class PromptNotFoundError < StandardError; end

    def initialize(version: nil)
      @version = version || current_version
      @config = load_config(@version)
    end

    attr_reader :version, :config

    # Returns the latest available prompt version
    def self.current_version
      versions = Dir.glob(PROMPTS_PATH.join("*.yml")).map do |file|
        File.basename(file, ".yml")
      end

      return DEFAULT_VERSION if versions.empty?

      # Sort versions semantically (v1.0.0, v1.0.1, v1.1.0, etc.)
      versions.sort_by { |v| Gem::Version.new(v.delete_prefix("v")) }.last
    end

    def current_version
      self.class.current_version
    end

    # Get prompt configuration for a specific version
    def self.get_prompt(version)
      new(version: version).config
    end

    # Build the complete prompt for a content item
    def build_prompt(content_item)
      template = config["user_prompt_template"]

      # Truncate extracted text to avoid token limits
      extracted_text = content_item.extracted_text || ""
      truncated_text = truncate_text(extracted_text, MAX_TEXT_LENGTH)

      # Build taxonomy list for the site so AI can suggest from known topics
      taxonomy_list = build_taxonomy_list(content_item.site_id)

      # Interpolate template variables
      prompt = template
        .gsub("{title}", content_item.title || "")
        .gsub("{url}", content_item.url_canonical || "")
        .gsub("{description}", content_item.description || "")
        .gsub("{extracted_text}", truncated_text)
        .gsub("{taxonomy_list}", taxonomy_list)

      {
        system_prompt: config["system_prompt"],
        user_prompt: prompt,
        version: version,
        model: model_config
      }
    end

    # Get model configuration
    def model_config
      config["model"] || {}
    end

    # Get output constraints
    def constraints
      config["constraints"] || {}
    end

    private

    def load_config(version)
      path = PROMPTS_PATH.join("#{version}.yml")

      unless File.exist?(path)
        raise PromptNotFoundError, "Prompt version #{version} not found at #{path}"
      end

      YAML.load_file(path)
    end

    def truncate_text(text, max_length)
      return text if text.length <= max_length

      # Truncate at word boundary
      truncated = text[0, max_length]
      last_space = truncated.rindex(/\s/)
      truncated = truncated[0, last_space] if last_space && last_space > max_length - 100

      "#{truncated}..."
    end

    # Build a comma-separated list of taxonomy slugs for the site
    # so the AI can suggest from known topics
    def build_taxonomy_list(site_id)
      taxonomies = Taxonomy.where(site_id: site_id).order(:position).pluck(:slug)
      return "(none defined)" if taxonomies.empty?

      taxonomies.join(", ")
    end
  end
end
