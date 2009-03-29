require 'active_resource'

module At
  class Job < ActiveResource::Base
    self.site = 'http://localhost:4567'
  end
end
