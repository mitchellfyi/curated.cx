# frozen_string_literal: true

# Test helpers specific to job specs
module JobTestHelpers
  # Set up tenant context for job tests
  def setup_job_tenant_context(tenant, site = nil)
    site ||= tenant.sites.first || create(:site, tenant: tenant)
    Current.tenant = tenant
    Current.site = site
    ActsAsTenant.current_tenant = tenant
    [ tenant, site ]
  end

  # Clear tenant context after job tests
  def clear_job_tenant_context
    Current.tenant = nil
    Current.site = nil
    ActsAsTenant.current_tenant = nil
  end

  # Load fixture file content
  def fixture_file(filename)
    File.read(Rails.root.join("spec", "fixtures", "files", filename))
  end

  # Stub an RSS feed response
  def stub_rss_feed(url, body: nil, status: 200)
    body ||= fixture_file("sample_feed.xml")
    stub_request(:get, url)
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/rss+xml" })
  end

  # Stub a SerpAPI response
  def stub_serp_api_response(query: nil, status: 200)
    body = fixture_file("serp_api_news.json")
    stub_request(:get, /serpapi\.com\/search\.json/)
      .with(query: hash_including("engine" => "google_news"))
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  # Stub a Hacker News Algolia API response
  def stub_hacker_news_response(status: 200)
    body = fixture_file("hacker_news_search.json")
    stub_request(:get, /hn\.algolia\.com\/api\/v1\/search/)
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  # Stub a Product Hunt GraphQL API response
  def stub_product_hunt_response(status: 200, fixture: "product_hunt_posts.json")
    body = fixture_file(fixture)
    stub_request(:post, "https://api.producthunt.com/v2/api/graphql")
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  # Stub an HTML page response for MetaInspector
  def stub_html_page(url, body: nil, status: 200)
    body ||= fixture_file("sample_page.html")
    stub_request(:get, url)
      .to_return(status: status, body: body, headers: { "Content-Type" => "text/html" })
  end
end

# Configure RSpec to include helpers for job specs
RSpec.configure do |config|
  config.include JobTestHelpers, type: :job

  config.before(:each, type: :job) do
    clear_job_tenant_context
  end

  config.after(:each, type: :job) do
    clear_job_tenant_context
  end
end
