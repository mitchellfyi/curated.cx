# frozen_string_literal: true

# Helper for generating JSON-LD structured data for SEO
# https://developers.google.com/search/docs/advanced/structured-data
#
module StructuredDataHelper
  # Render JSON-LD script tag
  def json_ld_tag(data)
    tag.script(data.to_json.html_safe, type: "application/ld+json")
  end

  # Organization schema for the tenant/site
  def organization_schema
    tenant = Current.tenant&.decorate
    return {} unless tenant

    {
      "@context": "https://schema.org",
      "@type": "Organization",
      "name": tenant.title,
      "url": root_url,
      "logo": tenant.social_image_url
    }.compact
  end

  # WebSite schema with SearchAction
  def website_schema
    tenant = Current.tenant&.decorate
    return {} unless tenant

    {
      "@context": "https://schema.org",
      "@type": "WebSite",
      "name": tenant.title,
      "url": root_url,
      "potentialAction": {
        "@type": "SearchAction",
        "target": {
          "@type": "EntryPoint",
          "urlTemplate": "#{search_url}?q={search_term_string}"
        },
        "query-input": "required name=search_term_string"
      }
    }
  end

  # BreadcrumbList schema
  def breadcrumb_schema(items)
    return {} if items.blank?

    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      "itemListElement": items.map.with_index(1) do |item, position|
        {
          "@type": "ListItem",
          "position": position,
          "name": item[:name],
          "item": item[:url]
        }
      end
    }
  end

  # Article schema for feed entries
  def article_schema(content_item)
    return {} unless content_item

    tenant = Current.tenant&.decorate

    {
      "@context": "https://schema.org",
      "@type": "Article",
      "headline": content_item.title,
      "description": content_item.ai_summary.presence || content_item.description,
      "image": content_item.image_url,
      "datePublished": content_item.published_at&.iso8601,
      "dateModified": content_item.updated_at&.iso8601,
      "author": {
        "@type": "Organization",
        "name": content_item.source&.title || tenant&.title
      },
      "publisher": {
        "@type": "Organization",
        "name": tenant&.title,
        "logo": {
          "@type": "ImageObject",
          "url": tenant&.social_image_url
        }
      },
      "mainEntityOfPage": {
        "@type": "WebPage",
        "@id": content_item.url_canonical
      }
    }.compact_blank
  end

  # SoftwareApplication schema for tool listings
  def software_schema(listing)
    return {} unless listing&.tool?

    {
      "@context": "https://schema.org",
      "@type": "SoftwareApplication",
      "name": listing.title,
      "description": listing.description,
      "image": listing.image_url,
      "url": listing.url_canonical,
      "applicationCategory": listing.category&.name,
      "offers": listing.paid? ? {
        "@type": "Offer",
        "price": "0",
        "priceCurrency": "USD"
      } : nil
    }.compact_blank
  end

  # JobPosting schema for job listings
  def job_posting_schema(listing)
    return {} unless listing&.job?

    {
      "@context": "https://schema.org",
      "@type": "JobPosting",
      "title": listing.title,
      "description": listing.description || listing.body_text,
      "datePosted": listing.published_at&.iso8601,
      "validThrough": listing.expires_at&.iso8601,
      "hiringOrganization": {
        "@type": "Organization",
        "name": listing.company.presence || listing.site_name,
        "sameAs": listing.url_canonical
      },
      "jobLocation": listing.location.present? ? {
        "@type": "Place",
        "address": {
          "@type": "PostalAddress",
          "addressLocality": listing.location
        }
      } : nil,
      "baseSalary": listing.salary_range.present? ? {
        "@type": "MonetaryAmount",
        "currency": "USD",
        "value": {
          "@type": "QuantitativeValue",
          "value": listing.salary_range
        }
      } : nil,
      "employmentType": "FULL_TIME"
    }.compact_blank
  end

  # Product schema for service listings
  def product_schema(listing)
    return {} unless listing&.service?

    {
      "@context": "https://schema.org",
      "@type": "Product",
      "name": listing.title,
      "description": listing.description,
      "image": listing.image_url,
      "url": listing.url_canonical,
      "category": listing.category&.name,
      "brand": {
        "@type": "Brand",
        "name": listing.company.presence || listing.site_name
      }
    }.compact_blank
  end

  # Get appropriate schema for a listing based on type
  def listing_schema(listing)
    case listing.listing_type
    when "tool"
      software_schema(listing)
    when "job"
      job_posting_schema(listing)
    when "service"
      product_schema(listing)
    else
      {}
    end
  end

  # ItemList schema for category pages
  def item_list_schema(items, list_name:)
    return {} if items.blank?

    {
      "@context": "https://schema.org",
      "@type": "ItemList",
      "name": list_name,
      "numberOfItems": items.size,
      "itemListElement": items.map.with_index(1) do |item, position|
        {
          "@type": "ListItem",
          "position": position,
          "url": item.respond_to?(:url_canonical) ? item.url_canonical : listing_url(item)
        }
      end
    }
  end
end
