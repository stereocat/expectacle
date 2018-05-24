# frozen_string_literal: true

require 'erb'

module Expectacle
  # Basic state setup/management
  class ThrowerBase
    # Path to prompt file directory.
    # @return [String]
    def prompts_dir
      File.join @base_dir, 'prompts'
    end

    # Path to host list file directory.
    # @return [String]
    def hosts_dir
      File.join @base_dir, 'hosts'
    end

    # Path to command list file directory.
    # @return [String]
    def commands_dir
      File.join @base_dir, 'commands'
    end

    # Path to span command options file directory.
    # @return [String]
    def opts_dir
      File.join @base_dir, 'opts'
    end

    private

    # Setup ssh command to spawn
    # @return [String] ssh command
    def ssh_command
      opts = load_spawn_command_opts_file
      ['ssh', opts, "-l #{embed_user_name}", embed_ipaddr].join(' ')
    end

    # Setup telnet command to spawn
    # @return [String] telnet command
    def telnet_command
      ['telnet', embed_ipaddr].join(' ')
    end

    # Setup cu command to spawn
    # @return [String: cu command
    def cu_command
      @local_serial = true
      opts = load_spawn_command_opts_file
      ['cu', @host_param[:cu_opts], opts].join(' ')
    end

    # Setup regexp to find prompt
    # @return [Regexp] Prompt regexp
    def expect_regexp
      /
        ( #{@prompt[:password]} | #{@prompt[:enable_password]}
        | #{@prompt[:username]}
        | #{@prompt[:command1]} | #{@prompt[:command2]}
        | #{@prompt[:sub1]} | #{@prompt[:sub2]}
        | #{@prompt[:yn]}
        )\s*$
      /x
    end

    # Make command to spawn according to host type
    # @return [String] Command to spawn
    def make_spawn_command
      case @host_param[:protocol]
      when /^telnet$/i
        telnet_command
      when /^ssh$/i
        ssh_command
      when /^cu$/i
        cu_command
      else
        @logger.error "Unknown protocol #{@host_param[:protocol]}"
        nil
      end
    end

    # Error checking of environment variable to embed
    # @param param [String] Embedding target command
    def check_embed_envvar(param)
      return unless param =~ /<%=\s*ENV\[[\'\"]?(.+)[\'\"]\]?\s*%>/
      envvar_name = Regexp.last_match(1)
      if !ENV.key?(envvar_name)
        @logger.error "Variable name: #{envvar_name} is not found in ENV"
      elsif ENV[envvar_name] =~ /^\s*$/
        @logger.warn "Env var: #{envvar_name} exists, but null string"
      end
    end

    # Embedding environment variable to parameter
    # @param param [String] Embedding target command
    # @return [String] Embedded command
    def embed_var(param)
      check_embed_envvar(param)
      erb = ERB.new(param)
      erb.result(binding)
    end

    # Embedding password
    # @return [String] Embedded password
    def embed_password
      @host_param[:enable] = '_NOT_DEFINED_' unless @host_param.key?(:enable)
      base_str = @enable_mode ? @host_param[:enable] : @host_param[:password]
      embed_var(base_str)
    end

    # Embedding command
    # @return [String] Embedded command
    def embed_command(command)
      embed_var(command)
    end

    # Embedding user name
    # @return [String] Embedded user name
    def embed_user_name
      embed_var(@host_param[:username])
    end

    # Embedding ip address
    # @return [String] Embedded password
    def embed_ipaddr
      embed_var(@host_param[:ipaddr])
    end
  end
end
