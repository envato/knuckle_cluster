# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'knuckle_cluster/version'

Gem::Specification.new do |spec|
  spec.name          = "knuckle_cluster"
  spec.version       = KnuckleCluster::VERSION
  spec.authors       = ["Envato"]
  spec.email         = ["rubygems@envato.com"]

  spec.summary       = %q{Handy cluster tool}
  spec.description   = %q{Interrogation of AWS ECS clusters, with the ability to directly connect to hosts and containers.}
  spec.homepage      = "https://github.com/envato/knuckle_cluster"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_dependency 'aws-sdk', '~> 2.8'
  spec.add_dependency 'table_print', '~> 1.5'

  spec.bindir      = "bin"
  spec.executables = 'knuckle_cluster'
end
