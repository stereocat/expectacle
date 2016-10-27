require 'rspec/given'
require 'expectacle/thrower'

module Expectacle
  describe Thrower do
    describe '.new' do
      Given(:thrower) { Thrower.new }

      describe '#prompts_dir' do
        When(:prompts_dir) { thrower.prompts_dir }
        Then { prompts_dir == File.join(thrower.base_dir, 'prompts') }
      end

      describe '#hosts_dir' do
        When(:hosts_dir) { thrower.hosts_dir }
        Then { hosts_dir == File.join(thrower.base_dir, 'hosts') }
      end

      describe '#commands_dir' do
        When(:commands_dir) { thrower.commands_dir }
        Then { commands_dir == File.join(thrower.base_dir, 'commands') }
      end

      # rubocop:disable Style/GlobalVars
      describe '#preview_parameter' do
        def YAML.dump(data)
          $dump_data = data # FIXME
          nil
        end
        When(:preview) { thrower.preview_parameter hosts, commands }

        context 'when hosts is empty' do
          Given(:hosts) { [] }
          Given(:commands) { [] }

          Then { expect(preview).to be_empty }
        end

        context "when hosts = [{ hostname: 'pica8', ipaddr: '1.2.3.4', type: 'pica8', protocol: 'ssh', username: 'yasuhito', password: 'password' }]" do
          Given { allow(YAML).to receive(:load_file).with(/pica8_prompt\.yml$/).and_return([]) }
          Given(:hosts) { [{ hostname: 'pica8', ipaddr: '1.2.3.4', type: 'pica8', protocol: 'ssh', username: 'yasuhito', password: 'password' }] }

          context 'when commands is empty' do
            Given(:commands) { [] }

            Then { $dump_data[:spawn_cmd] == 'ssh -o StrictHostKeyChecking=no -o KexAlgorithms=+diffie-hellman-group1-sha1 -l yasuhito 1.2.3.4' }
            Then { $dump_data[:commands].empty? }
          end

          context "when commands is ['ls']" do
            Given(:commands) { ['ls'] }

            Then { $dump_data[:spawn_cmd] == 'ssh -o StrictHostKeyChecking=no -o KexAlgorithms=+diffie-hellman-group1-sha1 -l yasuhito 1.2.3.4' }
            Then { $dump_data[:commands] == ['ls'] }
          end
        end
      end
      # rubocop:enable Style/GlobalVars
    end
  end
end
