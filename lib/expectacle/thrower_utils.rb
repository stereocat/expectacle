# frozen_string_literal: true

require 'expectacle/thrower_base_io'

module Expectacle
  # Thrower logic(command list operation)
  class Thrower < ThrowerBase
    private

    def check_auth_count
      if @commands.length == @commands_len
        @auth_count += 1
      else
        @auth_count = 0
        @commands_len = @commands.length
      end
      return unless @auth_count > MAX_AUTH_COUNT
      @logger.error "Close: Too many auth retries (#{@auth_count} times)"
      @commands = []
      close_session
    end

    def clear_auth_count
      @auth_count = 0
    end

    def close_session
      write_and_logging 'Send break: ', 'exit'
      return unless @local_serial
      @logger.info 'Close IO for spawn command'
      @reader.close
      @writer.close
    end
  end
end
