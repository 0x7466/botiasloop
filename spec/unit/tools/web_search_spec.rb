# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe Botiasloop::Tools::WebSearch do
  let(:searxng_url) { "http://localhost:8080" }
  let(:tool) { described_class.new(searxng_url) }

  describe "#execute" do
    context "with successful response" do
      let(:search_results) do
        {
          "results" => [
            {"title" => "Result 1", "url" => "http://example.com/1", "content" => "Content 1"},
            {"title" => "Result 2", "url" => "http://example.com/2", "content" => "Content 2"}
          ]
        }
      end

      before do
        stub_request(:get, "#{searxng_url}/search")
          .with(query: {"q" => "ruby programming", "format" => "json"})
          .to_return(status: 200, body: search_results.to_json, headers: {"Content-Type" => "application/json"})
      end

      it "returns search results" do
        result = tool.execute(query: "ruby programming")
        aggregate_failures do
          expect(result[:results]).to be_an(Array)
          expect(result[:results].length).to eq(2)
        end
      end

      it "includes result details" do
        result = tool.execute(query: "ruby programming")
        first_result = result[:results].first
        aggregate_failures do
          expect(first_result["title"]).to eq("Result 1")
          expect(first_result["url"]).to eq("http://example.com/1")
        end
      end
    end

    context "with empty results" do
      before do
        stub_request(:get, "#{searxng_url}/search")
          .with(query: {"q" => "xyzabc123", "format" => "json"})
          .to_return(status: 200, body: {"results" => []}.to_json, headers: {"Content-Type" => "application/json"})
      end

      it "returns empty results" do
        result = tool.execute(query: "xyzabc123")
        expect(result[:results]).to eq([])
      end
    end

    context "with HTTP error" do
      before do
        stub_request(:get, "#{searxng_url}/search")
          .with(query: {"q" => "test", "format" => "json"})
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises error on HTTP failure" do
        expect { tool.execute(query: "test") }.to raise_error(Botiasloop::Error)
      end
    end

    context "with connection error" do
      before do
        stub_request(:get, "#{searxng_url}/search")
          .with(query: {"q" => "test", "format" => "json"})
          .to_raise(Errno::ECONNREFUSED)
      end

      it "raises error on connection failure" do
        expect { tool.execute(query: "test") }.to raise_error(Botiasloop::Error)
      end
    end
  end

  describe "Result" do
    let(:results) do
      [
        {"title" => "Test", "url" => "http://test.com", "content" => "Test content"}
      ]
    end

    subject(:result) { described_class::Result.new(results) }

    it { is_expected.to have_attributes(results: results) }

    it "converts to string" do
      aggregate_failures do
        expect(result.to_s).to include("Test")
        expect(result.to_s).to include("http://test.com")
      end
    end
  end
end
