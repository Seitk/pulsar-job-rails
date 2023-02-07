# require "rails"

# module PulsarJob
#   class Engine < ::Rails::Engine
#     config.generators do |g|
#       g.orm :mongoid
#       g.test_framework :rspec, fixture: false
#       g.fixture_replacement :factory_girl, dir: 'spec/factories'
#       g.assets false
#       g.helper false
#       g.stylesheets false
#       g.javascripts false
#     end

#     config.to_prepare do
#       Dir.glob(Rails.root + "app/jobs/**/*.rb").each do |c|
#         require_dependency(c)
#       end
#     end
#   end
# end
