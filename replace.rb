#!/usr/bin/env ruby
# We wrote a replace script because we needed to make a bunch of post-migration
# edits that aren't possible through the Batch Find/Replace Beta right now.

require 'date'
require_relative 'astools'

@repo = "/repositories/2"
logfile = "log_#{DateTime.now.strftime("%Y%m%d_%H%M%S")}.txt"
File.delete(logfile) if File.exist?(logfile)

ASTools::User.get_session

# pick a data model to work on and grab its IDs
ids = ASTools::HTTP.get_json("#{@repo}/digital_objects", 'all_ids' => true)

# iterate over the ids and work on just the ones that match our conditions
ids.each_with_index do |id, i|
  print "Processing record #{i+1} of #{ids.length}... \r"
  json = ASTools::HTTP.get_json("#{@repo}/digital_objects/#{id.to_s}")

  json['notes'] = []
  json['linked_agents'] = []
  json['dates'] = []
  json['extents'] = []
  json['subjects'] = []

  resp = ASTools::HTTP.post_json("#{@repo}/digital_objects/#{id.to_s}", json)
  if resp.code == "200"
    File.open(logfile, 'a') { |f| f.puts("Success: digital_objects/#{id.to_s}") }
  else
    File.open(logfile, 'a') { |f| f.puts("Error: digital_objects/#{id.to_s}") }
  end
end

puts "\nDone."
