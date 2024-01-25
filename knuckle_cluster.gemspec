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

  spec.add_dependency 'aws-sdk-core',        '~> 3'
  spec.add_dependency 'aws-sdk-ec2',         '~> 1'
  spec.add_dependency 'aws-sdk-ecs',         '~> 1'
  spec.add_dependency 'aws-sdk-autoscaling', '~> 1'
  spec.add_dependency 'rexml',               '~> 3'

  spec.add_dependency 'table_print', '~> 1.5'

  spec.bindir      = "bin"
  spec.executables = 'knuckle_cluster'
end
