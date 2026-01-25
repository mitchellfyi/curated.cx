# SEO Testing Standards and Implementation Guide

## Overview

This document provides comprehensive SEO testing standards for the Curated.www multi-tenant platform. SEO is critical for content discovery and tenant growth.

## SEO Testing Requirements

### 1. Meta Tags Testing
Every public page must have proper meta tags:

```ruby
# spec/system/seo/meta_tags_spec.rb
RSpec.describe "Meta tags", type: :system do
  let(:tenant) { create(:tenant, title: "AI News", description: "Latest AI industry news") }
  let(:listing) { create(:listing, :published, tenant: tenant) }

  before do
    ActsAsTenant.current_tenant = tenant
  end

  context "listing pages" do
    it "includes proper meta tags" do
      visit listing_path(listing)

      expect(page).to have_title("#{listing.title} | #{tenant.title}")
      expect(page).to have_meta_description(listing.decorate.seo_description)
      expect(page).to have_link(rel: 'canonical', href: listing_url(listing))

      # Open Graph tags
      expect(page).to have_meta_property('og:title', content: listing.title)
      expect(page).to have_meta_property('og:description', content: listing.description)
      expect(page).to have_meta_property('og:url', content: listing_url(listing))
      expect(page).to have_meta_property('og:type', content: 'article')

      # Twitter Card tags
      expect(page).to have_meta_name('twitter:card', content: 'summary_large_image')
      expect(page).to have_meta_name('twitter:title', content: listing.title)
    end
  end

  context "tenant home pages" do
    it "includes tenant-specific meta tags" do
      visit root_path

      expect(page).to have_title(tenant.title)
      expect(page).to have_meta_description(tenant.description)
      expect(page).to have_link(rel: 'canonical', href: root_url)
    end
  end
end
```

### 2. Structured Data Testing

```ruby
# spec/system/seo/structured_data_spec.rb
RSpec.describe "Structured data", type: :system do
  let(:listing) { create(:listing, :published, :with_image) }

  it "includes JSON-LD structured data" do
    visit listing_path(listing)

    structured_data = find('script[type="application/ld+json"]', visible: false)
    data = JSON.parse(structured_data.text(:all))

    expect(data['@context']).to eq('https://schema.org')
    expect(data['@type']).to eq('Article')
    expect(data['headline']).to eq(listing.title)
    expect(data['description']).to eq(listing.description)
    expect(data['datePublished']).to be_present
    expect(data['author']['@type']).to eq('Organization')
    expect(data['publisher']['@type']).to eq('Organization')
  end

  it "includes organization structured data" do
    visit root_path

    structured_data = find('script[type="application/ld+json"]', visible: false)
    data = JSON.parse(structured_data.text(:all))

    expect(data['@type']).to eq('Organization')
    expect(data['name']).to eq(Current.tenant.title)
    expect(data['url']).to eq(root_url)
  end
end
```

### 3. XML Sitemap Testing

```ruby
# spec/requests/sitemaps_spec.rb
RSpec.describe "XML Sitemaps", type: :request do
  let(:tenant) { create(:tenant) }
  let!(:listings) { create_list(:listing, 3, :published, tenant: tenant) }

  before do
    ActsAsTenant.current_tenant = tenant
  end

  it "generates valid XML sitemap" do
    get sitemap_path(format: :xml)

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to eq('application/xml; charset=utf-8')

    doc = Nokogiri::XML(response.body)
    expect(doc.errors).to be_empty

    # Check sitemap structure
    expect(doc.xpath('//urlset')).to be_present
    expect(doc.xpath('//url')).to have(listings.count + 1) # +1 for home page

    # Check individual URLs
    listings.each do |listing|
      expect(doc.xpath("//loc[text()='#{listing_url(listing)}']")).to be_present
    end
  end

  it "includes proper lastmod dates" do
    get sitemap_path(format: :xml)

    doc = Nokogiri::XML(response.body)
    lastmod_elements = doc.xpath('//lastmod')

    expect(lastmod_elements.length).to be > 0
    lastmod_elements.each do |element|
      expect(element.text).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end
  end
end
```

### 4. Robots.txt Testing

```ruby
# spec/requests/robots_spec.rb
RSpec.describe "Robots.txt", type: :request do
  it "serves robots.txt with proper directives" do
    get "/robots.txt"

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to eq('text/plain; charset=utf-8')

    robots_content = response.body
    expect(robots_content).to include('User-agent: *')
    expect(robots_content).to include('Sitemap:')
    expect(robots_content).to include(sitemap_url(format: :xml))
  end
end
```

## SEO Implementation Patterns

### 1. Controller Meta Tag Setup

```ruby
class ListingsController < ApplicationController
  before_action :set_seo_meta_tags, only: [:show, :index]

  private

  def set_seo_meta_tags
    case action_name
    when 'show'
      set_listing_meta_tags
    when 'index'
      set_listings_index_meta_tags
    end
  end

  def set_listing_meta_tags
    @listing = @listing.decorate

    set_meta_tags(
      title: @listing.seo_title,
      description: @listing.seo_description,
      canonical: listing_url(@listing),
      og: {
        title: @listing.title,
        description: @listing.description,
        image: @listing.image_url,
        url: listing_url(@listing),
        type: 'article',
        site_name: Current.tenant.title
      },
      twitter: {
        card: @listing.image_url? ? 'summary_large_image' : 'summary',
        title: @listing.title,
        description: @listing.description,
        image: @listing.image_url
      }
    )
  end

  def set_listings_index_meta_tags
    set_meta_tags(
      title: t('pages.listings.meta_title', tenant: Current.tenant.title),
      description: t('pages.listings.meta_description', tenant: Current.tenant.title),
      canonical: listings_url,
      og: {
        title: Current.tenant.title,
        description: Current.tenant.description,
        url: root_url,
        type: 'website'
      }
    )
  end
end
```

### 2. Decorator SEO Methods

```ruby
class ListingDecorator < Draper::Decorator
  delegate_all

  def seo_title
    "#{object.title} | #{Current.tenant.title}"
  end

  def seo_description
    return object.ai_summaries&.dig('medium') if object.ai_summaries&.dig('medium')&.present?
    return object.description.truncate(160) if object.description.present?

    t('pages.listings.default_description', tenant: Current.tenant.title)
  end

  def structured_data
    {
      "@context": "https://schema.org",
      "@type": "Article",
      "headline": object.title,
      "description": object.description,
      "image": object.image_url,
      "datePublished": object.published_at&.iso8601,
      "dateModified": object.updated_at&.iso8601,
      "author": {
        "@type": "Organization",
        "name": Current.tenant.title,
        "url": h.root_url
      },
      "publisher": {
        "@type": "Organization",
        "name": Current.tenant.title,
        "logo": {
          "@type": "ImageObject",
          "url": Current.tenant.logo_url
        }
      },
      "mainEntityOfPage": {
        "@type": "WebPage",
        "@id": h.listing_url(object)
      }
    }
  end
end
```

### 3. View Helpers for SEO

```ruby
module ApplicationHelper
  def structured_data(data)
    content_tag :script, data.to_json.html_safe, type: 'application/ld+json'
  end

  def tenant_meta_tags
    set_meta_tags(
      site: Current.tenant.title,
      title: Current.tenant.title,
      description: Current.tenant.description,
      keywords: Current.tenant.keywords,
      canonical: root_url,
      og: {
        site_name: Current.tenant.title,
        title: Current.tenant.title,
        description: Current.tenant.description,
        image: Current.tenant.logo_url,
        url: root_url
      }
    )
  end

  def page_meta_tags(title:, description:, **options)
    set_meta_tags(
      title: title,
      description: description,
      canonical: request.original_url,
      **options
    )
  end
end
```

### 4. Sitemap Generation

```ruby
# app/controllers/sitemaps_controller.rb
class SitemapsController < ApplicationController
  def show
    @urls = sitemap_urls

    respond_to do |format|
      format.xml { render layout: false }
    end
  end

  private

  def sitemap_urls
    urls = []

    # Add home page
    urls << {
      loc: root_url,
      lastmod: Current.tenant.updated_at,
      changefreq: 'daily',
      priority: '1.0'
    }

    # Add listings
    Current.tenant.listings.published.includes(:category).find_each do |listing|
      urls << {
        loc: listing_url(listing),
        lastmod: listing.updated_at,
        changefreq: 'weekly',
        priority: '0.8'
      }
    end

    # Add categories
    Current.tenant.categories.each do |category|
      urls << {
        loc: category_url(category),
        lastmod: category.updated_at,
        changefreq: 'weekly',
        priority: '0.6'
      }
    end

    urls
  end
end
```

### 5. Sitemap View Template

```xml
<!-- app/views/sitemaps/show.xml.erb -->
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <% @urls.each do |url| %>
    <url>
      <loc><%= url[:loc] %></loc>
      <lastmod><%= url[:lastmod].xmlschema %></lastmod>
      <changefreq><%= url[:changefreq] %></changefreq>
      <priority><%= url[:priority] %></priority>
    </url>
  <% end %>
</urlset>
```

## SEO Performance Testing

### Page Speed Testing

```ruby
# spec/performance/seo_performance_spec.rb
RSpec.describe "SEO Performance", type: :performance do
  let(:listing) { create(:listing, :published) }

  it "loads listing pages quickly for SEO" do
    expect { get listing_path(listing) }.to perform_under(200).ms

    # Check critical SEO elements are present
    expect(response.body).to include('<title>')
    expect(response.body).to include('meta name="description"')
    expect(response.body).to include('link rel="canonical"')
  end

  it "generates sitemap efficiently" do
    create_list(:listing, 100, :published)

    expect { get sitemap_path(format: :xml) }.to perform_under(500).ms
  end
end
```

### SEO Audit Helpers

```ruby
# spec/support/seo_helpers.rb
module SEOHelpers
  def have_meta_description(content = nil)
    if content
      have_selector("meta[name='description'][content='#{content}']", visible: false)
    else
      have_selector("meta[name='description']", visible: false)
    end
  end

  def have_meta_property(property, content: nil)
    selector = "meta[property='#{property}']"
    selector += "[content='#{content}']" if content
    have_selector(selector, visible: false)
  end

  def have_meta_name(name, content: nil)
    selector = "meta[name='#{name}']"
    selector += "[content='#{content}']" if content
    have_selector(selector, visible: false)
  end

  def have_structured_data(type)
    have_selector("script[type='application/ld+json']", visible: false, text: /\"@type\":\s*\"#{type}\"/)
  end
end

RSpec.configure do |config|
  config.include SEOHelpers, type: :system
  config.include SEOHelpers, type: :feature
end
```

## SEO Quality Gates

### Mandatory SEO Checks:
1. **Meta Tags**: Title, description, canonical URL on all pages
2. **Open Graph**: Social media sharing optimization
3. **Twitter Cards**: Rich Twitter preview support
4. **Structured Data**: JSON-LD schema markup for content
5. **XML Sitemap**: Auto-generated and up-to-date
6. **Robots.txt**: Proper crawler directives
7. **Canonical URLs**: Prevent duplicate content issues
8. **Performance**: Fast loading times for better rankings

### SEO Testing Commands:

```bash
# Run SEO-specific tests
bundle exec rspec spec/system/seo/
bundle exec rspec spec/requests/sitemaps_spec.rb
bundle exec rspec spec/requests/robots_spec.rb

# Validate XML sitemaps
curl -s "http://localhost:3000/sitemap.xml" | xmllint --format -

# Check meta tags
curl -s "http://localhost:3000/" | grep -E "<title>|meta.*description|meta.*og:"
```

This comprehensive SEO implementation ensures that all tenant content is properly optimized for search engines and social media sharing.