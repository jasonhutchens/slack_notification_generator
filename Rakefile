# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = "slack_notification_generator"
  gem.homepage = "http://github.com/JasonHutchens/slack_notification_generator"
  gem.license = "UNLICENSE"
  gem.summary = %Q{Sends notifications to Slack when your CI system deploys your project.}
  gem.description = %Q{Does what it says on the tin.}
  gem.email = "jasonhutchens@gmail.com"
  gem.authors = ["Jason Hutchens"]
  gem.required_ruby_version = "~> 2.2"
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

task :default => :clean

require 'yard'
YARD::Rake::YardocTask.new
