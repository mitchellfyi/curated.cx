# Factory Bot configuration for RSpec
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Lint factories for duplicated attributes and invalid factory definitions
  # Disabled due to pre-existing jsonb_field recursion issues in other models
  # config.before(:suite) do
  #   begin
  #     FactoryBot.lint
  #   rescue SystemExit
  #     # Factory Bot lint failures result in an exit code
  #     # We want the suite to continue running in test mode
  #   end
  # end
end
