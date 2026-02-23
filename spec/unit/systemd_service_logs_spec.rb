# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::SystemdService do
  let(:service) { described_class.new }

  before do
    allow(service).to receive(:`).with("which systemctl 2>/dev/null").and_return("/bin/systemctl")
  end

  describe "#logs" do
    context "when systemd is not available" do
      before do
        allow(service).to receive(:`).with("which systemctl 2>/dev/null").and_return("")
      end

      it "raises SystemdError" do
        expect do
          service.logs
        end.to raise_error(Botiasloop::SystemdError, "systemd is not available on this system")
      end
    end

    context "when systemd is available" do
      it "executes journalctl with default options" do
        expect(service).to receive(:system).with(
          "journalctl", "--user", "-u", "botiasloop.service", "-n", "50", "--no-pager"
        ).and_return(true)

        service.logs
      end

      it "executes journalctl with custom line count" do
        expect(service).to receive(:system).with(
          "journalctl", "--user", "-u", "botiasloop.service", "-n", "100", "--no-pager"
        ).and_return(true)

        service.logs(lines: 100)
      end

      it "executes journalctl in follow mode" do
        expect(service).to receive(:system).with(
          "journalctl", "--user", "-u", "botiasloop.service", "-n", "50", "-f"
        ).and_return(true)

        service.logs(follow: true)
      end

      it "executes journalctl in follow mode with custom line count" do
        expect(service).to receive(:system).with(
          "journalctl", "--user", "-u", "botiasloop.service", "-n", "200", "-f"
        ).and_return(true)

        service.logs(follow: true, lines: 200)
      end
    end
  end
end
