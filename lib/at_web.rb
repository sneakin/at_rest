require 'sinatra'
require 'at'

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

set :views, File.dirname(__FILE__) + '/../templates'

get /\/jobs\.(xml|html)/ do |format|
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
    puts xml_data.inspect
    @job = At::Job.new(xml_data['job'])
  rescue NoMethodError
    @job = At::Job.new(params['job'])
  end

  @job.save
end

post '/jobs.xml' do
  create_job
  created("/jobs/#{@job.id}.xml")
end

get '/jobs/new.html' do
  @job = At::Job.new
  erb :job
end

post '/jobs/new.html' do
  create_job
  redirect("/jobs/#{@job.id}.html")
end

get /\/jobs\/(\d+)\.(xml|html)/ do |jid, format|
  @job = At::Job.find(jid)

  if @job
    if format == 'html'
      erb :job
    else
      content_type 'application/xml', :charset => 'utf-8'
      @job.to_xml(:root => 'jobs')
    end
  else
    not_found
  end
end

def put_job(jid, format)
  @job = At::Job.find(jid)

  if @job
    begin
      xml_data = Hash.from_xml(request.body.read)
      puts xml_data.inspect
      @job.attributes = xml_data['job']
    rescue NoMethodError
      @job.attributes = params['job']
    end
    
    @job.save

    if format == 'html'
      redirect "/jobs/#{@job.id}.html"
    else
      @job.to_xml
    end
  else
    not_found
  end
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
