# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'expectacle/version'

Gem::Specification.new do |spec|
  spec.name          = 'expectacle'
  spec.version       = Expectacle::VERSION
  spec.authors       = ['stereocat']
  spec.email         = ['stereocat@gmail.com']

  spec.summary       = 'Simple expect wrapper to send commands to a devices.'
  spec.description   = 'Expectacle is simple wrapper of pty/expect.'
  spec.homepage      = 'https://github.com/stereocat/expectacle'
  spec.license       = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake', '~> 10.0'
end
