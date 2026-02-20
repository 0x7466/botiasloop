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
end
