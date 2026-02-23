# frozen_string_literal: true

require "logger"

module Botiasloop
  module Logger
    class << self
      def logger
        @logger ||= create_logger
      end

      def debug(msg)
        logger.debug(msg)
      end

      def info(msg)
        logger.info(msg)
      end

      def warn(msg)
        logger.warn(msg)
      end

      def error(msg)
        logger.error(msg)
      end

      private

      def create_logger
        level = begin
          config = Botiasloop::Config.new
          ::Logger.const_get(config.log_level.to_s.upcase)
        rescue
          ::Logger::INFO
        end

        log = ::Logger.new($stderr)
        log.level = level
        log.formatter = proc { |_severity, _datetime, _progname, msg| "#{msg}\n" }
        log
      end
    end
  end
end
