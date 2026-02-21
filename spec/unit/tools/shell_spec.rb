# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe Botiasloop::Tools::Shell do
  describe "#execute" do
    let(:tool) { described_class.new }

    it "executes a simple command" do
      result = tool.execute(command: "echo hello")
      aggregate_failures do
        expect(result[:stdout]).to eq("hello\n")
        expect(result[:exit_code]).to eq(0)
        expect(result[:success?]).to be true
      end
    end

    it "captures stderr" do
      result = tool.execute(command: "echo error >&2")
      aggregate_failures do
        expect(result[:stderr]).to eq("error\n")
        expect(result[:stdout]).to eq("")
      end
    end

    it "returns non-zero exit code on failure" do
      result = tool.execute(command: "exit 1")
      aggregate_failures do
        expect(result[:exit_code]).to eq(1)
        expect(result[:success?]).to be false
      end
    end

    it "handles multi-line output" do
      result = tool.execute(command: "printf 'line1\nline2\n'")
      expect(result[:stdout]).to eq("line1\nline2\n")
    end
  end

  describe "Result" do
    subject(:result) { described_class::Result.new("stdout", "stderr", 0) }

    it { is_expected.to have_attributes(stdout: "stdout", stderr: "stderr", exit_code: 0) }
    it { is_expected.to be_success }

    it "returns false for success? when exit code is non-zero" do
      failed_result = described_class::Result.new("", "error", 1)
      expect(failed_result).not_to be_success
    end

    it "converts to string" do
      aggregate_failures do
        expect(result.to_s).to include("stdout")
        expect(result.to_s).to include("stderr")
        expect(result.to_s).to include("0")
      end
    end
  end
end
