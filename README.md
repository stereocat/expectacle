# Expectacle
[![Gem Version](https://badge.fury.io/rb/expectacle.svg)](https://badge.fury.io/rb/expectacle)

Expectacle ("expect + spectacle") is a small wrapper of `pty`/`expect`.
It can send commands (command-list) to hosts (including network devices etc)
using telnet/ssh session.

Expectacle is portable (instead of less feature).
Because it depends on only standard modules (YAML, ERB, PTY, Expect and Logger).
It can work on almost ruby(>2.2) system without installation other gems. (probably...)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'expectacle'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install expectacle

## Usage

### Send commands to hosts
See [exe/run_command](./exe/run_command) and [vendor directory](./vendor).

`run_command` can send commands to hosts with `-r`/`--run` option.

    $ bundle exec run_command -r -h l2switch.yml -c cisco_show_arp.yml

- See details of command line options with `--help` option.
- [l2switch.yml](./vendor/hosts/l2switch.yml) is host-list file.
  It is a data definitions for each hosts to send commands.
  - At username and password (login/enable) parameter,
    you can write environment variables with ERB manner to avoid write raw login information.
  - [exe/readne](./exe/readne) is a small bash script to set environment variable in your shell.

```
$ export L2SW_USER=`./exe/readne`
Input: (type username)
$ export L2SW_PASS=`./exe/readne`
Input: (type password)
```

- `Expectacle::Thrower` read prompt-file by "type" parameter in host-list file.
  - In prompt-file, prompt regexps that used for interactive operation to host
    are defined. (These regexp are common information for some host-groups. (vendor, OS, ...))
  - Prompt-file is searched by filename: `#{type}_prompt.yml` from [prompts directory](./vendor/prompts).
    `type` parameter defined in host-list file.
- [cisco_show_arp.yml](./vendor/commands/cisco_show_arp.yml) is command-list file.
  - it is a list of commands.
- Each files are written by YAML.

### Parameter expansion and preview
Expectacle has parameter expansion feature using ERB.
In a command list file,
you can write command strings including environment variable and parameters defined in host file.
See [Parameter definitions](#parameter-definitions) section about details of parameter expansion feature.

Thereby, there are some risks sending danger commands by using wrong parameter and command definitions.

Then, you can preview expanded command strings to send a host and parameters before execute actually.
For Example:
```
stereocat@tftpserver:~/expectacle$ bundle exec run_command -p -h l2switch.yml -c cisco_save_config_tftp.yml
---
:spawn_cmd: ssh -o StrictHostKeyChecking=no -o KexAlgorithms=+diffie-hellman-group1-sha1
  -l cisco 192.168.20.150
:prompt:
  :password: "^Password\\s*:"
  :username: "^Username\\s*:"
  :sub1: "\\][:\\?]"
  :sub2: "\\[confirm\\]"
  :yn: "\\[yes\\/no\\]:"
  :command1: "^[\\w\\-]+>"
  :command2: "^[\\w\\-]+(:?\\(config\\))?\\#"
  :enable_password: SAME_AS_LOGIN_PASSWORD
  :enable_command: enable
:host:
  :hostname: l2sw1
  :type: c3750g
  :ipaddr: 192.168.20.150
  :protocol: ssh
  :username: cisco
  :password: ********
  :enable: ********
  :tftp_server: 192.168.20.170
:commands:
- copy run start
- copy run tftp://192.168.20.170/l2sw1.confg
---
(snip)
```
**Notice** : Passwords were masked above example, but actually, raw password strings are printed out.

### Change place of log message

With `-l`/`--logfile`, [run_command](./exe/run_command) changes logging IO to file instead of standard-out (default).

    $ bundle exec run_command -r -l foo.log -h l2switch.yml -c cisco_show_arp.yml

With `-s`/`--syslog`, [run_command](./exe/run_command) changes logging instance to `syslog/logger`.
So, log messages are printed out to syslog on localhost.

    $ bundle exec run_command -rs -h l2switch.yml -c cisco_show_arp.yml

**Notice** : When specified `--logfile` and `--syslog` at the same time, `--syslog` is used to logging.

### Quiet mode

With `-q`/`--quiet`, [run_command](./exe/run_command) stop printing out results
received from a host to standard out. For example:

    $ bundle exec run_command -rq -h l2switch.yml -c cisco_show_arp.yml

the command prints only log message (without host output) to standard out.
If you use options syslog(`-s`) and quiet(`-q`),
there is nothing to be appeared in terminal (standard out).

    $ bundle exec run_command -rqs -h l2switch.yml -c cisco_show_arp.yml

## Parameter Definitions

### Expectacle::Thrower

`Expectacle::Thrower` argument description.
- `:timeout` : (Optional) Timeout interval (sec) to connect a host.
  (default: 60sec)
- `:verbose` : (Optional) When `:verbose` is `false`,
  `Expectacle` does not output spawned process input/output to standard-out(`$stdout`).
  (default: `true`)
- `:base_dir`: (Optional) Base path to search host/prompt/command files. 
  (default: current working directory (`Dir.pwd`))
  - `#{base_dir}/commands`: command-list file directory.
  - `#{base_dir}/prompts` : prompt-file directory.
  - `#{base_dir}/hosts` : host-file directory.
- `:logger` : (Optional) IO object to logging `Expectacle` operations.
  (default: `$stdout`)

**Notice** : When `Expectacle` success to connect(spawn) host,
it will change the user mode to privilege (root/super-user/enable) at first, ASAP.
All commands are executed with privilege mode at the host.

### Host-list parameter
Host-list file is a list of host-parameters.
- `:hostname`: Indication String of host name.
- `:type`: Host type (used to choose prompt-file).
- `:ipaddr`: IP(v4) address to connect host.
- `:protocol`: Protocol to connect host. (telnet or ssh)
- `:username`: Login name.
- `:password`: Login password.
- `:enable`: Password to be privilege mode.

It can use ERB to set values from environment variable in `:username`, `:password` and `:enable`.

You can add other parameter(s) to refer in command-list files.
See also: [Command list](#command-list-with-erb) section.

### Prompt parameter
Prompt file is a table of prompt regexp of host group(type).
- `:password`: Login password prompt
- `:username`: Login username prompt
- `:sub1`: Sub command prompt
- `:sub2`: Sub command prompt
- `:yn`: Yes/No prompt
- `:command1`: Command prompt (normal mode)
- `:command2`: Command prompt (privilege mode)
- `enable_password`: Enable password prompt
- `enable_command`: command to be privilege mode
  (Only this parameter is not a "prompt regexp")

### Command list with ERB
Command-list is a simple list of command-string.
A command-string can contain host-parameter reference by ERB.

For example, if you want to save configuration of a Cisco device to tftp server:
- Add a parameter to tftp server info (IP address) in [host-list file](vendor/hosts/l2switch.yml).
```YAML
- :hostname : 'l2sw1'
  :type : 'c3750g'
  :ipaddr : '192.168.20.150'
  :protocol : 'ssh'
  :username : "<%= ENV['L2SW_USER'] %>"
  :password : "<%= ENV['L2SW_PASS'] %>"
  :enable : "<%= ENV['L2SW_PASS'] %>"
  :tftp_server: '192.168.20.170'
- :hostname : 'l2sw2'
  :type : 'c3750g'
  :ipaddr : '192.168.20.151'
  :protocol : 'ssh'
  :username : "<%= ENV['L2SW_USER'] %>"
  :password : "<%= ENV['L2SW_PASS'] %>"
  :enable : "<%= ENV['L2SW_PASS'] %>"
  :tftp_server: '192.168.20.170'
```

- Write [command-list file](vendor/commands/cisco_save_config_tftp.yml) using ERB.
  When send a command to host, ERB string was evaluated in `Expectacle::Thrower` bindings.
  Then, it can refer host-parameter as `@host_param` hash.
  - When exec below command-list, host configuration will be saved a file as `l2sw1.confg` on tftp server.
  - See also: [parameter preview](#parameter-expansion-and-preview) section.

```YAML
- "copy run start"
- "copy run tftp://<%= @host_param[:tftp_server] %>/<%= @host_param[:hostname] %>.confg"
```

## Default SSH Options

When use `ssh` (OpenSSH) command to spawn device, the user can set options for the command via `#{base_dir}/opts/ssh_opts.yml`.
With options as list in [ssh_opts.yml](./vendor/opts/ssh_opts.yml),
```
- '-o StrictHostKeyChecking=no'
- '-o KexAlgorithms=+diffie-hellman-group1-sha1'
- '-o Ciphers=+aes128-cbc,3des-cbc,aes192-cbc,aes256-cbc'
```
it works same as `~/.ssh/config` below.
```
Host *
    StrictHostKeyChecking no
    KexAlgorithms +diffie-hellman-group1-sha1
    Ciphers +aes128-cbc,3des-cbc,aes192-cbc,aes256-cbc
```

## Use Local Serial Port

Expectacle can handle `cu` (call up another system) command to operate via device local serial port.

At first, install `cu`. If you use Ubuntu, install it with `apt`.
```
sudo apt install cu
```

Next, set parameter `:protocol` to `cu`, and write `cu` command options as `:cu_opts`. Usually, one serial port correspond to one device. So host parameter `:cu_opts` is used as options to connect a host via serial port. For example:
```
- :hostname : 'l2sw1'
  :type : 'c3750g'
  :protocol : 'cu'
  :cu_opts : '-l /dev/ttyUSB0 -s 9600'
```
File `#{base_dir}/opts/cu_opts.yml` has default options for `cu` command.

At last, execute by `run_command` with `sudo`. Because it requires superuser permission to handle local device.
```
sudo -E bundle exec run_command -r -h l2switch.yml -c cisco_show_version.yml
```
**Notice** : Without `sudo -E` (`--preserve-env`) option, it do not preserve environment variables such as username/password and others you defined.

## TODO

### Sub prompt operation (interactive command)
Feature for sub-prompt (interactive command) is not enough.
Now, Expectacle sends fixed command for sub-prompt.
(These actions were defined for cisco to execute above "copy run" example...)
- Yex/No (`:yn`) : always sends "yes"
- Sub prompt (`:sub1` and `:sub2`) : always sends Empty string (RETURN)

### Error handling
Expectacle does not have error message handling feature.
If a host returns a error message when expectacle sent a command,
then expectacle ignores it and continue sending rest commands (until command list is empty).

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/stereocat/expectacle>.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
