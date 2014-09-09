#!/usr/bin/env ruby

# environment setup
ENV["RAILS_ENV"] ||= "development"
root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)
require File.join(root, "config", "environment")

# sigterm listener
$running = true
Signal.trap("TERM") do
  $running = false
end

# daemon loop
worker = Worker.new
Rails.logger.info "[#{Time.now.utc}] WORKER: Summoned."
while($running) do
  Rails.logger.info "[#{Time.now.utc}] WORKER: Starting main loop."
  begin
    worker.work
  rescue Exception => e
    Rails.logger.info "[#{Time.now.utc}] WORKER ERROR: #{e.inspect}"
  end
  Rails.logger.info "[#{Time.now.utc}] WORKER: Going to sleep."
  sleep 20
end
Rails.logger.info "[#{Time.now.utc}] WORKER: Dismissed, exiting."
