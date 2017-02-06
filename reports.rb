#!/usr/bin/env ruby

require 'io/console'
require 'net/http'
require 'uri'
require 'json'
require_relative 'as_helpers'

def data_model
  opts = { '1' => "resources", '2' => "archival_objects", '3' => "agents", '4' => "subjects", '5' => "digital_objects", '6' => "accessions", '7' => "top_containers", '8' => "container_profiles" }

  puts "Select a data model:"
  opts.each do |k,v|
    puts "* (#{k}) #{v}"
  end

  opt = gets.chomp
  if opts.has_key?(opt)
    return opts[opt]
  else
    puts "Invalid entry, try again."
    get_data_model
  end
end

def report_type(data_model)
  opts = case data_model
  when "resources"
    { '1' => "json", '2' => "ead", '3' => "marc" }
  when "agents"
    { '1' => "json", '2' => "eac" }
  else
    { '1' => "json" }
  end

  puts "Select report type:"
  opts.each do |k,v|
    puts "* (#{k}) #{v}"
  end
  opt = gets.chomp
  if opts.has_key?(opt)
    return opts[opt]
  else
    puts "Invalid entry, try again."
    get_report_type(data_model)
  end
end

params = {
  'url' => "http://localhost:8089/",
  'repo' => "repositories/2",
  'path' => "/Users/jackflaps"
}

params['token'] = get_token(params)

model = data_model
type = report_type(model)

if model == "agents"
  run_report(type, "#{model}/people", params)
  run_report(type, "#{model}/corporate_entities", params)
  run_report(type, "#{model}/families", params)
  run_report(type, "#{model}/software", params)
else
  run_report(type, model, params)
end
