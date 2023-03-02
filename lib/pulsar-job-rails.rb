# frozen_string_literal: true

require "pulsar-job-rails/version"
require "pulsar-job-rails/configuration"
require "pulsar-job-rails/cli"
require "pulsar-job-rails/pools"
require "pulsar-job-rails/consume"
require "pulsar-job-rails/produce"
require "pulsar-job-rails/context"
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
