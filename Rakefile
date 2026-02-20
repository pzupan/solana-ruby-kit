# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

namespace :sorbet do
  desc 'Run Sorbet type checker'
  task :check do
    sh 'srb tc'
  end

  desc 'Generate RBI files for gems'
  task :generate_rbi do
    sh 'bundle exec tapioca gems'
  end

  desc 'Generate RBI files for DSLs'
  task :generate_dsl do
    sh 'bundle exec tapioca dsl'
  end
end

task default: :spec
