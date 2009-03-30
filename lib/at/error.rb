module At
  class Error < RuntimeError
    def initialize(job, msg)
      super(msg)

      @job = job
    end

    def message
      "Job(id: #{@job.id.inspect}, at: #{@job.at.inspect}, command: #{@job.command.inspect}): #{super}"
    end
  end

  class NotFoundError < RuntimeError
  end
end
