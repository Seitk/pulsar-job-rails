# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require "pulsar-job-rails/version"

Gem::Specification.new do |spec|
  spec.name          = "pulsar-job-rails"
  spec.version       = PulsarJob::VERSION
  spec.authors       = ["Philip Yu"]
  spec.email         = ["ht.yu@me.com"]

  spec.summary       = %q{Pulsar job for Rails.}
  spec.description   = %q{Pulsar job for Rails.}
  spec.homepage      = "https://shopline.hk"
  spec.license       = "MIT"

  spec.bindir = 'bin'
  spec.executables << "pulsar_job"
  spec.files = Dir["{app,config,lib,bin}/**/*", "MIT-LICENSE", "README.md"]
  spec.require_paths = ["lib"]
  spec.test_files = Dir["spec/**/*"]

  spec.add_dependency "pulsar-client"
  spec.add_dependency "optparse"
  spec.add_development_dependency "rails"
end
