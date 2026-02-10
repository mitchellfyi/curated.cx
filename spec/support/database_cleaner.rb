# Database Cleaner configuration for RSpec
RSpec.configure do |config|
  config.before(:suite) do
    # Use :deletion for suite setup to avoid TRUNCATE deadlocks caused by
    # circular FK constraints (comments, notes, taxonomies, discussion_posts).
    # :deletion uses DELETE FROM which takes lighter locks than TRUNCATE.
    DatabaseCleaner.clean_with(:deletion)
  end

  config.before(:each) do |example|
    # Use truncation for tests that need after_commit callbacks to fire
    if example.metadata[:js] || example.metadata[:commit]
      DatabaseCleaner.strategy = :deletion
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
