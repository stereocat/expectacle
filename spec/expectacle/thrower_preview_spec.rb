require 'rspec/given'
require 'expectacle/thrower'

module Expectacle
  describe Thrower do
    describe '#previewed_data' do
      Given(:thrower) { Thrower.new base_dir: File.expand_path('../../vendor', __dir__) }
      When(:preview) { thrower.previewed_data hosts, commands }

      context 'when hosts is empty' do
        Given(:hosts) { [] }
        Given(:commands) { [] }

        Then { expect(preview).to be_empty }
      end

      context 'standard param definition with ssh' do
        Given(:hosts) { [{ hostname: 'pica8', ipaddr: '1.2.3.4', type: 'pica8', protocol: 'ssh', username: 'yasuhito', password: 'password' }] }

        context 'when commands is empty' do
          Given(:commands) { [] }

          Then { preview[0][:spawn_cmd] == 'ssh -o StrictHostKeyChecking=no -o KexAlgorithms=+diffie-hellman-group1-sha1 -o Ciphers=+aes128-cbc,3des-cbc,aes192-cbc,aes256-cbc -l yasuhito 1.2.3.4' }
          Then { preview[0][:commands].empty? }
        end

        context "when commands is ['ls']" do
          Given(:commands) { ['ls'] }

          Then { preview[0][:spawn_cmd] == 'ssh -o StrictHostKeyChecking=no -o KexAlgorithms=+diffie-hellman-group1-sha1 -o Ciphers=+aes128-cbc,3des-cbc,aes192-cbc,aes256-cbc -l yasuhito 1.2.3.4' }
          Then { preview[0][:commands] == ['ls'] }
        end
      end

      context 'check embed var: ipaddr, username, password, command' do
        Given do
          allow(ENV).to receive(:[]).with('L2SW_IP').and_return('172.16.0.1')
          allow(ENV).to receive(:[]).with('L2SW_USER').and_return('yasuhito')
          allow(ENV).to receive(:[]).with('L2SW_PASS').and_return('password')
          allow(ENV).to receive(:[]).with('L2SW_EN_PASS').and_return('p@ssw0rd')
        end
        Given(:commands) { [] }

        context 'embed ipaddr' do
          Given(:hosts) { [{ hostname: 'l2sw1', ipaddr: "<%= ENV['L2SW_IP'] %>", type: 'c3750g', protocol: 'telnet', username: 'yasuhito', password: 'password' }] }
          Then { preview[0][:host][:ipaddr] == '172.16.0.1' }
          Then { preview[0][:spawn_cmd] == 'telnet 172.16.0.1' }
        end

        context 'embed username' do
          Given(:hosts) { [{ hostname: 'l2sw1', ipaddr: '172.16.0.1', type: 'c3750g', protocol: 'ssh', username: "<%= ENV['L2SW_USER'] %>", password: 'password' }] }
          Then { preview[0][:host][:username] == 'yasuhito' }
          Then { preview[0][:spawn_cmd] =~ /-l yasuhito 172.16.0.1/ }
        end

        context 'embed password and embed enable password' do
          Given(:hosts) { [{ hostname: 'l2sw1', ipaddr: '172.16.0.1', type: 'c3750g', protocol: 'telnet', username: 'yasuhito', password: "<%= ENV['L2SW_PASS'] %>", enable: "<%= ENV['L2SW_EN_PASS'] %>" }] }
          Then { preview[0][:host][:password] == 'password' }
          Then { preview[0][:host][:enable] == 'p@ssw0rd' }
        end

        context 'embed command' do
          Given(:hosts) { [{ hostname: 'l2sw1', ipaddr: '172.16.0.1', type: 'c3750g', protocol: 'telnet', username: 'yasuhito', password: 'password', tftp_server: '192.168.0.33' }] }
          Given(:commands) { ['copy run tftp://<%= @host_param[:tftp_server] %>/<%= @host_param[:hostname] %>.confg'] }
          Then { preview[0][:commands] == ['copy run tftp://192.168.0.33/l2sw1.confg'] }
        end
      end

      context 'use local serial port with cu' do
        Given(:hosts) { [{ hostname: 'l2sw1', ipaddr: '172.16.0.2', type: 'ssg', protocol: 'cu', cu_opts: '-l /dev/ttyUSB0 -s 115200', username: 'yasuhito', password: 'password' }] }
        Given(:commands) { [] }

        context 'when commands is empty' do
          Then { preview[0][:spawn_cmd] == 'cu -l /dev/ttyUSB0 -s 115200 --parity=none' }
          Then { preview[0][:commands].empty? }
        end
      end
    end
  end
end
