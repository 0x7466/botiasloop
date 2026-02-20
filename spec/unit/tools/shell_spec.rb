# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe Botiasloop::Tools::Shell do
  describe "#execute" do
    let(:tool) { described_class.new }

    it "executes a simple command" do
      result = tool.execute(command: "echo hello")
      expect(result[:stdout]).to eq("hello\n")
      expect(result[:exit_code]).to eq(0)
      expect(result[:success?]).to be true
    end

    it "captures stderr" do
      result = tool.execute(command: "echo error >&2")
      expect(result[:stderr]).to eq("error\n")
      expect(result[:stdout]).to eq("")
    end

    it "returns non-zero exit code on failure" do
      result = tool.execute(command: "exit 1")
      expect(result[:exit_code]).to eq(1)
      expect(result[:success?]).to be false
    end

    it "handles multi-line output" do
      result = tool.execute(command: "printf 'line1\nline2\n'")
      expect(result[:stdout]).to eq("line1\nline2\n")
    end
  end

  describe "Result" do
    let(:result) { described_class::Result.new("stdout", "stderr", 0) }

    it "provides stdout accessor" do
      expect(result.stdout).to eq("stdout")
    end

    it "provides stderr accessor" do
      expect(result.stderr).to eq("stderr")
    end

    it "provides exit_code accessor" do
      expect(result.exit_code).to eq(0)
    end

    it "provides success? method" do
      expect(result.success?).to be true
    end

    it "returns false for success? when exit code is non-zero" do
      failed_result = described_class::Result.new("", "error", 1)
      expect(failed_result.success?).to be false
    end

    it "converts to string" do
      expect(result.to_s).to include("stdout")
      expect(result.to_s).to include("stderr")
      expect(result.to_s).to include("0")
    end
  end
end
