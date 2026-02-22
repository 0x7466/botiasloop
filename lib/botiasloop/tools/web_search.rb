# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require_relative "../tool"

module Botiasloop
  module Tools
    class WebSearch < Tool
      description "Search the web using SearXNG"
      param :query, type: :string, desc: "The search query", required: true

      # Initialize with SearXNG URL
      #
      # @param searxng_url [String] SearXNG instance URL
      def initialize(searxng_url)
        @searxng_url = searxng_url
      end

      # Execute web search
      #
      # @param query [String] Search query
      # @return [Hash] Search results
      # @raise [Error] On HTTP or connection errors
      def execute(query:)
        uri = URI("#{@searxng_url}/search")
        uri.query = URI.encode_www_form("q" => query, "format" => "json")

        response = Net::HTTP.get_response(uri)

        unless response.is_a?(Net::HTTPSuccess)
          raise Error, "Search failed: HTTP #{response.code}"
        end

        data = JSON.parse(response.body)
        Result.new(data["results"] || []).to_h
      rescue Errno::ECONNREFUSED => e
        raise Error, "Search failed: #{e.message}"
      rescue JSON::ParserError => e
        raise Error, "Search failed: Invalid JSON response - #{e.message}"
      end

      # Result wrapper for search results
      class Result
        attr_reader :results

        def initialize(results)
          @results = results
        end

        def to_s
          @results.map do |r|
            "#{r["title"]}\n#{r["url"]}\n#{r["content"]}"
          end.join("\n\n")
        end

        def to_h
          {results: @results}
        end
      end
    end
  end
end
