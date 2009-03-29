require 'rubygems'
require 'spec'
require 'at'

describe At::Job do
  before(:all) do
    @all_jobs = Array.new
  end

  before(:each) do
    @jobs = Array.new
    3.times do |i|
      job = At::Job.new(:at => 30.minutes.from_now, :command => 'ls').save
      @jobs << job
      @all_jobs << job
    end
  end

  after(:all) do
    @all_jobs.each do |job|
      job.destroy
    end
  end

  describe '.find' do
    describe '(:all)' do
      it "returns every job" do
        jobs = At::Job.find(:all)
        $stderr.puts jobs.inspect
        $stderr.puts @jobs.inspect
        @jobs.each do |job|
          jobs.should include(job)
        end
      end
    end

    describe '(Fixnum)' do
      describe 'with a valid id' do
        it "returns the job" do
          At::Job.find(@jobs.first.id).should == @jobs.first
        end
      end

      describe 'with a bad id' do
        it "raises an error" do
          lambda { At::Job.find(123455) }.should raise_error
        end
      end
    end
  end

  describe '#save' do
    describe 'on an unchanged job' do
      before(:each) do
        @job = At::Job.find(@jobs.first.id)
      end

      it "does nothing" do
        $stderr.puts @job.inspect
        At::Job.should_not_receive(:run)
        @job.save
      end
    end

    describe 'on a changed job' do
      def assert_time(a, b)
        [ :hour, :min, :year, :month, :day ].each do |attr|
          a.send(attr).should == b.send(attr)
        end
      end

      describe 'on an existing job' do
        before(:each) do
          @job = At::Job.find(@jobs.first.id)
          @job.at = 1.hour.from_now
          @job.command = 'echo hello'
        end

        after(:each) do
          @job.destroy
        end

        it "gets a new id" do
          lambda { @job.save }.should change(@job, :id)
        end

        it "is no longer a changed" do
          lambda { @job.save }.should change(@job, :changed?).to(false)
        end

        it "has the same at time" do
          at = @job.at
          @job.save
          assert_time(at, @job.at)
        end

        it "has the same at time even after reloading" do
          at = @job.at
          @job.save

          @job = At::Job.find(@job.id)
          assert_time(at, @job.at)
        end

        it "has the same command" do
          lambda { @job.save }.should_not change(@job, :command)
        end
      end

      describe 'on a new job' do
        before(:each) do
          @job = At::Job.new(:at => 30.minutes.from_now, :command => 'ls')
        end

        it "gets an id" do
          lambda { @job.save }.should change(@job, :id)
        end

        it "is no longer a changed" do
          lambda { @job.save }.should change(@job, :changed?).to(false)
        end

        it "is no longer a new record" do
          lambda { @job.save }.should change(@job, :new_record?).to(false)
        end

        it "has the same at time" do
          at = @job.at
          @job.save
          assert_time(at, @job.at)
        end

        it "has the same command" do
          lambda { @job.save }.should_not change(@job, :command)
        end
      end
    end
  end

  describe '#destroy' do
    before(:each) do
      @job = @jobs.first
    end

    it "destroys the job" do
      jid = @job.id
      @job.destroy

      lambda { At::Job.find(jid) }.should raise_error
    end

    it "freezes the job" do
      @job.destroy
      @job.should be_frozen
    end

    it "is destroyed" do
      @job.destroy
      @job.should be_destroyed
    end
  end
end
