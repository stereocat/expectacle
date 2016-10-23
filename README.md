# Expectacle

Expectacle ("expect + spectacle") is a small wrapper of `pty/expect`.
It can send commands (command-list) to hosts (including network devices etc)
using telnet/ssh session.

Expectacle is portable (instead of less feature).
Because it depends on only standard modules (YAML, ERB, PTY, Expect).
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

### Utility Script
See `bin/run_command` and `vendor` directory.

`run_command` can send commands to hosts.

    $ bundle exec ./bin/run_command l2switch.yml cisco_show_arp.yml

- `l2switch.yml` is host-list file.
  It is a data definitions for each hosts to send commands.
  - At username and password (login/enable) parameter,
    you can write environment variables with ERB manner to avoid write raw login information.
  - `bin/readne` is a small utility shell-script to set environment variable from CLI.

```
$ export L2SW_USER=`./bin/readne`
Input: (type username)
$ export L2SW_PASS=`./bin/readne`
Input: (type password)
```

- `SimpleCommandThrowre::Thrower` read prompt-file by "type" parameter in host-list file.
  - In prompt-file, prompt regexps that used for interactive operation to host
    are defined. (These regexp are common information for some host-groups. (vendor, OS, ...))
  - Prompt-file is searched by filename: `#{type}_prompt.yml`,
    `type` parameter defined in host-list file.
- `cisco_show_arp.yml` is command-list file.
  - it is a list of commands.
- Each files are written by YAML.

## Parameter Definitions

### Expectacle::Thrower

`Expectacle::Thrower` argument description.
- `:timeout` : (Optional) Timeout interval (sec) to connect a host. (default: 60sec)
- `:verbose` : (Optional) When `:verbose` is `false`,
  `Expectacle` does not output spawned process input/output to standard-out(`$stdout`).
  (default: `true`)
- `:base_dir`: (Optional) Base path to search host/prompt/command files.
  - `#{base_dir}/commands`: command-list file directory.
  - `#{base_dir}/prompts` : prompt-file directory.
  - `#{base_dir}/hosts` : host-file directory.
- `:logger` : (Optional) IO object to logging `Expectacle` operations. (default: `$stdout`)

**Notice** : When `Expectacle` success to connect(spawn) host,
it will change to privilege (root/super-user/enable) mode at first, ASAP.
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
See also: "Command list" section.

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

For example, if you want to save configuration of a cisco device to tftp server:
- Add a parameter to tftp server info (IP address) in host-list file. (`vendor/hosts/l2switch.yml`)
```YAML
- :hostname : 'l2sw1'
  :type : 'c3750g'
  :ipaddr : '192.168.0.1'
  :protocol : 'ssh'
  :username : "<%= ENV['L2SW_USER'] %>"
  :password : "<%= ENV['L2SW_PASS'] %>"
  :enable : "<%= ENV['L2SW_PASS'] %>"
  :tftp_server: '192.168.2.16'
- :hostname : 'l2sw2'
  :type : 'c3750g'
  :ipaddr : '192.168.0.2'
  :protocol : 'ssh'
  :username : "<%= ENV['L2SW_USER'] %>"
  :password : "<%= ENV['L2SW_PASS'] %>"
  :enable : "<%= ENV['L2SW_PASS'] %>"
  :tftp_server: '192.168.2.16'
```

- Write command-list file using ERB.
  When send a command to host, ERB string was evaluated in `Expectacle::Thrower` bindings.
  Then, it can refer host-parameter as `@host_param` hash. (`vendor/commands/cisco_save_config_tftp.yml`)
  -  When exec below command-list, host configuration will be saved a file as `l2sw1.confg` on tftp server.

```YAML
- "copy run start"
- "copy run tftp://<%= @host_param[:tftp_server] %>/<%= @host_param[:hostname] %>.confg"
```

## TODO

### Sub prompt operation (interactive command)
Feature for sub-prompt (interactive command) is not enough.
Now, Expectacle sends fixed command for sub-prompt.
(These actions were defined for cisco to execute above "copy run" example...)
- Yex/No (`:yn`) : always sends "yes"
- Sub prompt (`:sub1` and `:sub2`) : Empty string (RETURN)

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/stereocat/expectacle>.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
