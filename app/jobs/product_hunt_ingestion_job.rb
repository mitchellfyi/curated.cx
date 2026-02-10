# frozen_string_literal: true

# Job to fetch products from Product Hunt via GraphQL API and store as feed Entries.
# Requires OAuth2 access token configured in the source config.
class ProductHuntIngestionJob < ApplicationJob
  include WorkflowPausable

  self.workflow_type = :product_hunt_ingestion

  queue_as :ingestion

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  PH_GRAPHQL_URL = "https://api.producthunt.com/v2/api/graphql"

  def perform(source_id)
    @source = Source.find(source_id)
    @site = @source.site
    @tenant = @site.tenant

    # Set tenant context for the job
    Current.tenant = @tenant
    Current.site = @site

    # Check if workflow is paused
    return if workflow_paused?(source: @source, tenant: @tenant)

    # Verify source is enabled and correct kind
    unless @source.enabled? && @source.product_hunt?
      @source.update_run_status("skipped")
      return
    end

    # Create ImportRun to track this execution
    @import_run = ImportRun.create_for_source!(@source)

    begin
      execute_ingestion
    rescue StandardError => e
      handle_failure(e)
      raise
    end
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def execute_ingestion
    access_token = config_value("access_token")
    raise ConfigurationError, "Product Hunt access_token is required" if access_token.blank?

    # Call Product Hunt GraphQL API
    results = fetch_from_product_hunt(access_token)

    # Parse results and create feed Entries
    stats = process_results(results)

    # Mark import run as completed
    @import_run.mark_completed!(
      items_created: stats[:created],
      items_updated: stats[:updated],
      items_failed: stats[:failed]
    )

    # Update source status
    @source.update_run_status("success")
  end

  def fetch_from_product_hunt(access_token)
    require "net/http"
    require "json"
    require "uri"

    uri = URI(PH_GRAPHQL_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    request.body = { query: graphql_query }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise ExternalServiceError, "Product Hunt API request failed: #{response.code} #{response.message}"
    end

    JSON.parse(response.body)
  end

  def graphql_query
    max_results = config_value("max_results")&.to_i || 50
    feed_type = config_value("feed_type") || "featured"
    topic = config_value("topic")

    if topic.present?
      topic_query(topic, max_results)
    elsif feed_type == "newest"
      posts_query("NEWEST", max_results)
    else
      posts_query("RANKING", max_results)
    end
  end

  def posts_query(order, count)
    <<~GRAPHQL
      {
        posts(first: #{count}, order: #{order}) {
          edges {
            node {
              id
              name
              url
              tagline
              description
              votesCount
              createdAt
              thumbnail {
                url
              }
              topics {
                edges {
                  node {
                    name
                  }
                }
              }
              makers {
                id
                name
                username
              }
            }
          }
        }
      }
    GRAPHQL
  end

  def topic_query(topic, count)
    <<~GRAPHQL
      {
        topic(slug: "#{topic}") {
          posts(first: #{count}) {
            edges {
              node {
                id
                name
                url
                tagline
                description
                votesCount
                createdAt
                thumbnail {
                  url
                }
                topics {
                  edges {
                    node {
                      name
                    }
                  }
                }
                makers {
                  id
                  name
                  username
                }
              }
            }
          }
        }
      }
    GRAPHQL
  end

  def process_results(results)
    stats = { created: 0, updated: 0, failed: 0 }

    # Extract posts from GraphQL response (handles both posts and topic queries)
    posts_data = results.dig("data", "posts", "edges") ||
                 results.dig("data", "topic", "posts", "edges") ||
                 []

    max_results = config_value("max_results")&.to_i || 50
    posts_data = posts_data.first(max_results)

    posts_data.each do |edge|
      process_single_result(edge["node"], stats)
    end

    stats
  end

  def process_single_result(node, stats)
    url = node["url"]
    return if url.blank?

    # Canonicalize the URL
    canonical_url = UrlCanonicaliser.canonicalize(url)

    # Find or initialize feed Entry by canonical URL (deduplication)
    entry = Entry.find_or_initialize_by_canonical_url(
      site: @site,
      url_canonical: canonical_url,
      source: @source,
      entry_kind: "feed"
    )

    is_new = entry.new_record?

    entry.assign_attributes(
      url_raw: url,
      title: node["name"],
      description: node["tagline"],
      og_image_url: node.dig("thumbnail", "url"),
      published_at: parse_date(node["createdAt"]),
      raw_payload: node,
      tags: extract_tags(node)
    )

    if entry.save
      is_new ? stats[:created] += 1 : stats[:updated] += 1
    else
      stats[:failed] += 1
      log_job_warning(
        "Failed to save Entry",
        url: url,
        errors: entry.errors.full_messages
      )
    end
  rescue UrlCanonicaliser::InvalidUrlError => e
    stats[:failed] += 1
    log_job_warning("Invalid URL", url: url, error: e.message)
  rescue StandardError => e
    stats[:failed] += 1
    log_job_warning("Failed to process result", url: url, error: e.message)
  end

  def handle_failure(error)
    @import_run&.mark_failed!(error.message)
    @source.update_run_status("error: #{error.message}")
    log_job_error(error, source_id: @source.id, import_run_id: @import_run&.id)
  end

  def config_value(key)
    @source.config[key] || @source.config[key.to_sym]
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    Time.zone.parse(date_string)
  rescue ArgumentError
    nil
  end

  def extract_tags(node)
    tags = [ "source:product-hunt" ]

    # Add topic tags from the topics field
    topics = node.dig("topics", "edges") || []
    topics.each do |edge|
      topic_name = edge.dig("node", "name")
      tags << "topic:#{topic_name.downcase.gsub(/\s+/, '-')}" if topic_name.present?
    end

    tags
  end
end
