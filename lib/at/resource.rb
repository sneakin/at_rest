require 'active_resource'
require 'at/error'

module At
  class Job < ActiveResource::Base
    self.site = 'http://localhost:4567'
  end
end
