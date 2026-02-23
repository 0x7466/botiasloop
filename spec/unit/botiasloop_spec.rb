# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'botiasloop CLI' do
  let(:config) do
    Botiasloop::Config.new({
                             'providers' => { 'openrouter' => { 'api_key' => 'test-api-key' } }
                           })
  end

  let(:cli_channel) { instance_double(Botiasloop::Channels::CLI) }

  before do
    allow(Botiasloop::Config).to receive(:new).and_return(config)
    allow(Botiasloop::Channels::CLI).to receive(:new).and_return(cli_channel)
    allow(cli_channel).to receive(:start_listening)
  end

  describe 'no arguments' do
    it 'prints help message' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace([])
      load File.expand_path('../../bin/botiasloop', __dir__)

      expect(output.string).to include('botiasloop')
      expect(output.string).to include('Usage:')
      expect(output.string).to include('Commands:')
    end
  end

  describe 'cli command' do
    it 'starts CLI channel' do
      allow(cli_channel).to receive(:start_listening)

      ARGV.replace(['cli'])
      load File.expand_path('../../bin/botiasloop', __dir__)

      expect(cli_channel).to have_received(:start_listening)
    end
  end

  describe 'help command' do
    it "prints help message with 'help' command" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(['help'])
      load File.expand_path('../../bin/botiasloop', __dir__)

      expect(output.string).to include('botiasloop')
      expect(output.string).to include('Usage:')
      expect(output.string).to include('Commands:')
    end
  end

  describe 'help flag' do
    it 'prints help message with -h' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(['-h'])
      load File.expand_path('../../bin/botiasloop', __dir__)

      expect(output.string).to include('botiasloop')
      expect(output.string).to include('Usage:')
      expect(output.string).to include('Options:')
    end

    it 'prints help message with --help' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(['--help'])
      load File.expand_path('../../bin/botiasloop', __dir__)

      expect(output.string).to include('botiasloop')
      expect(output.string).to include('Usage:')
      expect(output.string).to include('Options:')
    end
  end

  describe 'version flag' do
    it 'prints version with -v' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(['-v'])
      load File.expand_path('../../bin/botiasloop', __dir__)

      expect(output.string).to include('botiasloop')
      expect(output.string).to include(Botiasloop::VERSION)
    end

    it 'prints version with --version' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(['--version'])
      load File.expand_path('../../bin/botiasloop', __dir__)

      expect(output.string).to include('botiasloop')
      expect(output.string).to include(Botiasloop::VERSION)
    end
  end

  describe 'unknown command' do
    it 'prints error message and help' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      allow($stderr).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(['unknown'])
      begin
        load File.expand_path('../../bin/botiasloop', __dir__)
      rescue SystemExit => e
        expect(e.status).to eq(1)
      end

      expect(output.string).to include('Unknown command')
      expect(output.string).to include('botiasloop')
    end
  end
end
