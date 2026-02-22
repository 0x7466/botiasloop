# frozen_string_literal: true

require "spec_helper"
require_relative "../../lib/botiasloop/systemd_service"

RSpec.describe Botiasloop::SystemdService do
  let(:config) { instance_double(Botiasloop::Config) }
  let(:service) { described_class.new(config) }
  let(:user_home) { "/home/testuser" }
  let(:config_dir) { "#{user_home}/.config" }
  let(:systemd_dir) { "#{config_dir}/systemd/user" }
  let(:service_file) { "#{systemd_dir}/botiasloop.service" }

  before do
    allow(Dir).to receive(:home).and_return(user_home)
    allow(FileUtils).to receive(:mkdir_p)
    allow(FileUtils).to receive(:rm_f)
    allow(File).to receive(:write)
    allow(File).to receive(:exist?).and_return(false)
    allow(service).to receive(:systemctl).and_return(true)
    allow(service).to receive(:systemd_available?).and_return(true)
  end

  describe "#initialize" do
    it "stores the config" do
      expect(service.config).to eq(config)
    end
  end

  describe "#installed?" do
    context "when service file exists" do
      before do
        allow(File).to receive(:exist?).with(service_file).and_return(true)
      end

      it "returns true" do
        expect(service.installed?).to be true
      end
    end

    context "when service file does not exist" do
      before do
        allow(File).to receive(:exist?).with(service_file).and_return(false)
      end

      it "returns false" do
        expect(service.installed?).to be false
      end
    end
  end

  describe "#enabled?" do
    context "when systemd is not available" do
      before do
        allow(service).to receive(:systemd_available?).and_return(false)
      end

      it "returns false" do
        expect(service.enabled?).to be false
      end
    end

    context "when systemctl exits with 0" do
      before do
        allow(service).to receive(:systemctl_quiet).with("is-enabled", "botiasloop.service").and_return(true)
      end

      it "returns true" do
        expect(service.enabled?).to be true
      end
    end

    context "when systemctl exits with non-zero" do
      before do
        allow(service).to receive(:systemctl_quiet).with("is-enabled", "botiasloop.service").and_return(false)
      end

      it "returns false" do
        expect(service.enabled?).to be false
      end
    end
  end

  describe "#active?" do
    context "when systemd is not available" do
      before do
        allow(service).to receive(:systemd_available?).and_return(false)
      end

      it "returns false" do
        expect(service.active?).to be false
      end
    end

    context "when systemctl exits with 0" do
      before do
        allow(service).to receive(:systemctl_quiet).with("is-active", "botiasloop.service").and_return(true)
      end

      it "returns true" do
        expect(service.active?).to be true
      end
    end

    context "when systemctl exits with non-zero" do
      before do
        allow(service).to receive(:systemctl_quiet).with("is-active", "botiasloop.service").and_return(false)
      end

      it "returns false" do
        expect(service.active?).to be false
      end
    end
  end

  describe "#install" do
    let(:service_template) { "[Unit]\nDescription=botiasloop" }

    before do
      allow(service).to receive(:service_template).and_return(service_template)
      allow(service).to receive(:systemctl).with("daemon-reload").and_return(true)
    end

    it "creates systemd user directory" do
      expect(FileUtils).to receive(:mkdir_p).with(systemd_dir)
      service.install
    end

    it "writes service file" do
      expect(File).to receive(:write).with(service_file, service_template)
      service.install
    end

    it "reloads systemd daemon" do
      expect(service).to receive(:systemctl).with("daemon-reload")
      service.install
    end

    it "returns true on success" do
      expect(service.install).to be true
    end

    context "when file write fails" do
      before do
        allow(File).to receive(:write).and_raise(Errno::EACCES, "Permission denied")
      end

      it "raises SystemdError" do
        expect { service.install }.to raise_error(Botiasloop::SystemdError, /Failed to install/)
      end
    end
  end

  describe "#uninstall" do
    before do
      allow(File).to receive(:exist?).with(service_file).and_return(true)
    end

    it "stops service if active" do
      allow(service).to receive(:active?).and_return(true)
      expect(service).to receive(:stop)
      service.uninstall
    end

    it "disables service if enabled" do
      allow(service).to receive(:enabled?).and_return(true)
      expect(service).to receive(:disable)
      service.uninstall
    end

    it "removes service file" do
      expect(FileUtils).to receive(:rm_f).with(service_file)
      service.uninstall
    end

    it "reloads systemd daemon" do
      expect(service).to receive(:systemctl).with("daemon-reload")
      service.uninstall
    end

    it "returns true on success" do
      expect(service.uninstall).to be true
    end

    context "when service file does not exist" do
      before do
        allow(File).to receive(:exist?).with(service_file).and_return(false)
      end

      it "returns false" do
        expect(service.uninstall).to be false
      end
    end
  end

  describe "#enable" do
    context "when systemd is not available" do
      before do
        allow(service).to receive(:systemd_available?).and_return(false)
      end

      it "raises SystemdError" do
        expect { service.enable }.to raise_error(Botiasloop::SystemdError, /systemd is not available/)
      end
    end

    context "when service is not installed" do
      before do
        allow(File).to receive(:exist?).with(service_file).and_return(false)
      end

      it "raises SystemdError" do
        expect { service.enable }.to raise_error(Botiasloop::SystemdError, /Service is not installed/)
      end
    end

    it "enables the service" do
      allow(File).to receive(:exist?).with(service_file).and_return(true)
      expect(service).to receive(:systemctl).with("enable", "botiasloop.service")
      service.enable
    end

    it "returns true on success" do
      allow(File).to receive(:exist?).with(service_file).and_return(true)
      expect(service.enable).to be true
    end
  end

  describe "#disable" do
    context "when systemd is not available" do
      before do
        allow(service).to receive(:systemd_available?).and_return(false)
      end

      it "raises SystemdError" do
        expect { service.disable }.to raise_error(Botiasloop::SystemdError, /systemd is not available/)
      end
    end

    it "disables the service" do
      expect(service).to receive(:systemctl).with("disable", "botiasloop.service")
      service.disable
    end

    it "returns true on success" do
      expect(service.disable).to be true
    end
  end

  describe "#start" do
    context "when systemd is not available" do
      before do
        allow(service).to receive(:systemd_available?).and_return(false)
      end

      it "raises SystemdError" do
        expect { service.start }.to raise_error(Botiasloop::SystemdError, /systemd is not available/)
      end
    end

    context "when service is not installed" do
      before do
        allow(File).to receive(:exist?).with(service_file).and_return(false)
      end

      it "raises SystemdError" do
        expect { service.start }.to raise_error(Botiasloop::SystemdError, /Service is not installed/)
      end
    end

    it "starts the service" do
      allow(File).to receive(:exist?).with(service_file).and_return(true)
      expect(service).to receive(:systemctl).with("start", "botiasloop.service")
      service.start
    end

    it "returns true on success" do
      allow(File).to receive(:exist?).with(service_file).and_return(true)
      expect(service.start).to be true
    end
  end

  describe "#stop" do
    context "when systemd is not available" do
      before do
        allow(service).to receive(:systemd_available?).and_return(false)
      end

      it "raises SystemdError" do
        expect { service.stop }.to raise_error(Botiasloop::SystemdError, /systemd is not available/)
      end
    end

    it "stops the service" do
      expect(service).to receive(:systemctl).with("stop", "botiasloop.service")
      service.stop
    end

    it "returns true on success" do
      expect(service.stop).to be true
    end
  end

  describe "#restart" do
    context "when systemd is not available" do
      before do
        allow(service).to receive(:systemd_available?).and_return(false)
      end

      it "raises SystemdError" do
        expect { service.restart }.to raise_error(Botiasloop::SystemdError, /systemd is not available/)
      end
    end

    context "when service is not installed" do
      before do
        allow(File).to receive(:exist?).with(service_file).and_return(false)
      end

      it "raises SystemdError" do
        expect { service.restart }.to raise_error(Botiasloop::SystemdError, /Service is not installed/)
      end
    end

    it "restarts the service" do
      allow(File).to receive(:exist?).with(service_file).and_return(true)
      expect(service).to receive(:systemctl).with("restart", "botiasloop.service")
      service.restart
    end

    it "returns true on success" do
      allow(File).to receive(:exist?).with(service_file).and_return(true)
      expect(service.restart).to be true
    end
  end

  describe "#status" do
    before do
      allow(service).to receive(:installed?).and_return(true)
      allow(service).to receive(:enabled?).and_return(true)
      allow(service).to receive(:active?).and_return(false)
    end

    it "returns hash with status information" do
      result = service.status
      expect(result).to be_a(Hash)
      expect(result[:installed]).to be true
      expect(result[:enabled]).to be true
      expect(result[:active]).to be false
    end

    context "when not installed" do
      before do
        allow(service).to receive(:installed?).and_return(false)
      end

      it "shows not installed message" do
        result = service.status
        expect(result[:message]).to eq("Service not installed")
      end
    end

    context "when installed and enabled but not active" do
      before do
        allow(service).to receive(:installed?).and_return(true)
        allow(service).to receive(:enabled?).and_return(true)
        allow(service).to receive(:active?).and_return(false)
      end

      it "shows enabled but stopped message" do
        result = service.status
        expect(result[:message]).to eq("Service enabled but stopped")
      end
    end

    context "when installed and running" do
      before do
        allow(service).to receive(:installed?).and_return(true)
        allow(service).to receive(:enabled?).and_return(true)
        allow(service).to receive(:active?).and_return(true)
      end

      it "shows running message" do
        result = service.status
        expect(result[:message]).to eq("Service is running")
      end
    end
  end

  describe "#systemd_available?" do
    before do
      # Reset the mock to call original method
      allow(service).to receive(:systemd_available?).and_call_original
    end

    context "when systemctl is available" do
      before do
        allow(service).to receive(:`).with("which systemctl 2>/dev/null").and_return("/usr/bin/systemctl")
      end

      it "returns true" do
        expect(service.systemd_available?).to be true
      end
    end

    context "when systemctl is not available" do
      before do
        allow(service).to receive(:`).with("which systemctl 2>/dev/null").and_return("")
      end

      it "returns false" do
        expect(service.systemd_available?).to be false
      end
    end
  end

  describe "#service_template" do
    it "returns string with service configuration" do
      template = service.send(:service_template)
      expect(template).to be_a(String)
      expect(template).to include("[Unit]")
      expect(template).to include("[Service]")
      expect(template).to include("[Install]")
    end

    it "includes botiasloop.service in Description" do
      template = service.send(:service_template)
      expect(template).to include("Description=botiasloop")
    end
  end

  describe "#systemctl" do
    before do
      allow(service).to receive(:systemctl).and_call_original
      allow(service).to receive(:system).and_return(true)
    end

    it "runs systemctl with given arguments" do
      expect(service).to receive(:system).with("systemctl", "--user", "start", "botiasloop.service")
      service.send(:systemctl, "start", "botiasloop.service")
    end

    it "returns true when command succeeds" do
      allow(service).to receive(:system).and_return(true)
      result = service.send(:systemctl, "status")
      expect(result).to be true
    end

    it "returns false when command fails" do
      allow(service).to receive(:system).and_return(false)
      result = service.send(:systemctl, "status")
      expect(result).to be false
    end
  end
end
