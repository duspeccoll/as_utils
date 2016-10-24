#!/usr/bin/env ruby
# We wrote a replace script because we needed to make a bunch of post-migration
# edits that aren't possible through the Batch Find/Replace Beta right now.

require 'io/console'
require 'json'
require 'net/http'
require 'uri'
require_relative 'as_helpers'

params = {
  'url' => "http://localhost:8089/",
  'repo_url' => "http://localhost:8089/repositories/2/"
  'logfile' => "logfile.txt"
}

params['token'] = get_token(params)

File.delete(params['logfile']) if File.exist?(params['logfile'])

# pick a data model to work on and grab its IDs
ids = get_request(URI("#{params['url']}/repositories/2/top_containers"), params, {'all_ids' => true})

# iterate over the ids and work on just the ones that match our conditions
ids.each do |id|
  record_url = URI("#{params['url']}/repositories/2/top_containers/#{id.to_s}")
  record = get_request(record_url, params)
  indicator = record['indicator']

  if indicator.match(/\.\d{2}\./)
    log_string = "#{indicator} => "
    indicator.sub!(/\.\d{2}\.\d{2}\./,'.') if indicator.match(/\.\d{2}\.\d{2}\./)
    indicator.sub!(/\.\d{2}\./,'.')
    log_string << "#{indicator}"
    record['indicator'] = indicator
    resp = post_request(record_url, record, params, {'content_type' => "application/json"})
    if resp.code == "200"
      File.open(params['logfile'], 'a') { |f| f.puts(log_string) }
    else
      puts "Error: top_containers/#{id.to_s}"
    end
  end
end
