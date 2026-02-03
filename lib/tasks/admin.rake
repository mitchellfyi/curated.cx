# frozen_string_literal: true

namespace :admin do
  desc "Show system stats"
  task stats: :environment do
    puts "=" * 50
    puts "System Statistics"
    puts "=" * 50

    puts "\n📊 Content:"
    puts "  Content Items: #{ContentItem.count}"
    puts "  Listings: #{Listing.count}"
    puts "  Notes: #{Note.count}"
    puts "  Comments: #{Comment.count}"

    puts "\n👥 Users:"
    puts "  Total: #{User.count}"
    puts "  Admins: #{User.admins.count}"
    puts "  Created this week: #{User.where('created_at > ?', 1.week.ago).count}"

    puts "\n🏢 Infrastructure:"
    puts "  Tenants: #{Tenant.count}"
    puts "  Sites: #{Site.count}"
    puts "  Sources: #{Source.count} (#{Source.enabled.count} enabled)"

    puts "\n📥 Imports:"
    puts "  Total runs: #{ImportRun.count}"
    puts "  Last 24h: #{ImportRun.where('started_at > ?', 24.hours.ago).count}"
    puts "  Failed (24h): #{ImportRun.failed.where('started_at > ?', 24.hours.ago).count}"

    puts "\n🤖 AI Processing:"
    puts "  Editorialisations: #{Editorialisation.count}"
    puts "  Completed: #{Editorialisation.completed.count}"
    puts "  Failed: #{Editorialisation.failed.count}"
    puts "  Pending: #{Editorialisation.pending.count}"

    puts "\n🚨 Moderation:"
    puts "  Open flags: #{Flag.open.count}"
    puts "  Pending submissions: #{Submission.pending.count}"

    puts "=" * 50
  end

  desc "Retry all failed editorialisations"
  task retry_failed_editorialisations: :environment do
    failed = Editorialisation.failed
    count = failed.count

    if count.zero?
      puts "No failed editorialisations to retry."
      next
    end

    puts "Retrying #{count} failed editorialisations..."

    failed.find_each do |ed|
      EditorialiseContentItemJob.perform_later(ed.content_item_id)
      print "."
    end

    puts "\nQueued #{count} items for retry."
  end

  desc "Clean up old import runs (default: older than 30 days)"
  task :clean_import_runs, [ :days ] => :environment do |_t, args|
    days = (args[:days] || 30).to_i
    cutoff = days.days.ago

    old_runs = ImportRun.where("created_at < ?", cutoff)
    count = old_runs.count

    if count.zero?
      puts "No import runs older than #{days} days."
      next
    end

    puts "Deleting #{count} import runs older than #{days} days..."
    old_runs.delete_all
    puts "Done."
  end

  desc "Clean up orphaned records"
  task clean_orphans: :environment do
    puts "Checking for orphaned records..."

    # Content items without sources
    orphaned_content = ContentItem.left_joins(:source).where(sources: { id: nil })
    if orphaned_content.any?
      puts "  Found #{orphaned_content.count} content items without sources"
    end

    # Editorialisations without content items
    orphaned_eds = Editorialisation.left_joins(:content_item).where(content_items: { id: nil })
    if orphaned_eds.any?
      puts "  Found #{orphaned_eds.count} editorialisations without content items"
      puts "  Deleting orphaned editorialisations..."
      orphaned_eds.delete_all
    end

    # Comments on deleted records
    orphaned_comments = Comment.where(commentable_id: nil)
    if orphaned_comments.any?
      puts "  Found #{orphaned_comments.count} orphaned comments"
    end

    puts "Done."
  end

  desc "Verify data integrity"
  task verify_integrity: :environment do
    puts "Verifying data integrity..."
    issues = []

    # Check tenant/site consistency
    ContentItem.includes(:site).find_each do |item|
      if item.site && item.respond_to?(:tenant_id) && item.site.tenant_id != item.tenant_id
        issues << "ContentItem #{item.id}: site.tenant_id mismatch"
      end
    end

    # Check source/site consistency
    Source.includes(:site).find_each do |source|
      if source.site && source.site.tenant_id != source.tenant_id
        issues << "Source #{source.id}: site.tenant_id mismatch"
      end
    end

    if issues.empty?
      puts "✓ No integrity issues found."
    else
      puts "Found #{issues.count} issues:"
      issues.first(20).each { |issue| puts "  - #{issue}" }
      puts "  ... and #{issues.count - 20} more" if issues.count > 20
    end
  end

  desc "Make a user an admin by email"
  task :make_admin, [ :email ] => :environment do |_t, args|
    email = args[:email]

    if email.blank?
      puts "Usage: rake admin:make_admin[email@example.com]"
      next
    end

    user = User.find_by(email: email)

    if user.nil?
      puts "User not found: #{email}"
      next
    end

    if user.admin?
      puts "#{email} is already an admin."
    else
      user.add_role(:admin)
      puts "#{email} is now an admin."
    end
  end

  desc "Remove admin role from a user by email"
  task :remove_admin, [ :email ] => :environment do |_t, args|
    email = args[:email]

    if email.blank?
      puts "Usage: rake admin:remove_admin[email@example.com]"
      next
    end

    user = User.find_by(email: email)

    if user.nil?
      puts "User not found: #{email}"
      next
    end

    if user.admin?
      user.remove_role(:admin)
      puts "Removed admin role from #{email}."
    else
      puts "#{email} is not an admin."
    end
  end
end
