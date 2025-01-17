require 'spec_helper'

describe Lumberjack::SyslogDevice do

  let(:syslog) { MockSyslog.new }
  let(:time) { Time.parse("2011-02-01T18:32:31Z") }
  let(:entry) { Lumberjack::LogEntry.new(time, Lumberjack::Severity::WARN, "message 1", "lumberjack_syslog_device_spec", 12345, "foo" => "bar") }

  context "open connection" do
    it "should set the identity as the progname" do
      device = Lumberjack::SyslogDevice.new
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.ident).to eq entry.progname
    end

    it "should be able to specify syslog options" do
      device = Lumberjack::SyslogDevice.new(:options => Syslog::LOG_CONS)
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.options).to eq Syslog::LOG_CONS
    end

    it "should be able to specify a syslog facility" do
      device = Lumberjack::SyslogDevice.new(:facility => Syslog::LOG_FTP)
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.facility).to eq Syslog::LOG_FTP
    end

    it "should log all messages since the logger will filter them by severity" do
      device = Lumberjack::SyslogDevice.new
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.mask).to eq(Syslog::LOG_UPTO(Syslog::LOG_DEBUG))
    end

    it "should keep open the syslog connection by default" do
      device = Lumberjack::SyslogDevice.new
      device.write(entry)
      expect(Syslog).to be_opened
    end

    it "should close the syslog connection if :close_connection is true" do
      device = Lumberjack::SyslogDevice.new(:close_connection => true)
      device.write(entry)
      expect(Syslog).not_to be_opened
    end
  end

  context "logging" do
    it "should log entries to syslog" do
      entry.tags.clear
      device = Lumberjack::SyslogDevice.new
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.output).to eq [[Syslog::LOG_WARNING, "message 1"]]
    end

    it "should log output to syslog with tags" do
      device = Lumberjack::SyslogDevice.new
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.output).to eq [[Syslog::LOG_WARNING, 'message 1 [foo:"bar"]']]
    end

    it "should log output with a unit of work id in the default template" do
      entry.unit_of_work_id = "ABCD"
      device = Lumberjack::SyslogDevice.new
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.output).to eq [[Syslog::LOG_WARNING, 'message 1 (ABCD) [foo:"bar"]']]
    end

    it "should be able to specify a string template" do
      device = Lumberjack::SyslogDevice.new(:template => ":foo - :message")
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.output).to eq [[Syslog::LOG_WARNING, "bar - message 1"]]
    end

    it "should be able to specify a proc template" do
      device = Lumberjack::SyslogDevice.new(:template => lambda{|e| e.message.upcase})
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.output).to eq [[Syslog::LOG_WARNING, "MESSAGE 1"]]
    end

    it "should properly handle percent signs in the syslog message" do
      device = Lumberjack::SyslogDevice.new
      entry.message = "message 100%"
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.output).to eq [[Syslog::LOG_WARNING, 'message 100%% [foo:"bar"]']]
    end

    class Template
      def call(e)
        e.message
      end
    end
    it "should properly handle Hash" do
      device = Lumberjack::SyslogDevice.new(template: Template.new)
      entry.message = {}
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      device.write(entry)
      expect(syslog.output).to eq [[Syslog::LOG_WARNING, "HASH detected!!! #{entry.message}"]]
    end

    it "should convert lumberjack severities to syslog severities" do
      syslog = MockSyslog.new
      device = Lumberjack::SyslogDevice.new
      allow(device).to receive(:syslog_implementation).and_return(syslog)
      expect(syslog).to receive(:log).with(Syslog::LOG_DEBUG, "debug")
      expect(syslog).to receive(:log).with(Syslog::LOG_INFO, "info")
      expect(syslog).to receive(:log).with(Syslog::LOG_WARNING, "warn")
      expect(syslog).to receive(:log).with(Syslog::LOG_ERR, "error")
      expect(syslog).to receive(:log).with(Syslog::LOG_CRIT, "fatal")
      device.write(Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::DEBUG, "debug", "lumberjack_syslog_device_spec", 12345, nil))
      device.write(Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::INFO, "info", "lumberjack_syslog_device_spec", 12345, nil))
      device.write(Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::WARN, "warn", "lumberjack_syslog_device_spec", 12345, nil))
      device.write(Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::ERROR, "error", "lumberjack_syslog_device_spec", 12345, nil))
      device.write(Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::FATAL, "fatal", "lumberjack_syslog_device_spec", 12345, nil))
    end
  end
end
