# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'knuckle_cluster/version'

Gem::Specification.new do |spec|
  spec.name          = "knuckle_cluster"
  spec.version       = KnuckleCluster::VERSION
  spec.authors       = ["Peter Hofmann"]
  spec.email         = ["peter@envato.com"]

  spec.summary       = %q{Handy cluster tool}
  spec.description   = %q{Ever wanted to shuck away the hard, rough exterior of an ECS cluster and get to the soft, chewy innards? Sounds like you need KnuckleCluster!}
  spec.homepage      = "https://github.com/envato/knuckle_cluster"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.envato.net"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"


  spec.add_dependency 'aws-sdk', '~> 2.8'
  spec.add_dependency 'table_print'
end
