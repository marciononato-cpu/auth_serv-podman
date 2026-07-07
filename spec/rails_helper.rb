# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

# Limpar cache Redis antes da suíte (rate limits, blacklists)
RSpec.configure do |config|
  config.before(:each) do
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/1'))
      redis.flushdb
    rescue => e
      # Silencioso — se Redis não estiver disponível, rate limit não funciona
    end
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
