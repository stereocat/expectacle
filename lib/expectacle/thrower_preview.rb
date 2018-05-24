# frozen_string_literal: true

require 'expectacle/thrower_base'

module Expectacle
  # Thrower logic(command list operation)
  class Thrower < ThrowerBase
    # #preview_parameter
    #   #previewed_data [for hosts & a host]
    #     #ready_to_open_host_session #-> thrower_base
    #       #whole_previewed_parameters
    #         #previewed_host_param
    #         #previewed_commands

    # Preview all parameters for all hosts.
    # @param [Array<Hash>] hosts Host parameters (read from host list file).
    # @param [Array<String>] commands Commands (read from command list file).
    def preview_parameter(hosts, commands)
      print YAML.dump(previewed_data(hosts, commands))
    end

    # Preview all parameters for all hosts (for testing)
    # @param [Array<Hash>] hosts Host parameters (read from host list file).
    # @param [Array<String>] commands Commands (read from command list file).
    def previewed_data(hosts, commands)
      @commands = commands
      hosts.map do |each|
        @host_param = each
        # [for a host] operation
        ready_to_open_host_session do |spawn_cmd|
          whole_previewed_parameters(spawn_cmd)
        end
      end
    end

    private

    # Combine previewed parameters
    def whole_previewed_parameters(spawn_cmd)
      {
        spawn_cmd: spawn_cmd,
        prompt: @prompt,
        host: previewed_host_param,
        commands: previewed_commands
      }
    end

    # Setup parameters for a host to preview
    def previewed_host_param
      host_param = @host_param.dup
      enable_mode = @enable_mode
      @enable_mode = false
      host_param[:username] = embed_user_name
      host_param[:password] = embed_password
      host_param[:ipaddr] = embed_ipaddr
      @enable_mode = true
      host_param[:enable] = embed_password
      @enable_mode = enable_mode
      host_param
    end

    # Setup command list to preview
    def previewed_commands
      @commands.map { |cmd| embed_command(cmd) }
    end
  end
end
