#!/usr/bin/env ruby
# We wrote a replace script because we needed to make a bunch of post-migration
# edits that aren't possible through the Batch Find/Replace Beta right now.

require 'io/console'
require 'json'
require 'net/http'
require 'uri'
require 'date'
require_relative 'as_helpers'

params = {
  'url' => "http://localhost:8089",
  'repo_url' => "http://localhost:8089/repositories/2/",
  'logfile' => "log_#{DateTime.now.strftime("%Y%m%d_%H%M%S")}.txt"
}

params['token'] = get_token(params)

File.delete(params['logfile']) if File.exist?(params['logfile'])

# pick a data model to work on and grab its IDs
ids = JSON.parse(get_request(URI("#{params['url']}/repositories/2/digital_objects"), params, {'all_ids' => true}).body)

# iterate over the ids and work on just the ones that match our conditions
ids.each do |id|
  record_url = URI("#{params['url']}/repositories/2/digital_objects/#{id.to_s}")
  record = get_request(record_url, params)
  json = JSON.parse(record.body)

  json['notes'] = []
  json['linked_agents'] = []
  json['dates'] = []
  json['extents'] = []
  json['subjects'] = []

  resp = post_request(record_url, json, params, {'content_type' => "application/json"})
  if resp.code == "200"
    File.open(params['logfile'], 'a') { |f| f.puts("Success: digital_objects/#{id.to_s}") }
  else
    File.open(params['logfile'], 'a') { |f| f.puts("Error: digital_objects/#{id.to_s}") }
  end
end
