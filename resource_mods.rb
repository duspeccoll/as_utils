#!/usr/bin/env ruby

require 'json'
require 'nokogiri'
require_relative 'as_helpers'

def get_child_mods(object, params)
  uri = "#{params['repo_id']}archival_objects/mods/#{object['id']}.xml"
  filename = ""
  if object['component_id']
    filename << "#{params['path']}/#{object['component_id'].gsub(/\./,'_')}.xml"
  else
    filename << "#{params['path']}/#{object['id']}.xml"
  end
  if object['level'] == "item"
    mods = Nokogiri::XML(get_request(URI(uri), params).body)
    File.delete(filename) if File.exist?(filename)
    File.open(filename, 'w') { |f| f.write(mods.to_xml) }
  end
  object['children'].each do |child|
    get_child_mods(child, params)
  end
end

params = {
  'url' => "http://localhost:8089",
  'repo_id' => "http://localhost:8089/repositories/2/",
}

params['token'] = get_token(params)
print "resource id: "
id = gets.chomp
params['path'] = "mods_#{id}"
Dir.mkdir params['path'] unless Dir.exist?(params['path'])
json = JSON.parse(get_request(URI("#{params['repo_id']}resources/#{id}/tree"), params).body)
json['children'].each do |child|
  get_child_mods(child, params)
end
