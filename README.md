# SimpleCommandThrower

SimpleCommandThrower is a small wrapper of `pty/expect`.
It can send commands (command-list) to hosts (including network devices etc)
using telnet/ssh session.

SimpleCommandThrower is portable (instead of less feature).
Because it depends on only standard modules (YAML, ERB, PTY, Expect).
It can work on almost ruby(>2.2) system without installation other gems.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'simple_command_thrower'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install simple_command_thrower

## Usage

### Utility Script
See `bin/run_command` and `vendor` directory.

`run_command` can send commands to hosts.

    $ bundle exec ./bin/run_command l2switch.yml cisco_show_arp.yml

- `l2switch.yml` is host-list file.
  It is a data definitions for each hosts to send commands.
  - At username and password (login/enable) parameter,
    a user can write environment variables with ERB manner to avoid write raw login information.
  - `bin/readne` is a small utility shell-script to set environment variable from CLI.

```
$ export L2SW_USER=`./bin/readne`
Input: (type username)
$ export L2SW_PASS=`./bin/readne`
Input: (type password)
```

- `SimpleCommandThrowre::Arm` read prompt-file by "type" parameter in host-list file.
  - In prompt-file, prompt regexps that used for interactive operation to host
    are defined. (These regexp are common information for some host-groups. (vendor, OS, ...))
  - Prompt-file is searched by filename: `#{type}_prompt.yml`,
    `type` parameter defined in host-list file.
- `cisco_show_arp.yml` is command-list file.
  - it is a list of commands.
- Each files are written by YAML.

### `SimpleCommandThrower::Arm`

`SimpleCommandThrower::Arm` argument description.
- `:timeout` : (Optional) Timeout interval (sec) to connect a host. (default: 60sec)
- `:verbose` : (Optional) When `:verbose` is `false`,
  `SimpleCommandThrower` does not output spawned process input/output to standard-out(`$stdout`).
  (default: `true`)
- `:base_dir`: (Optional) Base path to search host/prompt/command files.
  - `#{base_dir}/commands`: command-list file directory.
  - `#{base_dir}/prompts` : prompt-file directory.
  - `#{base_dir}/hosts` : host-file directory.
- `:logger` : (Optional) IO object to logging `SimpleCommandThrower` operations. (default: `$stdout`)

**Notice** : When `SimpleCommandThrower` success to connect(spawn) host,
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

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/simple_command_thrower. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

