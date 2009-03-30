require 'rubygems'
require 'sinatra'

lib = File.join(File.dirname(__FILE__), "lib")
$: << lib

set :run, false
set :environment, :production
set :app_file, File.join(lib, "at_web.rb")

require 'at_web'

run Sinatra::Application