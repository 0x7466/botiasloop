# frozen_string_literal: true

require_relative "botiasloop/version"
require_relative "botiasloop/config"
require_relative "botiasloop/conversation"
require_relative "botiasloop/tools/registry"
require_relative "botiasloop/tools/shell"
require_relative "botiasloop/tools/web_search"
require_relative "botiasloop/commands"
require_relative "botiasloop/loop"
require_relative "botiasloop/agent"
require_relative "botiasloop/channels"
require_relative "botiasloop/channels/base"
require_relative "botiasloop/channels/cli"
require_relative "botiasloop/channels/telegram"

module Botiasloop
  class Error < StandardError; end

  class MaxIterationsExceeded < Error
    attr_reader :max_iterations

    def initialize(max_iterations)
      @max_iterations = max_iterations
      super("I've reached my thinking limit (#{max_iterations} iterations). Please try a more specific question.")
    end
  end
end
