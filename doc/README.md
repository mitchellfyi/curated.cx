# Documentation Index for Curated.www

## 📚 Complete Documentation Guide

This directory contains comprehensive documentation for the Curated.www Rails 8 multi-tenant curation platform.

## 🎯 Quick Start

1. **New Developer?** Start with [README.md](../README.md)
2. **Making Changes?** Review [AGENTS.md](../AGENTS.md) principles
3. **Quality Focused?** Read [QUALITY_ENFORCEMENT.md](QUALITY_ENFORCEMENT.md)
4. **Working on Features?** Check [TODO.md](../TODO.md) roadmap

## 📖 Core Documentation

### Development Guidelines
- **[AGENTS.md](../AGENTS.md)** - Core development principles and quality enforcement
- **[README.md](../README.md)** - Project overview, setup, and development tools
- **[TODO.md](../TODO.md)** - Detailed roadmap and implementation tasks
- **[SPECIFICATION_V0.md](../SPECIFICATION_V0.md)** - Complete technical specification

### Quality Standards
- **[QUALITY_ENFORCEMENT.md](QUALITY_ENFORCEMENT.md)** - Comprehensive quality standards and enforcement
- **[CI_CD_QUALITY.md](CI_CD_QUALITY.md)** - CI/CD workflows and automated quality gates
- **[SAFE_MIGRATIONS.md](SAFE_MIGRATIONS.md)** - Database migration safety guide
- **[SEO_TESTING.md](SEO_TESTING.md)** - SEO optimization and testing standards

### GitHub Integration
- **[.github/copilot-instructions.md](../.github/copilot-instructions.md)** - GitHub Copilot configuration
- **[.github/workflows/ci.yml](../.github/workflows/ci.yml)** - Comprehensive CI/CD pipeline

## 🛠️ Development Tools

### Quality Scripts
```bash
./script/dev/quality        # Master quality enforcement script
./script/dev/i18n          # Internationalization checks
./script/dev/migrations     # Database migration safety
./script/dev/accessibility  # Accessibility testing
./script/dev/setup         # Development environment setup
```

### Pre-commit Integration
- **[.git/hooks/pre-commit](../.git/hooks/pre-commit)** - Automated quality enforcement before commits

## 🏗️ Architecture Documentation

### Multi-tenancy
- Shared schema with row-level isolation via `tenant_id`
- Host-based tenant resolution (domain/subdomain routing)
- Comprehensive tenant isolation at database and application levels
- Acts-as-tenant integration with proper scoping

### Quality Architecture
- **12 Quality Gates**: All must pass for any code change
- **Zero Tolerance**: No exceptions, workarounds, or "temporary" bypasses
- **Automated Enforcement**: CI/CD pipeline with comprehensive checks
- **Documentation First**: Quality standards clearly documented

### Technology Stack
- **Rails 8.0.3** with modern defaults (Solid Cache, Solid Queue)
- **PostgreSQL** with full-text search and proper indexing
- **Hotwire** (Turbo + Stimulus) for modern frontend interactions
- **Tailwind CSS** for responsive, accessible styling
- **RSpec** with 80% minimum coverage and comprehensive test types

## 📊 Quality Metrics & Monitoring

### Critical Quality Gates
1. ✅ **RuboCop** (rails-omakase) - Zero violations + SOLID principles
2. ✅ **Brakeman** - Zero high/medium security issues
3. ✅ **RSpec** - 100% passing, 80% coverage minimum + Test Pyramid
4. ✅ **Route Testing** - Every route must have corresponding tests
5. ✅ **i18n-tasks** - Zero missing translations
6. ✅ **ERB Lint** - Template compliance
7. ✅ **SEO Optimization** - Meta tags, structured data, XML sitemaps
8. ✅ **Accessibility** - WCAG 2.1 AA compliance
9. ✅ **Performance** - No N+1 queries
10. ✅ **Strong Migrations** - Safe database changes
11. ✅ **Bundle Audit** - Zero security vulnerabilities
12. ✅ **Database** - Proper indexes and constraints
7. ✅ **Performance** - No N+1 queries
8. ✅ **Strong Migrations** - Safe database changes
9. ✅ **Bundle Audit** - Zero security vulnerabilities
10. ✅ **Database** - Proper indexes and constraints

### Monitoring Dashboard
- Local quality metrics: `./script/dev/quality`
- CI/CD results: GitHub Actions with detailed artifacts
- Coverage reports: SimpleCov with 80% minimum threshold
- Security scanning: Brakeman with zero tolerance policy

## 🔒 Security & Compliance

### Security Standards
- **Brakeman**: Continuous security vulnerability scanning
- **Bundle Audit**: Dependency security monitoring
- **Strong Migrations**: Database security for production deployments
- **Multi-tenant Isolation**: Secure tenant data separation

### Compliance Features
- **WCAG 2.1 AA**: Accessibility compliance with axe-core testing
- **i18n Ready**: Complete internationalization support
- **Data Protection**: Secure tenant isolation and data handling
- **Audit Trail**: Comprehensive logging and monitoring

## 🚀 Deployment & Operations

### Production Readiness
- **Zero Downtime Deployments**: Safe migration strategies
- **Performance Monitoring**: N+1 detection and optimization
- **Error Tracking**: Comprehensive error handling and logging
- **Scalability**: Multi-tenant architecture designed for growth

### Operational Excellence
- **Monitoring**: Comprehensive quality and performance metrics
- **Alerting**: Automated notifications for quality or security issues
- **Documentation**: Living documentation that evolves with codebase
- **Training**: Clear onboarding and continuous learning resources

## 📈 Continuous Improvement

### Quality Evolution
- **Regular Reviews**: Weekly quality metric analysis
- **Tool Updates**: Monthly tool and standard updates
- **Best Practices**: Quarterly best practice reviews
- **Team Training**: Ongoing education and skill development

### Documentation Maintenance
- **Living Docs**: Documentation updated with every change
- **Version Control**: All documentation version controlled
- **Review Process**: Regular documentation review and improvement
- **Feedback Loop**: Developer feedback incorporated continuously

## 🤝 Contributing

### Development Workflow
1. **Understand Standards**: Review quality documentation thoroughly
2. **Plan Changes**: Consider quality impact in all planning
3. **Implement Safely**: Make smallest possible changes
4. **Verify Quality**: Run `./script/dev/quality` before committing
5. **Document Changes**: Update relevant documentation
6. **Review Process**: Comprehensive code review with quality focus

### Quality First Culture
- **No Shortcuts**: Quality is never compromised for speed
- **Shared Responsibility**: Every team member enforces quality
- **Continuous Learning**: Stay updated with best practices
- **Proactive Improvement**: Identify and fix quality issues early

## 📞 Getting Help

### Troubleshooting
1. **Quality Issues**: See specific tool documentation in quality scripts
2. **Migration Problems**: Review [SAFE_MIGRATIONS.md](SAFE_MIGRATIONS.md)
3. **CI/CD Failures**: Check [CI_CD_QUALITY.md](CI_CD_QUALITY.md)
4. **Architecture Questions**: Refer to [SPECIFICATION_V0.md](../SPECIFICATION_V0.md)

### Resources
- **Internal**: Check existing codebase patterns and tests
- **Tools**: Each quality tool has comprehensive help documentation
- **Community**: Rails, RSpec, and accessibility communities
- **Standards**: WCAG 2.1, Rails guides, Ruby style guides

## 🎯 Success Metrics

### Quality Indicators
- **Test Coverage**: Maintained above 80% consistently
- **Security Issues**: Zero high/medium severity issues
- **Performance**: All response times under thresholds
- **Accessibility**: Full WCAG 2.1 AA compliance
- **i18n Completeness**: Zero missing translation keys

### Development Velocity
- **Quality First**: No technical debt accumulation
- **Confident Changes**: High test coverage enables safe refactoring
- **Automated Feedback**: Fast CI/CD pipeline with comprehensive checks
- **Clear Standards**: Documented expectations eliminate confusion

Remember: **Quality is not optional**. Every change must meet these standards to maintain the integrity and maintainability of the Curated.www platform.