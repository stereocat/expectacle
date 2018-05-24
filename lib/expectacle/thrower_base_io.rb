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

    # Send string to process and logging the string
    # @param message [String] Message to logging
    # @param command [String] Command to send
    # @param secret [Boolearn] Choise to logging command
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

    # Setup default IO logger
    # @return [Logger] logger
    def default_io_logger(logger_io, progname)
      logger = Logger.new(logger_io)
      logger.progname = progname
      logger.datetime_format = '%Y-%m-%d %H:%M:%D %Z'
      logger
    end

    # Setup default logger (select IO or Syslog logger)
    # @param logger [Symbol] Syslog logger or not
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

    # YAML file loader
    # @param file_type [String] File description
    # @param file_name [String] File name to load
    # @raise [Error] File load error
    def load_yaml_file(file_type, file_name)
      YAML.load_file file_name
    rescue StandardError => error
      @logger.error "Cannot load #{file_type}: #{file_name}"
      raise error
    end

    # Load prompt file and setup prompt parameter
    def load_prompt_file
      prompt_file = "#{prompts_dir}/#{@host_param[:type]}_prompt.yml"
      @prompt = load_yaml_file('prompt file', prompt_file)
    end

    # Load span command options from file
    # @return [Array<String>] Options for spawn command
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
