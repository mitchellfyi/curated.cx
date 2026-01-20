---
$schema: dk://schemas/v1/prompt
id: code.optimize
title: Code Optimization
description: Optimize code for performance, maintainability, and best practices
tags: [code, optimize, performance]
---

# Code Optimization Prompt

Optimize the codebase focusing on:

## Performance Optimization
- Database query optimization (eager loading, select specific columns)
- N+1 query elimination
- Caching strategy implementation
- Asset pipeline optimization
- Background job usage for heavy operations

## Code Quality Optimization
- Refactor long methods into smaller, focused methods
- Extract complex logic into service objects
- Improve test coverage and speed
- Reduce duplication through shared code
- Simplify complex conditionals

## Rails Best Practices
- Use proper Rails conventions
- Leverage Rails helpers and built-ins
- Optimize ActiveRecord queries
- Use appropriate Rails callbacks (judiciously)
- Implement proper error handling

## Security Optimization
- Strengthen authorization checks
- Improve input validation
- Add rate limiting where needed
- Secure sensitive data handling
- Review and improve CSRF protection

## Maintainability
- Improve code readability
- Add missing documentation
- Standardize code patterns
- Improve error messages
- Enhance logging for debugging

Make incremental improvements that can be tested and committed individually.
