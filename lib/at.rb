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

    def self.query_job(job_id)
      output = run("at -c #{job_id}")
      idx = output.rindex("export OLDPWD")
      idx = idx + output[idx..-1].index("\n")
      output[(idx + 1)..-1].strip
    end

    def self.queue_job(job)
      output = run("at", "-t", job.at.localtime.strftime("%Y%m%d%H%M")) do |i, o, e|
        i.puts job.command
        i.close

        e.read
      end

      m = output.match(/^job (\d+) at (.*\d{4})+$/)
      raise Error.new("unexpected output while queuing job") unless m

      job_id, time = m[1], m[2]
      self.new(:id => job_id.to_i, :at => Time.parse(time), :existing => true)
    end

    def self.destroy(job)
      run("atrm #{job.id}")
    end
  end
end

if __FILE__ == $0 && ENV['SPEC']
  require 'spec'

  describe At::Job do
    before(:each) do
      @job = At::Job.new
    end

    describe '.find' do
      describe 'with :all' do
        it "calls and returns #find_all" do
          At::Job.should_receive(:find_all).and_return(:jobs)
          At::Job.find(:all).should == :jobs
        end
      end

      describe 'with a Fixnum' do
        it "calls #find_by_id" do
          At::Job.should_receive(:find_by_id).with(123).and_return(:job)
          At::Job.find(123).should == :job
        end
      end
    end

    describe '.find_by_id' do
      it "returns the Job whose job id matches the Fixnum" do
        @job = At::Job.new(:id => 2, :at => Time.now)
        At::Job.should_receive(:find_all).and_return([ At::Job.new(:id => 1, :at => Time.now), @job ] )

        At::Job.find(2).should == @job
      end
    end

    describe '.find_all' do
      it "calls atq and returns a Job for each entry" do
        At::Job.should_receive(:run).with("atq").and_return("1\tSat Mar 28 17:03:00 2009\n2\tSun Apr 01 01:00 2009\n")

        jobs = At::Job.find_all
        jobs[0].id.should == 1
        jobs[0].at.should == Time.parse("2009/03/28 17:03")
        jobs[1].id.should == 2
        jobs[1].at.should == Time.parse("2009/04/01 01:00")
      end
    end

    describe '.run' do
      describe 'when given a block' do
        it "passes the command and block to popen3" do
          Open3.should_receive(:popen3).with("at", "-c", "55")
          At::Job.run("at", "-c", "55") do |i, o, e|
          end
        end
      end

      describe 'with no block' do
        it "executes the command" do
          At::Job.run("ls -a").should == `ls -a`
        end
      end
    end
    describe '.queue_job' do
      before(:each) do
        @job = At::Job.new(:id => 123, :at => Time.now, :command => 'ls')
      end

      it "runs at with the job's time" do
        At::Job.should_receive(:run).with("at", "-t", @job.at.strftime("%Y%m%d%H%M")).and_return("job 57 at Sun Mar 29 05:00:00 2009\n")

        At::Job.queue_job(@job)
      end

      it "returns the queued job's attributes" do
        At::Job.should_receive(:run).
          with("at", "-t", @job.at.localtime.strftime("%Y%m%d%H%M")).
          and_return("job 57 at Sun Mar 29 05:00:00 2009\n")

        new_job = At::Job.queue_job(@job)
        new_job.id.should == 57
        new_job.at.should == Time.parse("Sun Mar 29 05:00:00 2009")
      end

      it "writes the command to at and closes the input stream before reading the job's info" do
        @i = mock(Object)
        @i.should_receive(:puts).with(@job.command)
        @i.should_receive(:close)
        @o = nil
        @e = mock(Object)
        @e.should_receive(:read).and_return("job 57 at Sun Mar 29 05:00:00 2009\n")

        At::Job.should_receive(:run).and_yield(@i, @o, @e)
        At::Job.queue_job(@job)
      end

      it "raises an Error if the output is not recoginized" do
        Open3.should_receive(:popen3).and_return("job 57 at your mother's house")
        lambda { At::Job.queue_job(@job) }.should raise_error(At::Error)
      end
    end

    describe '#save' do
      before(:each) do
        @new_job = At::Job.new(:id => 987, :at => Time.now, :command => 'echo hello')
        At::Job.stub!(:queue_job).and_return(@new_job)
      end

      it "queues the job" do
        At::Job.should_receive(:queue_job).with(@job)

        @job.save
      end

      describe 'on an existing job' do
        before(:each) do
          @job = At::Job.new(:id => 123, :at => Time.now, :command => 'ls')
        end

        it "deletes the job with the old id" do
          @job.should_receive(:destroy)
          @job.save
        end

        it "updates the new attributes" do
          @new_job = At::Job.new(:id => 987, :at => Time.now, :command => 'echo hello')
          At::Job.should_receive(:queue_job).with(@job).and_return(@new_job)
          @job.should_receive(:attributes=).with(@new_job.attributes)

          @job.save
        end
      end

      describe 'on a new job' do
        it "gets an id" do
          lambda { @job.save }.should change(@job, :id)
        end
      end
    end

    describe 'at' do
      before(:each) do
        @job = At::Job.new(:at => Time.parse("2009/04/01 12:00"))
      end

      it "returns the time the job is scheduled" do
        @job.at.should == Time.parse("2009/04/01 12:00")
      end
    end

    describe 'at=' do
      it "sets the time the job is scheduled" do
        lambda { @job.at = Time.parse("2009/04/01 12:00") }.should change(@job, :at).to(Time.parse("2009/04/01 12:00"))
      end

      it "marks the job as changed" do
        lambda { @job.at = Time.now }.should change(@job, :changed?).to(true)
      end
    end

    describe '#command' do
      describe 'on an existing job' do
        before(:each) do
          @job = At::Job.new(:id => 123, :at => Time.parse("2009/04/01 12:00"), :existing => true)
        end

        describe 'when the command has not been set' do
          it "runs 'at -c' and returns the result" do
            At::Job.should_receive(:run).with("at -c #{@job.id}").and_return("export OLDPWD\nls")
            @job.command.should == "ls"
          end
        end

        describe 'when the command has been set' do
          before(:each) do
            @job.command = "cat /etc/passwd"
          end

          it "returns the new command" do
            @job.command.should == "cat /etc/passwd"
          end
        end
      end

      describe 'on a new job' do
        before(:each) do
          @job = At::Job.new(:at => Time.now, :command => 'echo hello')
        end

        it "returns the new command" do
          @job.command.should == 'echo hello'
        end
      end
    end

    describe '#command=' do
      it "changes the command" do
        lambda { @job.command = 'echo hello' }.should change(@job, :command).to("echo hello")
      end

      it "marks the job as changed" do
        lambda { @job.command = 'echo hello' }.should change(@job, :changed?).to(true)
      end
    end

    describe '#id' do
      before(:each) do
        @job = At::Job.new(:id => 123)
      end

      it "returns the id" do
        @job.id.should == 123
      end
    end
  end
elsif __FILE__ == $0
  At::Job.find(:all).each do |job|
    puts "%i\t%s" % [ job.id, job.at ]
    puts "\t%s" % [ job.command.split("\n").last ]
  end
end
