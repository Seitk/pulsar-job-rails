# frozen_string_literal: true

require "active_support/concern"

module PulsarJob
  module Asyncable
    extend ActiveSupport::Concern

    def self.wrap(klass, method, async_options = {})
      klass = klass.constantize if klass.is_a?(String) || klass.is_a?(Symbol)
      PulsarJob::Async::Wrapper.new(klass).tap do |wrapper|
        wrapper._method = method
        wrapper.set(async_options)

        if klass.method_defined?(method)
          # Instance method
          klass.send(:alias_method, "#{method}_without_async", method)
          klass.send(:define_method, method) do |*args|
            wrapper.instance = self
            wrapper.enqueue(method, args)
          end
        else
          # Static method
          klass.singleton_class.send(:alias_method, "#{method}_without_async", method)
          klass.singleton_class.send(:define_method, method) do |*args|
            wrapper.enqueue(method, args)
          end
        end
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
