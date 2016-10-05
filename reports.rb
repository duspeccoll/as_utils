#!/usr/bin/env ruby

require 'io/console'
require 'net/http'
require 'uri'
require 'json'
require_relative 'as_helpers'

params = {
  'url' => "http://localhost:8089",
  'repo' => "repositories/2",
  'path' => "/Users/jackflaps"
}

params['uri'] = URI("#{params['url']}")
params['token'] = get_token(params)

model = get_data_model
type = get_report_type(data_model)

if model == "agents"
  run_report(type, "#{model}/people", params)
  run_report(type, "#{model}/corporate_entities", params)
  run_report(type, "#{model}/families", params)
  run_report(type, "#{model}/software", params)
else
  run_report(type, model, params)
end
