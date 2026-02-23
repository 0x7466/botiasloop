# frozen_string_literal: true

require "open3"
require_relative "../tool"

module Botiasloop
  module Tools
    class Shell < Tool
      description "Execute a shell command and return the output"
      param :command, type: :string, desc: "The shell command to execute", required: true

      # Execute a shell command
      #
      # @param command [String] Shell command to execute
      # @return [Hash] Result with stdout, stderr, exit_code, and success?
      # @raise [Botiasloop::Error] When command execution fails
      def execute(command:)
        stdout, stderr, status = Open3.capture3(command)
        Result.new(stdout, stderr, status.exitstatus).to_h
      rescue Errno::ENOENT => e
        raise Error, "Command not found: #{e.message}"
      rescue Errno::EACCES => e
        raise Error, "Permission denied: #{e.message}"
      end

      # Result wrapper for shell execution
      class Result
        attr_reader :stdout, :stderr, :exit_code

        def initialize(stdout, stderr, exit_code)
          @stdout = stdout
          @stderr = stderr
          @exit_code = exit_code
        end

        def success?
          @exit_code == 0
        end

        def to_s
          "Exit: #{@exit_code}\nStdout:\n#{@stdout}\nStderr:\n#{@stderr}"
        end

        def to_h
          {
            stdout: @stdout,
            stderr: @stderr,
            exit_code: @exit_code,
            success?: success?
          }
        end
      end
    end
  end
end
