# frozen_string_literal: true

require_relative "commands/context"
require_relative "commands/base"
require_relative "commands/registry"
require_relative "commands/help"
require_relative "commands/status"
require_relative "commands/reset"
require_relative "commands/new"
require_relative "commands/compact"
require_relative "commands/label"
require_relative "commands/conversations"
require_relative "commands/switch"
require_relative "commands/archive"
require_relative "commands/system_prompt"

module Botiasloop
  # Slash commands module
  # Provides a registry-based command system for bot control
  module Commands
  end
end
