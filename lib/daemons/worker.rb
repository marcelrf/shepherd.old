#!/usr/bin/env ruby

# environment setup
ENV["RAILS_ENV"] ||= "development"
root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)
require File.join(root, "config", "environment")

# load main library
include WorkerLib

# globals
@@threads = {}

# sigterm listener
$running = true
Signal.trap("TERM") do
  $running = false
end

# start threads
Rails.logger.info "[#{Time.now.utc}] WORKER: Summoned."
queue_workers = get_queue_workers
queue_workers.each do |queue, workers|
  workers.times do
    thread = Thread.new {
      loop do
        Rails.logger.info "Worker thread #{queue} starting..."
        work(queue)
        Rails.logger.info "Worker thread #{queue} finishing..."
        sleep 10
      end
    }
    @@threads[thread] = queue
  end
end
Rails.logger.info "[#{Time.now.utc}] WORKER: Started #{@@threads.size} threads."

# daemon loop
while($running) do
  Rails.logger.info "[#{Time.now.utc}] WORKER: Checking health of threads..."
  restarted = 0
  @@threads.each do |thread, queue|
    unless thread.status
      # restart thread
      queue = @@threads[thread]
      @@threads.delete(thread)
      thread = Thread.new {
        loop do
          work(queue)
          sleep 10
        end
      }
      @@threads[thread] = queue
      restarted += 1
    end
  end
  if restarted == 0
    Rails.logger.info "[#{Time.now.utc}] WORKER: All threads in good health."
  else
    Rails.logger.warn "[#{Time.now.utc}] WORKER: Restarted #{restarted} crashed threads."
  end
  sleep 60
end

# terminate all threads and exit
Rails.logger.info "[#{Time.now.utc}] WORKER: Dismissed, terminating threads..."
@@threads.each do |thread, queue|
  thread.exit
end
Rails.logger.info "[#{Time.now.utc}] WORKER: Exiting."
