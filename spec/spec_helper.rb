ENV["RAILS_ENV"] ||= "test"

require "simplecov"
SimpleCov.start "rails"

# require "simplecov_json_formatter"
# SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter

require "rubygems"

Bundler.require(:default, :test)
require "bundler/setup"

require_relative "../lib/pulsar-job-rails"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.allow_message_expectations_on_nil = true
  end
end
