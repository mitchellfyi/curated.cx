---
$schema: dk://schemas/v1/prompt
id: code.review
title: Code Review
description: Comprehensive code review focusing on quality, security, and best practices
tags: [code, review, quality]
---

# Code Review Prompt

Review the codebase systematically for:

## Quality Checks
- Code style consistency (RuboCop compliance)
- SOLID principles adherence
- Proper abstraction layers (services, decorators, jobs)
- Test coverage and quality
- i18n compliance (no hardcoded strings)

## Security Review
- Authentication and authorization checks
- Multi-tenant isolation verification
- SQL injection prevention
- XSS prevention
- Input validation

## Performance Analysis
- N+1 query detection
- Database query optimization
- Caching opportunities
- Asset optimization

## Architecture Review
- Controller simplicity (business logic in services)
- Model responsibilities
- Decorator usage for presentation
- Job usage for background processing

## Code Smells
- Duplication (DRY violations)
- Long methods/classes
- Complex conditionals
- Magic numbers/strings

Provide specific, actionable feedback with file paths and line numbers.
