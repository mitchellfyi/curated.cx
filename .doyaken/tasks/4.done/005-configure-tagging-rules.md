# Configure Tagging Rules for Content Classification

## Description

Set up TaggingRules per tenant to automatically classify ingested content into categories (news, tools, articles, jobs, tutorials, etc.)

## Acceptance Criteria

- [ ] Create Taxonomy records for each content type
- [ ] Create TaggingRule records with keyword/regex patterns
- [ ] Configure rules for: news, tools, tutorials, jobs, events
- [ ] Test tagging accuracy on sample content

## Taxonomy Structure

```ruby
# Per tenant taxonomies
Taxonomy.create!(site: site, slug: "news", name: "News")
Taxonomy.create!(site: site, slug: "tools", name: "Tools & Apps")
Taxonomy.create!(site: site, slug: "tutorials", name: "Tutorials")
Taxonomy.create!(site: site, slug: "jobs", name: "Jobs")
Taxonomy.create!(site: site, slug: "events", name: "Events")
```

## Rule Examples

```ruby
# Match tools/apps
TaggingRule.create!(
  site: site,
  taxonomy: tools_taxonomy,
  rule_type: :keyword_match,
  pattern: "tool|app|software|platform|API|SDK",
  priority: 10,
  enabled: true
)

# Match job postings
TaggingRule.create!(
  site: site,
  taxonomy: jobs_taxonomy,
  rule_type: :keyword_match,
  pattern: "hiring|job|career|position|salary|remote work",
  priority: 10,
  enabled: true
)
```

## Priority

medium

## Labels

feature, tagging, setup
