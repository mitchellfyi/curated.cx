# Ensure Devise mapping is available in controller specs
RSpec.configure do |config|
  config.before(:each, type: :controller) do
    request.env["devise.mapping"] = Devise.mappings[:user]
  end
end
