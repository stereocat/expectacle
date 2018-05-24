# frozen_string_literal: true

require 'erb'

module Expectacle
  # Basic state setup/management
  class ThrowerBase
    private

    def ssh_command
      opts = load_spawn_command_opts_file
      ['ssh', opts, "-l #{embed_user_name}", embed_ipaddr].join(' ')
    end

    def cu_command
      @local_serial = true
      opts = load_spawn_command_opts_file
      ['cu', @host_param[:cu_opts], opts].join(' ')
    end

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

    def make_spawn_command
      case @host_param[:protocol]
      when /^telnet$/i
        ['telnet', embed_ipaddr].join(' ')
      when /^ssh$/i
        ssh_command
      when /^cu$/i
        cu_command
      else
        @logger.error "Unknown protocol #{@host_param[:protocol]}"
        nil
      end
    end

    def check_embed_envvar(command)
      return unless command =~ /<%=\s*ENV\[[\'\"]?(.+)[\'\"]\]?\s*%>/
      envvar_name = Regexp.last_match(1)
      if !ENV.key?(envvar_name)
        @logger.error "Variable name: #{envvar_name} is not found in ENV"
      elsif ENV[envvar_name] =~ /^\s*$/
        @logger.warn "Env var: #{envvar_name} exists, but null string"
      end
    end

    def embed_var(param)
      check_embed_envvar(param)
      erb = ERB.new(param)
      erb.result(binding)
    end

    def embed_password
      @host_param[:enable] = '_NOT_DEFINED_' unless @host_param.key?(:enable)
      base_str = @enable_mode ? @host_param[:enable] : @host_param[:password]
      embed_var(base_str)
    end

    def embed_command(command)
      embed_var(command)
    end

    def embed_user_name
      embed_var(@host_param[:username])
    end

    def embed_ipaddr
      embed_var(@host_param[:ipaddr])
    end
  end
end
