# -*- ruby -*-

require 'rubygems'
require 'rake'
require 'spec/rake/spectask'

namespace :spec do
  desc "Run all unit specs"
  Spec::Rake::SpecTask.new('unit') do |t|
    t.ruby_opts = [ "-Ilib" ]
    t.spec_files = FileList['spec/unit/**/*.rb']
    t.spec_opts = ["--format", "html:doc/spec.unit.html", "--format", "specdoc"]
  end

  desc "Run all integration specs"
  Spec::Rake::SpecTask.new('integration') do |t|
    t.ruby_opts = [ "-Ilib" ]
    t.spec_files = FileList['spec/integration/**/*.rb']
    t.spec_opts = ["--format", "html:doc/spec.integration.html", "--format", "specdoc"]
  end
end

desc "Run all specs"
task :spec => [ "spec:unit", "spec:integration" ]

# vim: syntax=Ruby
