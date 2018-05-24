# frozen_string_literal: true

require 'yaml'
require 'logger'
require 'syslog/logger'

module Expectacle
  # Basic state setup/management
  class ThrowerBase
    # @return [Logger] Logger instance.
    attr_accessor :logger

    private

    def write_and_logging(message, command, secret = false)
      logging_message = secret ? message : message + command
      @logger.info logging_message
      if @writer.closed?
        @logger.error "Try to write #{command}, but writer closed"
        @commands.clear
      else
        @writer.puts command
      end
    end

    def default_io_logger(logger_io, progname)
      logger = Logger.new(logger_io)
      logger.progname = progname
      logger.datetime_format = '%Y-%m-%d %H:%M:%D %Z'
      logger
    end

    def setup_default_logger(logger)
      progname = 'Expectacle'
      @logger = if logger == :syslog
                  Syslog::Logger.new(progname)
                else
                  default_io_logger(logger, progname)
                end
      @logger.level = Logger::INFO
      @logger.formatter = proc do |severity, datetime, pname, msg|
        "#{datetime} #{pname} [#{severity}] #{msg}\n"
      end
    end

    def load_yaml_file(file_type, file_name)
      YAML.load_file file_name
    rescue StandardError => error
      @logger.error "Cannot load #{file_type}: #{file_name}"
      raise error
    end

    def load_prompt_file
      prompt_file = "#{prompts_dir}/#{@host_param[:type]}_prompt.yml"
      @prompt = load_yaml_file('prompt file', prompt_file)
    end

    def load_spawn_command_opts_file
      opts_file = "#{opts_dir}/#{@host_param[:protocol]}_opts.yml"
      if File.exist?(opts_file)
        load_yaml_file("#{@host_param[:protocol]} opts file", opts_file)
      else
        @logger.warn "Opts file #{opts_file} not found."
        []
      end
    end
  end
end
