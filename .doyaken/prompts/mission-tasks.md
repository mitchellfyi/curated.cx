---
$schema: dk://schemas/v1/prompt
id: mission.tasks
title: Generate Mission Tasks
description: Create comprehensive task list based on MISSION.md requirements
tags: [mission, tasks, planning]
---

# Generate Mission Tasks

Analyze MISSION.md and the current codebase to create a comprehensive, actionable task list.

## Context

Read MISSION.md to understand the vision and requirements for Curated.cx.

## Current State Analysis

1. Review the codebase to identify what's already implemented:
   - Models (tenants, categories, listings, users)
   - Controllers and routes
   - Services and jobs
   - Views and UI components
   - Background jobs infrastructure
   - Multi-tenant setup

2. Compare against MISSION.md requirements:
   - Content aggregation and ingestion
   - AI enrichment
   - Indexes (tools, services, jobs, events)
   - Community features (submissions, votes, comments)
   - Distribution (email, RSS, social)
   - Search and discovery
   - Monetization features
   - Guardrails and moderation

## Task Generation

Create tasks organized by mission area:

1. **Content Aggregation & Ingestion**
   - Sources model and infrastructure
   - Ingestion jobs (SerpAPI, RSS, etc.)
   - URL normalization
   - Metadata scraping

2. **AI Enrichment**
   - Summarization services
   - Auto-tagging
   - Entity extraction
   - Budget enforcement

3. **Indexes (Monetization Layer)**
   - Tools/apps directory
   - Services directory
   - Professionals directory
   - Companies/products database
   - Jobs board
   - Events directory

4. **Community Layer**
   - User submissions
   - Voting system
   - Comments and discussion
   - Reputation system

5. **Distribution**
   - Email digests
   - RSS feeds
   - Social distribution
   - SEO optimization

6. **Search & Discovery**
   - Full-text search
   - Tagging system
   - Advanced filtering
   - Ranking algorithms

7. **Monetization**
   - Affiliate links
   - Sponsored placements
   - Job post payments
   - Premium listings
   - Membership tiers
   - Lead generation

8. **Guardrails**
   - Source quality controls
   - Anti-gaming measures
   - Moderation tools
   - Attribution and labeling

## Output Format

For each task, provide:
- Clear, actionable description
- Dependencies (what must be done first)
- Estimated complexity (if known)
- Related files/models that need to be created or modified
- Acceptance criteria

Organize tasks in a logical implementation order, prioritizing foundational work first.

Output should be suitable for tracking in a project management tool or TODO system.
