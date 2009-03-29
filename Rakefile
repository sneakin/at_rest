# -*- ruby -*-

require 'rubygems'
require 'rake'
require 'spec/rake/spectask'

desc "Run all examples"
Spec::Rake::SpecTask.new('spec') do |t|
  t.ruby_opts = [ "-Ilib" ]
  t.spec_files = FileList['spec/**/*.rb']
  t.spec_opts = ["--format", "html:doc/spec.html", "--diff"]
end

# vim: syntax=Ruby
