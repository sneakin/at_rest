require 'rubygems'
require 'spec'
require 'at'

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
      At::Job.should_receive(:run).with("at", @job.at.strftime("%H:%M %m/%d/%Y")).and_return("job 57 at Sun Mar 29 05:00:00 2009\n")

      At::Job.queue_job(@job)
    end

    it "returns the queued job's attributes" do
      At::Job.should_receive(:run).
        with("at", anything).
        and_return("job 57 at Sun Mar 29 05:00:00 2009\n")

      new_job = At::Job.queue_job(@job)
      new_job.id.should == 57
      new_job.at.should == Time.parse("Sun Mar 29 05:00:00 2009")
    end

    it "writes the command to at and closes the input stream before reading the job's info" do
      @i = mock(Object)
      @i.should_receive(:puts).with(At::Job::MARKER)
      @i.should_receive(:puts).with(@job.command)
      @i.should_receive(:close)
      @o = nil
      @e = mock(Object)
      @e.should_receive(:read).and_return("job 57 at Sun Mar 29 05:00:00 2009\n")

      At::Job.should_receive(:run).and_yield(@i, @o, @e)
      At::Job.queue_job(@job)
    end

    it "raises an Error if the output is not recoginized" do
      Open3.should_receive(:popen3).and_return("job one at your mother's house")
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
        describe 'with a marker in the command' do
          it "runs 'at -c' and returns the post-marker result" do
            At::Job.should_receive(:run).with("at -c #{@job.id}").and_return("echo garbage\n#{At::Job::MARKER}\nls")
            @job.command.should == "ls"
          end
        end

        describe 'without a marker in the command' do
          it "runs 'at -c' and returns the entirye result" do
            At::Job.should_receive(:run).with("at -c #{@job.id}").and_return("echo hello\nls")
            @job.command.should == "echo hello\nls"
          end
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
