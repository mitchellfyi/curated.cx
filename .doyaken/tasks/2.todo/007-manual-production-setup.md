# Manual: Production Setup for Content Ingestion

## Description

Manual steps required to enable automated content ingestion on production.

## Steps

### 1. Set SerpAPI Key

Add your SerpAPI key to production credentials or environment:

```bash
# Option A: Rails credentials
EDITOR=vim rails credentials:edit --environment production
# Add: serpapi_key: "your-key-here"

# Option B: Environment variable
# In your deployment config (Kamal, Dokku, etc.):
SERPAPI_KEY=your-key-here
```

Get key from: https://serpapi.com/manage-api-key

### 2. Run Database Seeds

```bash
# SSH to production
rails db:seed

# Or via Kamal:
kamal app exec "rails db:seed"
```

### 3. Verify Sources Created

```bash
rails console
Source.count  # Should be 6 (2 per tenant)
Source.pluck(:name, :enabled)
```

### 4. Monitor First Run

After 15 minutes, check:
```bash
rails console
ImportRun.last(10)
ContentItem.count
```

## Priority

high

## Labels

manual, production, setup
