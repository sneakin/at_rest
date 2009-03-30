require 'sinatra'
require 'active_resource' # needed for some exception classes

if ENV['REMOTE']
  require 'at/resource'
  At::Job.site = ENV['REMOTE']
else
  require 'at'
end

def created(url)
  status 201
  response['Location'] = url
  halt
end

def gone(url)
  status 410
  response['Location'] = url
  halt
end

enable :sessions
set :public, File.dirname(__FILE__) + '/../static'
set :views, File.dirname(__FILE__) + '/../templates'

def jobs_path(format)
  "/jobs.#{format}"
end

def job_path(jid, format)
  "/jobs/#{jid}.#{format}"
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

def flash(msg = nil)
  if msg
    session[:flash] ||= Array.new
    session[:flash] << msg
  end

  session[:flash] || Array.new
end

before do
  @flash = session[:flash]
  session[:flash] = Array.new
end

error do
  @title = "Unexpected Error"
  @error = request.env['sinatra.error']
  erb :error
end

not_found do
  @title = "Not Found"
  @path = request.fullpath
  erb :not_found
end

get '/' do
  redirect jobs_path('html')
end

get /\/jobs\.(xml|html)/ do |format|
  @title = "Jobs"
  @jobs = At::Job.find(:all)

  if format == 'html'
    erb :index
  else
    content_type 'application/xml', :charset => 'utf-8'
    @jobs.to_xml(:root => 'jobs')
  end
end

def create_job
  begin
    xml_data = Hash.from_xml(request.body)
    @job = At::Job.new(xml_data['job'])
  rescue NoMethodError
    @job = At::Job.new(params['job'])
  end

  @job.save
end

post '/jobs.xml' do
  create_job
  created(job_path(@job.id, "xml"))
end

get '/jobs/new.html' do
  @title = "New Job"
  @job = At::Job.new(:at => 5.minutes.from_now, :command => '')
  erb :job
end

post '/jobs/new.html' do
  create_job
  flash("Created <a href=\"#{job_path(@job.id, 'html')}\">job #{@job.id}</a>.")
  redirect(jobs_path("html"))
end

get /\/jobs\/(\d+)\.(xml|html)/ do |jid, format|
  begin
    @job = At::Job.find(jid)
    @title = "Job #{@job.id}"

    if format == 'html'
      erb :job
    else
      content_type 'application/xml', :charset => 'utf-8'
      @job.to_xml(:root => 'jobs')
    end
  rescue At::NotFoundError, ActiveResource::ResourceNotFound
    not_found
  end
end

def put_job(jid, format)
  @job = At::Job.find(jid)

  begin
    xml_data = Hash.from_xml(request.body.read)
    @job.attributes = xml_data['job'].merge('id' => @job.id)
  rescue NoMethodError
    @job.attributes = params['job'].merge('id' => @job.id)
  end
  
  if params['commit'] =~ /Destroy/i
    @job.destroy
    flash("Destroyed job #{@job.id}.")
    redirect jobs_path("html")
  else
    @job.save

    if format == 'html'
      flash("Saved <a href=\"#{job_path(@job.id, 'html')}\">job #{@job.id}</a>.")
      redirect jobs_path("html")
    else
      @job.to_xml
    end
  end
rescue At::NotFoundError, ActiveResource::ResourceNotFound
  not_found
end

post /\/jobs\/(\d+)\.(xml|html)/ do |jid, format|
  put_job(jid, format)
end

put /\/jobs\/(\d+)\.(xml|html)/ do |jid, format|
  put_job(jid, format)
end

delete '/jobs/:id.xml' do |jid|
  @job = At::Job.find(jid)

  if @job
    @job.destroy
    "Ok"
  else
    not_found
  end
end
