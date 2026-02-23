# frozen_string_literal: true

require "fileutils"

module Botiasloop
  # Systemd user service management for auto-start on boot
  #
  # Manages installation, enablement, and control of botiasloop
  # as a systemd user service. This allows botiasloop to start
  # automatically on user login and run in the background.
  #
  # @example Install and enable the service
  #   service = Botiasloop::SystemdService.new(config)
  #   service.install
  #   service.enable
  #   service.start
  #
  # @example Check status
  #   service = Botiasloop::SystemdService.new(config)
  #   status = service.status
  #   puts "Running: #{status[:active]}"
  #
  class SystemdService
    attr_reader :config

    # Service name used by systemd
    SERVICE_NAME = "botiasloop.service"

    # Initialize a new SystemdService instance
    #
    # @param config [Config] Configuration instance
    def initialize(config)
      @config = config
    end

    # Check if systemd is available on the system
    #
    # @return [Boolean] True if systemctl is available
    def systemd_available?
      !`which systemctl 2>/dev/null`.strip.empty?
    end

    # Check if the service file is installed
    #
    # @return [Boolean] True if service file exists
    def installed?
      File.exist?(service_file_path)
    end

    # Check if the service is enabled to start on boot
    #
    # @return [Boolean] True if service is enabled
    def enabled?
      return false unless systemd_available?

      systemctl_quiet("is-enabled", SERVICE_NAME)
    end

    # Check if the service is currently active/running
    #
    # @return [Boolean] True if service is active
    def active?
      return false unless systemd_available?

      systemctl_quiet("is-active", SERVICE_NAME)
    end

    # Install the service file
    #
    # Creates the systemd user directory if needed and writes
    # the service configuration file.
    #
    # @raise [SystemdError] If installation fails
    # @return [Boolean] True on success
    def install
      FileUtils.mkdir_p(systemd_user_dir)
      File.write(service_file_path, service_template)
      systemctl("daemon-reload")
      true
    rescue => e
      raise SystemdError, "Failed to install service: #{e.message}"
    end

    # Uninstall the service
    #
    # Stops the service if running, disables it, removes the
    # service file, and reloads systemd.
    #
    # @return [Boolean] True if uninstalled, false if not installed
    def uninstall
      return false unless installed?

      stop if active?
      disable if enabled?
      FileUtils.rm_f(service_file_path)
      systemctl("daemon-reload")
      true
    end

    # Enable the service to start on boot
    #
    # Enables linger to allow user services to start at boot time,
    # then enables the service. Falls back gracefully if linger fails.
    #
    # @raise [SystemdError] If systemd unavailable or service not installed
    # @return [Boolean] True on success
    def enable
      raise SystemdError, "systemd is not available on this system" unless systemd_available?
      raise SystemdError, "Service is not installed" unless installed?

      enable_linger
      systemctl("enable", SERVICE_NAME)
      true
    end

    # Disable the service from starting on boot
    #
    # Disables the service then disables linger if it was enabled.
    #
    # @raise [SystemdError] If systemd unavailable
    # @return [Boolean] True on success
    def disable
      raise SystemdError, "systemd is not available on this system" unless systemd_available?

      systemctl("disable", SERVICE_NAME)
      disable_linger
      true
    end

    # Check if linger is enabled for the current user
    #
    # Linger allows user services to start at boot time
    # without requiring a user login session.
    #
    # @return [Boolean] True if linger is enabled
    def linger_enabled?
      output = `loginctl show-user $USER --property=Linger 2>/dev/null`.strip
      output == "Linger=yes"
    end

    # Enable linger for the current user
    #
    # Allows user services to start at boot time.
    # Does nothing if already enabled.
    #
    # @return [Boolean] True on success or already enabled, false on failure
    def enable_linger
      return true if linger_enabled?

      system("loginctl", "enable-linger", ENV["USER"])
    end

    # Disable linger for the current user
    #
    # Prevents user services from starting at boot time.
    # Does nothing if already disabled.
    #
    # @return [Boolean] True on success or already disabled, false on failure
    def disable_linger
      return true unless linger_enabled?

      system("loginctl", "disable-linger", ENV["USER"])
    end

    # Start the service
    #
    # @raise [SystemdError] If systemd unavailable or service not installed
    # @return [Boolean] True on success
    def start
      raise SystemdError, "systemd is not available on this system" unless systemd_available?
      raise SystemdError, "Service is not installed" unless installed?

      systemctl("start", SERVICE_NAME)
      true
    end

    # Stop the service
    #
    # @raise [SystemdError] If systemd unavailable
    # @return [Boolean] True on success
    def stop
      raise SystemdError, "systemd is not available on this system" unless systemd_available?

      systemctl("stop", SERVICE_NAME)
      true
    end

    # Restart the service
    #
    # @raise [SystemdError] If systemd unavailable or service not installed
    # @return [Boolean] True on success
    def restart
      raise SystemdError, "systemd is not available on this system" unless systemd_available?
      raise SystemdError, "Service is not installed" unless installed?

      systemctl("restart", SERVICE_NAME)
      true
    end

    # Get service status information
    #
    # @return [Hash] Status with :installed, :enabled, :active, :message keys
    def status
      {
        installed: installed?,
        enabled: enabled?,
        active: active?,
        message: status_message
      }
    end

    # Display service logs using journalctl
    #
    # @param follow [Boolean] Whether to follow logs in real-time (tail -f mode)
    # @param lines [Integer] Number of lines to show (default: 50)
    # @raise [SystemdError] If systemd is not available
    # @return [Boolean] True on success
    def logs(follow: false, lines: 50)
      raise SystemdError, "systemd is not available on this system" unless systemd_available?

      args = ["--user", "-u", SERVICE_NAME, "-n", lines.to_s]
      args << (follow ? "-f" : "--no-pager")

      system("journalctl", *args)
    end

    private

    # Get the systemd user directory path
    #
    # @return [String] Path to ~/.config/systemd/user
    def systemd_user_dir
      File.join(Dir.home, ".config", "systemd", "user")
    end

    # Get the full path to the service file
    #
    # @return [String] Path to service file
    def service_file_path
      File.join(systemd_user_dir, SERVICE_NAME)
    end

    # Generate the service file content
    #
    # @return [String] systemd service unit content
    def service_template
      <<~SERVICE
        [Unit]
        Description=botiasloop - AI Agent Gateway
        Documentation=https://github.com/0x7466/botiasloop
        After=network.target

        [Service]
        Type=simple
        ExecStart=#{executable_path} gateway
        Restart=on-failure
        RestartSec=5
        StandardOutput=journal
        StandardError=journal
        Environment="PATH=#{ruby_bin_path}:/usr/local/bin:/usr/bin:/bin"

        [Install]
        WantedBy=default.target
      SERVICE
    end

    # Get the path to the botiasloop executable
    #
    # @return [String] Path to botiasloop binary
    def executable_path
      Gem.bin_path("botiasloop", "botiasloop")
    rescue Gem::Exception
      # Fallback to searching in PATH
      `which botiasloop 2>/dev/null`.strip
    end

    # Get the Ruby bin directory for PATH
    #
    # @return [String] Path to Ruby bin directory
    def ruby_bin_path
      File.dirname(RbConfig.ruby)
    end

    # Execute a systemctl command
    #
    # @param args [Array<String>] Arguments to pass to systemctl
    # @return [Boolean] True if command succeeded
    def systemctl(*args)
      system("systemctl", "--user", *args)
    end

    # Execute a systemctl command quietly (no output)
    #
    # @param args [Array<String>] Arguments to pass to systemctl
    # @return [Boolean] True if command succeeded
    def systemctl_quiet(*args)
      system("systemctl", "--user", *args, out: "/dev/null", err: "/dev/null")
    end

    # Get a human-readable status message
    #
    # @return [String] Status description
    def status_message
      if !installed?
        "Service not installed"
      elsif active?
        "Service is running"
      elsif enabled?
        "Service enabled but stopped"
      else
        "Service installed but disabled"
      end
    end
  end
end
