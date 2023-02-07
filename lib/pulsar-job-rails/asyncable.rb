# frozen_string_literal: true

require 'active_support/concern'

module PulsarJob
  module Asyncable
    extend ActiveSupport::Concern

    def self.wrap(klass, method, async_options = ::PulsarJob::Async::Options.new)
      klass.singleton_class.send(:alias_method, "#{method}_without_async", method)
      klass.singleton_class .send(:define_method, method) do |*args|
        async = AsyncJob.new(self).tap do |job|
          job.options = ::Pulsar::Async::Options.new({
            klass: klass,
            method: method,
            args: args,
          })
        end
        ::PulsarJob::Producer.publish(async)
      end
    end

    def self.included(base)
      base.extend ClassMethods
      
      def async
        AsyncJob.new(self.class).tap do |wrapper|
          wrapper.instance = self
        end
      end
    end

    module ClassMethods
      def async
        AsyncJob.new(self)
      end
    end
  end
end
