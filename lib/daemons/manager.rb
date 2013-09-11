#!/usr/bin/env ruby

# environment setup
ENV["RAILS_ENV"] ||= "development"
root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)
require File.join(root, "config", "environment")

# load libraries
include ManagerLib

# sigterm listener
$running = true
Signal.trap("TERM") do
  $running = false
end

# daemon loop
Rails.logger.info "[#{Time.now.utc}] MANAGER: Summoned."
while($running) do
  Rails.logger.info "[#{Time.now.utc}] MANAGER: Starting main loop."
  checks_to_do, done_checks = get_scheduled_checks
  registered, observed = process_done_checks(done_checks)
  Rails.logger.info "[#{Time.now.utc}] MANAGER: Registered #{registered} done checks."
  Rails.logger.info "[#{Time.now.utc}] MANAGER: Created #{observed} observations."
  scheduled = schedule_new_checks(checks_to_do)
  Rails.logger.info "[#{Time.now.utc}] MANAGER: Scheduled #{scheduled} new checks."
  Rails.logger.info "[#{Time.now.utc}] MANAGER: Going to sleep."
  sleep 60
end
Rails.logger.info "[#{Time.now.utc}] MANAGER: Dismissed, exiting."
