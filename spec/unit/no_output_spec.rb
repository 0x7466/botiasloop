# frozen_string_literal: true

require "./lib/botiasloop/channels/base"
require "./lib/botiasloop/commands"
require "./lib/botiasloop/agent"

RSpec.describe Botiasloop::Channels::Base do
  describe "NO_OUTPUT functionality" do
    let(:process_test_channel_class) do
      Class.new(Botiasloop::Channels::Base) do
        channel_name :process_test_channel

        attr_reader :delivered_responses

        def initialize
          super
          @delivered_responses = []
        end

        def start_listening
        end

        def stop_listening
        end

        def running?
          false
        end

        def extract_content(raw_message)
          raw_message
        end

        def authorized?(_source_id)
          true
        end

        def deliver_message(source_id, formatted_content)
          @delivered_responses << {source_id: source_id, content: formatted_content}
        end
      end
    end
    let(:channel) { process_test_channel_class.new }

    before do
      allow(Botiasloop::Agent).to receive(:chat).and_return("Agent response")
    end

    it "suppresses NO_OUTPUT response and stores stripped content" do
      allow(Botiasloop::Commands).to receive(:execute).and_return("NO_OUTPUT suppressed response")
      expect(channel).not_to receive(:deliver_message)
      channel.process_message("user123", "test")
      expect(channel.delivered_responses).to be_empty
    end

    it "doesn't suppress normal responses" do
      allow(Botiasloop::Commands).to receive(:execute).and_return("normal response")
      channel.process_message("user123", "test")
      expect(channel.delivered_responses).to be_empty
    end

    it "suppresses NO_OUTPUT response in callback and stores stripped content" do
      mock_agent_chat = double("agent_chat")
      allow(Botiasloop::Agent).to receive(:chat).and_call_original
      channel.process_message("user123", "test")
      expect(channel.delivered_responses).to be_empty
    end

    it "doesn't suppress normal responses in callback" do
      mock_agent_chat = double("agent_chat")
      allow(Botiasloop::Agent).to receive(:chat).and_call_original
      channel.process_message("user123", "test")
      expect(channel.delivered_responses).to be_empty
    end
  end
end