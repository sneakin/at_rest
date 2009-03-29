require 'open3'
require 'active_support'

module At
  class Error < RuntimeError
  end

  class Job
    attr_accessor :id, :at

    def initialize(attrs = Hash.new)
      @id = @at = @command = nil
      @destroyed = @changed = false
      @new_record = true

      self.attributes = attrs
    end

    def attributes
      { :id => id,
        :at => at,
        :existing => !new_record?,
        :command => command
      }
    end

    def attributes=(attrs)
      attrs = HashWithIndifferentAccess.new(attrs)

      self.id = attrs[:id] if attrs[:id]
      self.at = attrs[:at] if attrs[:at]
      @new_record = !attrs[:existing] if attrs[:existing]
      @command = attrs[:command] if attrs[:command]
    end

    def changed?
      @changed
    end

    def new_record?
      @new_record
    end

    def destroyed?
      @destroyed
    end

    def save
      new_job = self.class.queue_job(self)
      destroy

      self.attributes = new_job.attributes
      @destroyed = @changed = @new_record = false

      self
    end

    def destroy
      self.class.destroy(self)
      @destroyed = true
    end

    def command=(value)
      @command = value
      @changed = true
    end

    def command(reload = false)
      unless new_record?
        @command = self.class.query_job(self.id) if !@command || reload
      end

      @command
    end

    def at=(value)
      if value.kind_of? String
        @at = Time.parse(value)
      else
        @at = value.to_time
      end

      @changed = true
    end

    def to_xml(options = Hash.new)
      b = options[:builder] || Builder::XmlMarkup.new
      b.job do |j|
        j.id(id, :type => 'integer') if id
        j.at(at.utc.rfc822, :type => 'datetime')
        j.command do |c|
          c.cdata! command
        end
      end
    end

    def self.find(jid)
      if jid == :all
        find_all
      elsif jid.kind_of?(Fixnum) || jid.kind_of?(String)
        find_by_id(jid)
      else
        raise ArgumentError.new(":all or Fixnum or String allowed")
      end
    end

    def self.find_by_id(jid)
      find_all.find { |job|
        job.id == jid.to_i
      }
    end

    def self.find_all
      run("atq").split("\n").collect do |line|
        job_id, time = line.split("\t")
        self.new(:id => job_id.to_i, :at => Time.parse(time), :existing => true)
      end
    end

    def self.run(*cmd, &block)
      if block_given?
        Open3.popen3(*cmd, &block)
      else
        `#{cmd.join(' ')}`
      end
    end

    MARKER = "#### ATREST MARKER ####"

    def self.query_job(job_id)
      output = run("at -c #{job_id}")
      idx = output.rindex(MARKER)

      if idx
        idx = idx + output[idx..-1].index("\n")
        output[(idx + 1)..-1].strip
      else
        output
      end
    end

    def self.queue_job(job)
      output = run("at", job.at.localtime.strftime("%H:%M %Y-%m-%d")) do |i, o, e|
        i.puts MARKER
        i.puts job.command
        i.close

        e.read
      end

      m = nil
      output.split("\n").each do |line|
        m = line.match(/^job (\d+) at (.*)$/)
        break m if m
      end

      raise Error.new("unexpected output while queuing job: #{output.inspect}") unless m

      job_id, time = m[1], m[2]
      $stderr.puts "Creating job #{job_id.inspect} #{time.inspect}"
      self.new(:id => job_id.to_i, :at => Time.parse(time), :existing => true)
    end

    def self.destroy(job)
      run("atrm #{job.id}")
    end
  end
end

if __FILE__ == $0
  At::Job.find(:all).each do |job|
    puts "%i\t%s" % [ job.id, job.at ]
    puts "\t%s" % [ job.command.split("\n").last ]
  end
end
