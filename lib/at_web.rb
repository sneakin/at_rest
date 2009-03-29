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

get '/jobs.xml' do
  @jobs = At::Job.find(:all)

  content_type 'application/xml', :charset => 'utf-8'
  @jobs.to_xml(:root => 'jobs')
end

post '/jobs.xml' do
  xml_data = Hash.from_xml(request.body)
  puts xml_data.inspect
  @job = At::Job.new(xml_data['job'] || params['job'])
  @job.save

  created("//jobs/#{@job.id}.xml")
end

get '/jobs/:id.xml' do |jid|
  @job = At::Job.find(jid)

  if @job
    content_type 'application/xml', :charset => 'utf-8'
    @job.to_xml(:root => 'jobs')
  else
    not_found
  end
end

put '/jobs/:id.xml' do |jid|
  @job = At::Job.find(jid)

  if @job
    xml_data = Hash.from_xml(request.body)
    puts xml_data.inspect
    @job.attributes = xml_data['job'] || params['job']
    @job.save

    @job.to_xml
  else
    not_found
  end
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
