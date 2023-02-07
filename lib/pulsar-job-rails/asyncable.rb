# frozen_string_literal: true

require 'active_support/concern'

module PulsarJob
  module Asyncable
    extend ActiveSupport::Concern

    def self.wrap(klass, method, async_options = Options.new)
      klass.singleton_class.send(:alias_method, "#{method}_without_async", method)
      klass.singleton_class .send(:define_method, method) do |*args|
        wrapper = PulsarJob::Async::Wrapper.new(self).tap do |job|
          job.options = Options.new({
            klass: klass,
            method: method,
            instance: self,
            args: args,
          })
        end
        wrapper.perform_later
      end
    end

    def self.included(base)
      base.extend ClassMethods
      
      def async
        PulsarJob::Async::Wrapper.new(self.class).tap do |wrapper|
          wrapper.instance = self
        end
      end
    end

    module ClassMethods
      def async
        PulsarJob::Async::Wrapper.new(self)
      end
    end
  end
end
