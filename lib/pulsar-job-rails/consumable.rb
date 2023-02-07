# frozen_string_literal: true

require 'active_support/concern'

module PulsarJob
  module Consumable
    extend ActiveSupport::Concern

    def self.included(base)
      base.extend ClassMethods
      
      def async
        Async.new(self.class).tap do |wrapper|
          wrapper.instance = self
        end
      end
    end

    module ClassMethods
      def async
        Async.new(self)
      end
    end
  end
end
