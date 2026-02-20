# frozen_string_literal: true

require "spec_helper"

RSpec.describe "botiasloop CLI" do
  let(:agent) { instance_double(Botiasloop::Agent) }

  before do
    allow(Botiasloop::Agent).to receive(:new).and_return(agent)
  end

  describe "one-shot mode" do
    it "passes arguments to agent.chat" do
      allow(agent).to receive(:chat).with("hello world").and_return("response")
      allow($stdout).to receive(:puts)

      ARGV.replace(["hello", "world"])
      load File.expand_path("../../../bin/botiasloop", __FILE__)
    end
  end

  describe "interactive mode" do
    it "calls agent.interactive when no args" do
      allow(agent).to receive(:interactive)

      ARGV.replace([])
      load File.expand_path("../../../bin/botiasloop", __FILE__)
    end
  end

  describe "help flag" do
    it "prints help message with -h" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(["-h"])
      load File.expand_path("../../../bin/botiasloop", __FILE__)

      expect(output.string).to include("botiasloop")
      expect(output.string).to include("Usage:")
      expect(output.string).to include("Options:")
    end

    it "prints help message with --help" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(["--help"])
      load File.expand_path("../../../bin/botiasloop", __FILE__)

      expect(output.string).to include("botiasloop")
      expect(output.string).to include("Usage:")
      expect(output.string).to include("Options:")
    end
  end

  describe "version flag" do
    it "prints version with -v" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(["-v"])
      load File.expand_path("../../../bin/botiasloop", __FILE__)

      expect(output.string).to include("botiasloop")
      expect(output.string).to include(Botiasloop::VERSION)
    end

    it "prints version with --version" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(["--version"])
      load File.expand_path("../../../bin/botiasloop", __FILE__)

      expect(output.string).to include("botiasloop")
      expect(output.string).to include(Botiasloop::VERSION)
    end
  end
end
