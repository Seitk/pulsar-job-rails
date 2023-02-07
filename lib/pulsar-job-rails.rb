# frozen_string_literal: true

require "pulsar-job-rails/version"
require "pulsar-job-rails/configuration"
require "pulsar-job-rails/cli"
require "pulsar-job-rails/client"
require "pulsar-job-rails/callbacks"
require "pulsar-job-rails/consumer"
require "pulsar-job-rails/producer"
require "pulsar-job-rails/base"
require "pulsar-job-rails/async/options"
require "pulsar-job-rails/async/wrapper"
require "pulsar-job-rails/asyncable"

module PulsarJob
  class << self
    delegate :logger, to: :configuration

    def configure(&block)
      yield(configuration)
      configuration
    end

    def configuration
      @_configuration ||= Configuration.new
    end
  end
end
