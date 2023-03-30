source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in pulsar-job-rails.gemspec
gemspec

gem "rails"
gem "rice", "3.0.0"
gem "rake-compiler", github: "Seitk/rake-compiler", branch: "feature/make-install-path"
gem "pulsar-client", git: "https://github.com/Seitk/pulsar-client-ruby", branch: "master"

group :development, :test do
  gem "guard-rspec", require: false
  gem "rspec-rails"
  gem "awesome_print"
  gem "simplecov"
  gem "simplecov_json_formatter"
end
