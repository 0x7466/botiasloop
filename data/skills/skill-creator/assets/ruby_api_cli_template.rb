#!/usr/bin/env ruby
# frozen_string_literal: true

# API Client Template
# Copy this template when creating API client scripts for skills
# Customize based on specific API documentation

require "optparse"
require "json"
require "net/http"
require "uri"

# Configuration
BASE_URL = ENV.fetch("API_BASE_URL", "https://api.example.com")
API_KEY = ENV["API_KEY"]

# Command-line options
options = {
  verbose: false,
  endpoint: nil,
  method: "GET",
  data: nil,
  params: {}
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: api_client.rb [options]"
  opts.separator ""
  opts.separator "Options:"

  opts.on("-e", "--endpoint ENDPOINT", "API endpoint path (e.g., /users)") do |e|
    options[:endpoint] = e
  end

  opts.on("-m", "--method METHOD", "HTTP method (GET, POST, PUT, DELETE)") do |m|
    options[:method] = m.upcase
  end

  opts.on("-d", "--data DATA", "JSON data for POST/PUT requests") do |d|
    options[:data] = d
  end

  opts.on("-p", "--param KEY=VALUE", "Query parameters (can be used multiple times)") do |param|
    key, value = param.split("=", 2)
    options[:params][key] = value
  end

  opts.on("-v", "--verbose", "Enable verbose output") do
    options[:verbose] = true
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit 0
  end
end

begin
  parser.parse!
rescue OptionParser::InvalidOption => e
  warn "Error: #{e.message}"
  warn "Use --help for usage information"
  exit 1
end

# Validate required options
unless options[:endpoint]
  warn "Error: --endpoint is required"
  warn "Use --help for usage information"
  exit 1
end

# Validate API key
unless API_KEY
  warn "Error: API_KEY environment variable is required"
  warn "Example: API_KEY=xxx ./api_client.rb --endpoint /users"
  exit 1
end

# Build URI
uri = URI.parse("#{BASE_URL}#{options[:endpoint]}")
uri.query = URI.encode_www_form(options[:params]) unless options[:params].empty?

# Create HTTP request
request = case options[:method]
when "GET"
  Net::HTTP::Get.new(uri)
when "POST"
  req = Net::HTTP::Post.new(uri)
  req.body = options[:data] if options[:data]
  req["Content-Type"] = "application/json" if options[:data]
  req
when "PUT"
  req = Net::HTTP::Put.new(uri)
  req.body = options[:data] if options[:data]
  req["Content-Type"] = "application/json" if options[:data]
  req
when "DELETE"
  Net::HTTP::Delete.new(uri)
else
  warn "Error: Unsupported HTTP method: #{options[:method]}"
  exit 1
end

# Set headers
request["Authorization"] = "Bearer #{API_KEY}"
request["Accept"] = "application/json"
request["User-Agent"] = "BotiasLoop-Skill/1.0"

# Debug output
if options[:verbose]
  warn "Request: #{options[:method]} #{uri}"
  warn "Headers:"
  request.each_header { |k, v| warn "  #{k}: #{v}" }
  warn "Body: #{options[:data]}" if options[:data]
  warn ""
end

# Execute request
begin
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 10
  http.read_timeout = 30

  response = http.request(request)

  # Debug response
  if options[:verbose]
    warn "Response: #{response.code} #{response.message}"
    warn "Headers:"
    response.each_header { |k, v| warn "  #{k}: #{v}" }
    warn ""
  end

  # Output response body
  puts response.body

  # Exit with non-zero code on HTTP errors
  exit 1 unless response.is_a?(Net::HTTPSuccess)
rescue SocketError, Net::OpenTimeout, Net::ReadTimeout => e
  warn "Error: Network error - #{e.message}"
  exit 1
rescue JSON::ParserError => e
  warn "Error: Failed to parse response as JSON - #{e.message}"
  puts response.body # Still output raw body
  exit 1
rescue => e
  warn "Error: #{e.class} - #{e.message}"
  exit 1
end
